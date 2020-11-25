//
//  MetalRenderer.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 8/13/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import MetalKit
import SwiftTA_Core

public typealias MTKViewDelegateRequirementForNSObjectProtocol = NSObject
private let maxBuffersInFlight = 3


public class MetalRenderer: MTKViewDelegateRequirementForNSObjectProtocol, GameRenderer, GameViewProvider {
    
    private let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    private let viewStateQueue = DispatchQueue(label: "swiftta.renderer.viewstate")
    private var _viewState: GameViewState
    public var viewState: GameViewState {
        get { viewStateQueue.sync { self._viewState } }
        set { viewStateQueue.sync { self._viewState = newValue } }
    }
    
    let device: MTLDevice
    let metalView: MTKView
    private let commandQueue: MTLCommandQueue
    
    private let gui: MetalGuiDrawable
    private let tnt: MetalTntDrawable
    private let features: MetalFeatureDrawable
    private let units: MetalUnitDrawable
    
    public required init?(loadedState loaded: GameState, viewState: GameViewState = GameViewState()) {
        
        let beginRenderer = Date()
        
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device.")
            return nil
        }
        guard let metalCommandQueue = metalDevice.makeCommandQueue() else {
            print("Metal command queue not available.")
            return nil
        }
        guard let library = try? metalDevice.makeDefaultLibrary(bundle: Bundle.module) else {
            print("Failed to load Metal library.")
            return nil
        }
        
        _viewState = viewState
        self.device = metalDevice
        self.metalView = MTKView(frame: CGRect(size: viewState.viewport.size), device: metalDevice)
        self.commandQueue = metalCommandQueue
        
        gui = MetalGuiDrawable(metalDevice, maxBuffersInFlight)
        tnt = MetalRenderer.determineTntDrawable(loaded.map, metalDevice)
        features = MetalFeatureDrawable(metalDevice, maxBuffersInFlight)
        units = MetalUnitDrawable(metalDevice, maxBuffersInFlight)
        
        super.init()
        
        metalView.delegate = self
        metalView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalView.sampleCount = 1
        
        do {
            let host = MetalHost(view: metalView, device: device, library: library)
            let palette = try Palette.standardTaPalette(from: loaded.filesystem)
            
            let beginGui = Date()
            try gui.configure(for: host)
            try gui.loadCursors(from: loaded.filesystem, with: palette.applyingChromaKeys([0]))
            let endGui = Date()
            
            let beginMap = Date()
            try tnt.configure(for: host)
            switch loaded.map {
            case .ta(let map):
                try tnt.load(map, using: palette)
            case .tak(let map):
                try tnt.load(map, from: loaded.filesystem)
            }
            let endMap = Date()
            
            let beginFeatures = Date()
            try features.configure(for: host)
            features.load(loaded.features, containedIn: loaded.map, filesystem: loaded.filesystem)
            let endFeatures = Date()
            
            let beginUnits = Date()
            try units.configure(for: host)
            units.load(loaded.units, sides: loaded.sides, filesystem: loaded.filesystem)
            let endUnits = Date()
            
            let endRenderer = Date()
            print("""
                Render assets load time: \(endRenderer.timeIntervalSince(beginRenderer)) seconds
                  Gui(): \(endGui.timeIntervalSince(beginGui)) seconds
                  Map(\(loaded.map.mapSize)): \(endMap.timeIntervalSince(beginMap)) seconds
                  Units(\(loaded.units.count)): \(endUnits.timeIntervalSince(beginUnits)) seconds
                  Features(\(loaded.features.count)): \(endFeatures.timeIntervalSince(beginFeatures)) seconds
                """)
        }
        catch {
            print("Failed to load render assets: \(error)")
            return nil
        }
        
    }
    
    #if canImport(AppKit)
    public var view: NSView { return metalView }
    #elseif canImport(UIKit)
    public var view: UIView { return metalView }
    #endif
    
    private static func determineTntDrawable(_ map: MapModel, _ metalDevice: MTLDevice) -> MetalTntDrawable {
        
        enum PreferredTnt { case simple, tiled }
        let tntStyle: PreferredTnt
        
        if case .tak = map { tntStyle = .tiled }
        else if map.resolution.max() > metalDevice.maximum2dTextureSize { tntStyle = .tiled }
        else { tntStyle = .simple }
        
        switch tntStyle {
        case .tiled:
            print("Using tiled tnt renderer")
            return MetalTiledTntDrawable(metalDevice, maxBuffersInFlight)
        case .simple:
            print("Using simple tnt renderer")
            return MetalOneTextureTntDrawable(metalDevice, maxBuffersInFlight)
        }
    }
    
}

extension MetalRenderer: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //viewState.viewport.size = size
    }
    
    public func draw(in view: MTKView) {
        let viewState = self.viewState
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer { commandBuffer.commit() }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler { _ in semaphore.signal() }
        
        gui.setupNextFrame(viewState, commandBuffer)
        tnt.setupNextFrame(viewState, commandBuffer)
        features.setupNextFrame(viewState, commandBuffer)
        let ufs = units.setupNextFrame(viewState, commandBuffer)
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 1, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "Map Render Encoder"
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.pushDebugGroup("Draw Map")
        tnt.drawFrame(with: renderEncoder)
        renderEncoder.popDebugGroup()
        
        renderEncoder.pushDebugGroup("Draw Features")
        features.drawFrame(with: renderEncoder)
        renderEncoder.popDebugGroup()
        
        renderEncoder.pushDebugGroup("Draw Units")
        units.drawFrame(ufs, with: renderEncoder)
        renderEncoder.popDebugGroup()
        
        renderEncoder.pushDebugGroup("Draw GUI")
        gui.drawFrame(with: renderEncoder)
        renderEncoder.popDebugGroup()
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
    }
    
}

protocol MetalTntDrawable {
    func configure(for metal: MetalHost) throws
    func load(_ map: TaMapModel, using palette: Palette) throws
    func load(_ map: TakMapModel, from filesystem: FileSystem) throws
    func setupNextFrame(_ viewState: GameViewState, _ commandBuffer: MTLCommandBuffer)
    func drawFrame(with renderEncoder: MTLRenderCommandEncoder)
}
