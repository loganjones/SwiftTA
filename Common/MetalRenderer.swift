//
//  MetalRenderer.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 8/13/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import MetalKit

typealias MTKViewDelegateRequirementForNSObjectProtocol = NSObject
private let maxBuffersInFlight = 3


class MetalRenderer: MTKViewDelegateRequirementForNSObjectProtocol, GameRenderer {
    
    private let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var viewState: GameViewState
    let device: MTLDevice
    let metalView: MTKView
    private let commandQueue: MTLCommandQueue
    
    private let tnt: MetalTntDrawable
    private let features: MetalFeatureDrawable
    
    required init?(loadedState loaded: GameState, viewState: GameViewState = GameViewState()) {
        
        guard let metalDevice = MTLCreateSystemDefaultDevice(),
            let metalCommandQueue = metalDevice.makeCommandQueue(),
            let library = metalDevice.makeDefaultLibrary()
            else {
                print("Metal is not supported on this device")
                return nil
        }
        
        self.viewState = viewState
        self.device = metalDevice
        self.metalView = MTKView(frame: CGRect(size: viewState.viewport.size), device: metalDevice)
        self.commandQueue = metalCommandQueue
        
        tnt = MetalRenderer.determineTntDrawable(loaded.map, metalDevice)
        features = MetalFeatureDrawable(metalDevice, maxBuffersInFlight)
        
        super.init()
        
        metalView.delegate = self
        metalView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalView.sampleCount = 1
        
        do {
            let host = MetalHost(view: metalView, device: device, library: library)
            try tnt.configure(for: host)
            switch loaded.map {
            case .ta(let map):
                let palette = try Palette.standardTaPalette(from: loaded.filesystem)
                try tnt.load(map, using: palette)
            case .tak(let map):
                try tnt.load(map, from: loaded.filesystem)
            }
            
            try features.configure(for: host)
            features.load(loaded.features, containedIn: loaded.map, filesystem: loaded.filesystem)
        }
        catch {
            print("Failed to load map: \(error)")
            return nil
        }
        
    }
    
    #if canImport(AppKit)
    var view: NSView { return metalView }
    #elseif canImport(UIKit)
    var view: UIView { return metalView }
    #endif
    
    private static func determineTntDrawable(_ map: MapModel, _ metalDevice: MTLDevice) -> MetalTntDrawable {
        
        enum PreferredTnt { case simple, tiled }
        let tntStyle: PreferredTnt
        
        if case .tak = map { tntStyle = .tiled }
        else if map.resolution.max > metalDevice.maximum2dTextureSize { tntStyle = .tiled }
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
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //viewState.viewport.size = size
    }
    
    func draw(in view: MTKView) {
        let viewState = self.viewState
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer { commandBuffer.commit() }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler { _ in semaphore.signal() }
        
        tnt.setupNextFrame(viewState, commandBuffer)
        features.setupNextFrame(viewState, commandBuffer)
        
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
