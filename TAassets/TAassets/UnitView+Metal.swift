//
//  UnitView+Metal.swift
//  TAassets
//
//  Created by Logan Jones on 7/11/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation
import MetalKit


class MetalUnitView<StateProvider: UnitViewStateProvider>: MTKView, MTKViewDelegate, UnitViewLoader {
    
    unowned let stateProvider: StateProvider
    private var renderer: MetalUnitViewRenderer
    
    required init?(modelViewFrame frameRect: NSRect, stateProvider: StateProvider) {
        self.stateProvider = stateProvider
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        
        renderer = BasicMetalUnitViewRenderer(defaultDevice)
        super.init(frame: frameRect, device: defaultDevice)
        self.delegate = self
        
        renderer.configure(view: self)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(_ info: UnitInfo,
              _ model: UnitModel,
              _ script: UnitScript,
              _ texture: UnitTextureAtlas,
              _ filesystem: FileSystem,
              _ palette: Palette) throws {
        
        try renderer.switchTo(UnitModel.Instance(for: model), of: model, with: texture, textureData: texture.build(from: filesystem, using: palette))
    }
    
    func clear() {
        renderer.clear()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        stateProvider.viewportChanged(to: size)
    }
    
    func draw(in view: MTKView) {
        let deltaTime = 1.0 / Double(view.preferredFramesPerSecond)
        stateProvider.updateAnimatingState(deltaTime: deltaTime)
        
        let state = stateProvider.viewState
        if let model = state.model, let modelInstance = state.modelInstance {
            renderer.updateForAnimations(model, modelInstance)
        }
        renderer.drawFrame(in: view, state)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func mouseDragged(with event: NSEvent) {
        stateProvider.mouseDragged(with: event)
        setNeedsDisplay(bounds)
    }
    
    override func keyDown(with event: NSEvent) {
        stateProvider.keyDown(with: event)
        setNeedsDisplay(bounds)
    }
    
}

protocol MetalUnitViewRenderer {
    
    func configure(view: MTKView)
    func drawFrame(in view: MTKView, _ viewState: UnitViewState)

    func updateForAnimations(_ model: UnitModel, _ modelInstance: UnitModel.Instance)
    
    func switchTo(_ instance: UnitModel.Instance, of model: UnitModel, with textureAtlas: UnitTextureAtlas, textureData: Data) throws
    func clear()
    
}
