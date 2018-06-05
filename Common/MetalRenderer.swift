//
//  MetalRenderer.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 8/13/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import MetalKit

typealias MTKViewDelegateRequirementForNSObjectProtocol = NSObject


class MetalRenderer: MTKViewDelegateRequirementForNSObjectProtocol, GameRenderer {
    
    var viewState: GameViewState
    let device: MTLDevice
    let metalView: MTKView
    private let commandQueue: MTLCommandQueue
    
    private let tnt: MetalTntDrawable
    
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
        
        if loaded.map.resolution.max > metalDevice.maximum2dTextureSize {
            print("Using tiled tnt renderer")
            tnt = MetalTiledTntDrawable(metalDevice)
        }
        else {
            print("Using simple tnt renderer")
            tnt = MetalOneTextureTntDrawable(metalDevice)
        }
        
        super.init()
        
        metalView.delegate = self
        
        do {
            try tnt.configure(for: MetalHost(view: metalView, device: device, library: library))
            switch loaded.map {
            case .ta(let map):
                let palette = try Palette.standardTaPalette(from: loaded.filesystem)
                try tnt.load(map, using: palette)
            case .tak(let map):
                try tnt.load(map, from: loaded.filesystem)
            }
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
    
}

extension MetalRenderer: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //viewState.viewport.size = size
    }
    
    func draw(in view: MTKView) {
        let viewState = self.viewState
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer { commandBuffer.commit() }
        
        tnt.setupNextFrame(viewState, commandBuffer)
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 1, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "Map Render Encoder"
        renderEncoder.pushDebugGroup("Draw Map")
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        tnt.drawFrame(with: renderEncoder)
        
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
