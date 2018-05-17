//
//  UnitView.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL


class UnitView: NSOpenGLView {
    
    private var viewState = ViewState()
    private var renderer: UnitViewRenderer
    private var unit: UnitInstance?
    private var displayLink: CVDisplayLink?
    
    private var loadTime: Double = 0
    private var shouldStartMoving = false
    
    private var trackingMouse = false
    
    static let gridSize = 16
    
    override init(frame frameRect: NSRect) {
        
        let format: NSOpenGLPixelFormat?
        if let core = NSOpenGLPixelFormat(attributes: UnitViewOpenglCore33Renderer.desiredPixelFormatAttributes) {
            renderer = UnitViewOpenglCore33Renderer()
            format = core
        }
        else if let legacy = NSOpenGLPixelFormat(attributes: UnitViewOpenglLegacyRenderer.desiredPixelFormatAttributes) {
            renderer = UnitViewOpenglLegacyRenderer()
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
    
    deinit {
        CVDisplayLinkStop(displayLink!)
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
        
        func UnitViewDisplayLinkCallback(displayLink: CVDisplayLink,
                                         now: UnsafePointer<CVTimeStamp>,
                                         outputTime: UnsafePointer<CVTimeStamp>,
                                         flagsIn: CVOptionFlags,
                                         flagsOut: UnsafeMutablePointer<CVOptionFlags>,
                                         displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
            
            let currentTime = Double(now.pointee.videoTime) / Double(now.pointee.videoTimeScale)
            let deltaTime = 1.0 / (outputTime.pointee.rateScalar * Double(outputTime.pointee.videoTimeScale) / Double(outputTime.pointee.videoRefreshPeriod))
            
            let view = unsafeBitCast(displayLinkContext, to: UnitView.self)
            view.drawFrame(currentTime, deltaTime)
            
            return kCVReturnSuccess
        }
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!, UnitViewDisplayLinkCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        CVDisplayLinkStart(displayLink!)
    }
    
//    override func draw(_ dirtyRect: NSRect) {
//        drawScene()
//        glFlush()
//    }
    
    fileprivate func drawFrame(_ currentTime: Double, _ deltaTime: Double) {
        
        guard let unit = unit else {
            return
        }
        
        viewState.aspectRatio = Float(viewState.viewportSize.height) / Float(viewState.viewportSize.width)
        let w = Float( (unit.info.footprint.width + 8) * UnitView.gridSize )
        viewState.sceneSize = (width: w, height: w * viewState.aspectRatio)
        
        if shouldStartMoving && getTime() > loadTime + 1 {
            unit.scriptContext.startScript("StartMoving")
            shouldStartMoving = false
            viewState.isMoving = true
            viewState.speed = 0
        }
        
        unit.scriptContext.run(for: unit.modelInstance, on: self)
        unit.scriptContext.applyAnimations(to: &unit.modelInstance, for: deltaTime)
        renderer.updateForAnimations(unit.model, unit.modelInstance)
        
        guard let context = openGLContext
            else { return }
        context.makeCurrentContext()
        CGLLockContext(context.cglContextObj!)
        
        if viewState.isMoving {
            let dt = deltaTime * 10
            let acceleration = unit.info.acceleration
            let maxSpeed = unit.info.maxVelocity
            var speed = viewState.speed
            
            if speed < maxSpeed {
                speed = min(speed + dt * acceleration, maxSpeed)
            }
            viewState.movement += dt * speed
            viewState.speed = speed
            
            let gridSize = Double(UnitView.gridSize)
            if viewState.movement > gridSize {
                viewState.movement -= gridSize
            }
        }
        
        renderer.drawFrame(viewState, currentTime, deltaTime)
        glFlush()
        
        CGLFlushDrawable(context.cglContextObj!)
        CGLUnlockContext(context.cglContextObj!)
    }
    
    private struct ToLoad {
        var unit: UnitInfo
        var model: UnitModel
        var instance: UnitModel.Instance
        var scriptContext: UnitScript.Context
        var texture: UnitTextureAtlas
        var textureData: Data
    }
    
    func load(_ info: UnitInfo,
              _ model: UnitModel,
              _ script: UnitScript,
              _ texture: UnitTextureAtlas,
              _ filesystem: FileSystem,
              _ palette: Palette) throws {
        let unit = try UnitInstance(info, model, script, texture, filesystem, palette)
        self.unit = unit
        
        unit.scriptContext.startScript("Create")
        loadTime = getTime()
        shouldStartMoving = unit.info.maxVelocity > 0
        viewState.isMoving = false
        viewState.movement = 0
        
        renderer.switchTo(unit)
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
        case .some("t"):
            viewState.textured = !viewState.textured
            setNeedsDisplay(bounds)
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

extension UnitView: ScriptMachine {
    
    func getTime() -> Double {
        return Date.timeIntervalSinceReferenceDate
    }
    
}

extension UnitView {
    
    class UnitInstance {
        var info: UnitInfo
        var model: UnitModel
        var modelInstance: UnitModel.Instance
        var textureAtlas: UnitTextureAtlas
        var textureData: Data
        var scriptContext: UnitScript.Context
        
        init(_ info: UnitInfo,
             _ model: UnitModel,
             _ script: UnitScript,
             _ texture: UnitTextureAtlas,
             _ filesystem: FileSystem,
             _ palette: Palette) throws {
            self.info = info
            self.model = model
            self.modelInstance = UnitModel.Instance(for: model)
            self.textureAtlas = texture
            self.textureData = texture.build(from: filesystem, using: palette)
            self.scriptContext = try UnitScript.Context(script, model)
        }
        
    }
    
    struct ViewState {
        var viewportSize = CGSize()
        var aspectRatio: Float = 1
        var sceneSize: (width: Float, height: Float) = (0,0)
        
        var drawMode = DrawMode.solid
        var textured = true
        var lighted = false
        
        var rotateZ: GLfloat = 160
        var rotateX: GLfloat = 0
        var rotateY: GLfloat = 0
        
        var isMoving = false
        var speed: Double = 0
        var movement: Double = 0
    }
    
    enum DrawMode: Int {
        case solid
        case wireframe
        case outlined
    }
    
}

protocol UnitViewRenderer {
    
    static var desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] { get }
    
    func initializeOpenglState()
    func drawFrame(_ viewState: UnitView.ViewState, _ currentTime: Double, _ deltaTime: Double)
    func updateForAnimations(_ model: UnitModel, _ modelInstance: UnitModel.Instance)
    
    func switchTo(_ unit: UnitView.UnitInstance)
    
}

private extension UnitView {
    
    class EmptyRenderer: UnitViewRenderer {
        
        static var desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = []
        
        func initializeOpenglState() {
        }
        
        func drawFrame(_ viewState: ViewState, _ currentTime: Double, _ deltaTime: Double) {
        }
        
        func updateForAnimations(_ model: UnitModel, _ modelInstance: UnitModel.Instance) {
        }
        
        func switchTo(_ unit: UnitView.UnitInstance) {
        }
    
    }
    
}
