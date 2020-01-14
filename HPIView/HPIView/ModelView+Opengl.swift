//
//  ModelView+Opengl.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL
import SwiftTA_Core

class OpenglModelView<StateProvider: ModelViewStateProvider>: NSOpenGLView, ModelViewLoader {
    
    unowned let stateProvider: StateProvider
    private let renderer: OpenglModelViewRenderer
    
    required init?(modelViewFrame frameRect: NSRect, stateProvider: StateProvider) {
        self.stateProvider = stateProvider
        
        let format: NSOpenGLPixelFormat?
        if let core = NSOpenGLPixelFormat(attributes: Core33OpenglModelViewRenderer.desiredPixelFormatAttributes) {
            renderer = Core33OpenglModelViewRenderer()
            format = core
        }
        else if let legacy = NSOpenGLPixelFormat(attributes: LegacyOpenglModelViewRenderer.desiredPixelFormatAttributes) {
            renderer = LegacyOpenglModelViewRenderer()
            format = legacy
        }
        else {
            return nil
        }
        
        super.init(frame: frameRect, pixelFormat: format)
        wantsBestResolutionOpenGLSurface = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    enum InitError: Error {
        case noSupportedPixelFormatFound
    }
    
    override var frame: NSRect {
        didSet { stateProvider.viewportChanged(to: convertToBacking(bounds).size) }
    }
    
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        guard let context = openGLContext
            else { return }
        
        var swapInt: GLint = 1
        context.setValues(&swapInt, for: .swapInterval)
        
        renderer.initializeOpenglState()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        guard let context = openGLContext
            else { return }
        context.makeCurrentContext()
        CGLLockContext(context.cglContextObj!)
        
        renderer.drawFrame(stateProvider.viewState)
        glFlush()
        
        CGLFlushDrawable(context.cglContextObj!)
        CGLUnlockContext(context.cglContextObj!)
    }
    
    func load(_ model: UnitModel) throws {
        renderer.switchTo(model)
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

protocol OpenglModelViewRenderer {
    
    static var desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] { get }
    
    func initializeOpenglState()
    func drawFrame(_ viewState: ModelViewState)
    
    func switchTo(_ model: UnitModel)
    
}
