//
//  ModelView+Metal.swift
//  HPIView
//
//  Created by Logan Jones on 6/12/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa
import MetalKit


class MetalModelView<StateProvider: ModelViewStateProvider>: MTKView, MTKViewDelegate, ModelViewLoader {
    
    unowned let stateProvider: StateProvider
    private let renderer: MetalModelViewRenderer
    
    required init?(modelViewFrame frameRect: CGRect, stateProvider: StateProvider) {
        self.stateProvider = stateProvider
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        
        renderer = BasicMetalModelViewRenderer(defaultDevice)
        super.init(frame: frameRect, device: defaultDevice)
        self.delegate = self
        
        renderer.configure(view: self)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(_ model: UnitModel) throws {
        try renderer.switchTo(model)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        stateProvider.viewportChanged(to: size)
    }
    
    func draw(in view: MTKView) {
        renderer.drawFrame(in: view, stateProvider.viewState)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func mouseDragged(with event: NSEvent) {
        stateProvider.mouseDragged(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        stateProvider.keyDown(with: event)
    }
    
}

protocol MetalModelViewRenderer {
    func configure(view: MTKView)
    func drawFrame(in view: MTKView, _ viewState: ModelViewState)
    func switchTo(_ model: UnitModel) throws
}
