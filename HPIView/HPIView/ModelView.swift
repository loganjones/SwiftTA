//
//  ModelView.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL


class Model3DOView: NSOpenGLView {
    
    private var viewState = ViewState()
    private var renderer: ModelViewRenderer
    
    private var loadTime: Double = 0
    private var shouldStartMoving = false
    
    private var trackingMouse = false
    
    static let gridSize = 16
    
    override init(frame frameRect: NSRect) {
        
        let format: NSOpenGLPixelFormat?
        if let core = NSOpenGLPixelFormat(attributes: ModelViewOpenglCore33Renderer.desiredPixelFormatAttributes) {
            renderer = ModelViewOpenglCore33Renderer()
            format = core
        }
        else if let legacy = NSOpenGLPixelFormat(attributes: ModelViewOpenglLegacyRenderer.desiredPixelFormatAttributes) {
            renderer = ModelViewOpenglLegacyRenderer()
            format = legacy
        }
        else {
            renderer = EmptyRenderer()
            format = nil
        }
        
        super.init(frame: frameRect, pixelFormat: format)!
        wantsBestResolutionOpenGLSurface = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var frame: NSRect {
        didSet { viewState.viewportSize = convertToBacking(bounds).size }
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
        
        viewState.aspectRatio = Float(viewState.viewportSize.height) / Float(viewState.viewportSize.width)
        let w = Float(160)//Float( (unit.info.footprint.width + 8) * Model3DOView.gridSize )
        viewState.sceneSize = (width: w, height: w * viewState.aspectRatio)
        
        guard let context = openGLContext
            else { return }
        context.makeCurrentContext()
        CGLLockContext(context.cglContextObj!)
        
        renderer.drawFrame(viewState)
        glFlush()
        
        CGLFlushDrawable(context.cglContextObj!)
        CGLUnlockContext(context.cglContextObj!)
    }
    
    func load(_ model: UnitModel) throws {
        renderer.switchTo(model)
    }
    
    override func mouseDown(with event: NSEvent) {
        trackingMouse = true
    }
    
    override func mouseUp(with event: NSEvent) {
        trackingMouse = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        if trackingMouse {
            if event.modifierFlags.contains(.shift) { viewState.rotateX += GLfloat(event.deltaX) }
            else if event.modifierFlags.contains(.option) { viewState.rotateY += GLfloat(event.deltaX) }
            else { viewState.rotateZ += GLfloat(event.deltaX) }
            setNeedsDisplay(bounds)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.characters {
        case .some("w"):
            var drawMode = viewState.drawMode
            let i = drawMode.rawValue
            if let mode = DrawMode(rawValue: i+1) { drawMode = mode }
            else { drawMode = .solid }
            viewState.drawMode = drawMode
            setNeedsDisplay(bounds)
//        case .some("t"):
//            viewState.textured = !viewState.textured
//            setNeedsDisplay(bounds)
        case .some("l"):
            viewState.lighted = !viewState.lighted
            setNeedsDisplay(bounds)
        default:
            ()
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

extension Model3DOView {
    
    struct ViewState {
        var viewportSize = CGSize()
        var aspectRatio: Float = 1
        var sceneSize: (width: Float, height: Float) = (0,0)
        
        var drawMode = DrawMode.outlined
        var textured = false
        var lighted = true
        
        var rotateZ: GLfloat = 160
        var rotateX: GLfloat = 0
        var rotateY: GLfloat = 0
    }
    
    enum DrawMode: Int {
        case solid
        case wireframe
        case outlined
    }
    
}

protocol ModelViewRenderer {
    
    static var desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] { get }
    
    func initializeOpenglState()
    func drawFrame(_ viewState: Model3DOView.ViewState)
    
    func switchTo(_ model: UnitModel)
    
}

private extension Model3DOView {
    
    class EmptyRenderer: ModelViewRenderer {
        
        static var desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = []
        
        func initializeOpenglState() {
        }
        
        func drawFrame(_ viewState: ViewState) {
        }
        
        func switchTo(_ model: UnitModel) {
        }
        
    }
    
}
