//
//  UnitView+Opengl.swift
//  TAassets
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL
import SwiftTA_Core


class OpenglUnitView<StateProvider: UnitViewStateProvider>: NSOpenGLView, UnitViewLoader {
    
    unowned let stateProvider: StateProvider
    private var renderer: OpenglUnitViewRenderer
    private let displayLink: CVDisplayLink
    private var displayLinkCallback: CVDisplayLink.CallbackBox!
    
    private var toLoad: ToLoad?
    private var hasInitializedOpenglState = false
    private var shouldClear: Bool = false
    
    required init?(modelViewFrame frameRect: NSRect, stateProvider: StateProvider) {
        self.stateProvider = stateProvider
        
        let format: NSOpenGLPixelFormat?
        if let core = NSOpenGLPixelFormat(attributes: Core33OpenglUnitViewRenderer.desiredPixelFormatAttributes) {
            renderer = Core33OpenglUnitViewRenderer()
            format = core
        }
        else if let legacy = NSOpenGLPixelFormat(attributes: LegacyOpenglUnitViewRenderer.desiredPixelFormatAttributes) {
            renderer = LegacyOpenglUnitViewRenderer()
            format = legacy
        }
        else {
            return nil
        }
        
        var dl: CVDisplayLink?
        let rv = CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let displayLink = dl else {
            print("Failed to create CVDisplayLink! \(rv)")
            return nil
        }
        self.displayLink = displayLink
        
        super.init(frame: frameRect, pixelFormat: format)
        wantsBestResolutionOpenGLSurface = true
        
        displayLinkCallback = displayLink.setOutputCallback {
            [unowned self] (displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext) in
            
            let currentTime = Double(now.pointee.videoTime) / Double(now.pointee.videoTimeScale)
            let deltaTime = 1.0 / (outputTime.pointee.rateScalar * Double(outputTime.pointee.videoTimeScale) / Double(outputTime.pointee.videoRefreshPeriod))
            
            self.drawFrame(currentTime, deltaTime)
            
            return kCVReturnSuccess
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        CVDisplayLinkStop(displayLink)
        displayLinkCallback = nil
    }
    
    override var frame: NSRect {
        didSet { stateProvider.viewportChanged(to: convertToBacking(bounds).size) }
    }
    
    override func prepareOpenGL() {
        super.prepareOpenGL()

        guard let context = openGLContext
            else { print("Failed to obtain an NSOpenGLContext!"); return }
        
        var swapInt: GLint = 1
        context.setValues(&swapInt, for: .swapInterval)

        renderer.initializeOpenglState()
        
        hasInitializedOpenglState = true
        if shouldRunDisplayLink {
            CVDisplayLinkStart(displayLink)
        }
    }
    
    private var shouldRunDisplayLink: Bool {
        return toLoad != nil || renderer.hasLoadedModel
    }
    
//    override func draw(_ dirtyRect: NSRect) {
//        drawScene()
//        glFlush()
//    }
    
    private func drawFrame(_ currentTime: Double, _ deltaTime: Double) {
        
        guard let context = openGLContext
            else { return }
        context.makeCurrentContext()
        CGLLockContext(context.cglContextObj!)
        
        if let loading = toLoad {
            renderer.switchTo(loading.modelInstance,
                              of: loading.model,
                              with: loading.textureAtlas,
                              textureData: loading.textureAtlas.build(from: loading.filesystem, using: loading.palette))
            toLoad = nil
            shouldClear = false
        }
        
        if shouldClear {
            renderer.clear()
            shouldClear = false
        }
        
        stateProvider.updateAnimatingState(deltaTime: deltaTime)
        
        let state = stateProvider.viewState
        if let model = state.model, let modelInstance = state.modelInstance {
            renderer.updateForAnimations(model, modelInstance)
        }
        renderer.drawFrame(state, currentTime, deltaTime)
        
        CGLFlushDrawable(context.cglContextObj!)
        CGLUnlockContext(context.cglContextObj!)
        
        if !shouldRunDisplayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    private struct ToLoad {
        var model: UnitModel
        var modelInstance: UnitModel.Instance
        var textureAtlas: UnitTextureAtlas
        var filesystem: FileSystem
        var palette: Palette
    }
    
    func load(_ info: UnitInfo,
              _ model: UnitModel,
              _ script: UnitScript,
              _ texture: UnitTextureAtlas,
              _ filesystem: FileSystem,
              _ palette: Palette) throws {
        
        toLoad = ToLoad(
            model: model,
            modelInstance: UnitModel.Instance(for: model),
            textureAtlas: texture,
            filesystem: filesystem,
            palette: palette)
        
        if hasInitializedOpenglState {
            CVDisplayLinkStart(displayLink)
        }
    }
    
    func clear() {
        shouldClear = true
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

protocol OpenglUnitViewRenderer {
    
    static var desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] { get }
    
    func initializeOpenglState()
    func drawFrame(_ viewState: UnitViewState, _ currentTime: Double, _ deltaTime: Double)
    func updateForAnimations(_ model: UnitModel, _ modelInstance: UnitModel.Instance)
    
    func switchTo(_ instance: UnitModel.Instance, of model: UnitModel, with textureAtlas: UnitTextureAtlas, textureData: Data)
    func clear()
    
    var hasLoadedModel: Bool { get }
    
}

extension CVDisplayLink {
    
    typealias Callback = (CVDisplayLink,
        UnsafePointer<CVTimeStamp>,
        UnsafePointer<CVTimeStamp>,
        CVOptionFlags,
        UnsafeMutablePointer<CVOptionFlags>,
        UnsafeMutableRawPointer?) -> CVReturn
    
    func setOutputCallback(_ callback: @escaping Callback) -> CallbackBox {
        let box = CallbackBox(callback)
        let p = UnsafeMutableRawPointer(Unmanaged.passUnretained(box).toOpaque())
        CVDisplayLinkSetOutputCallback(self, CVDisplayLinkCallbackFunc, p)
        return box
    }
    
    class CallbackBox {
        let callback: Callback
        init(_ callback: @escaping Callback) {
            self.callback = callback
        }
    }
    
}

func CVDisplayLinkCallbackFunc(
    displayLink: CVDisplayLink,
    now: UnsafePointer<CVTimeStamp>,
    outputTime: UnsafePointer<CVTimeStamp>,
    flagsIn: CVOptionFlags,
    flagsOut: UnsafeMutablePointer<CVOptionFlags>,
    displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn
{
    let box = unsafeBitCast(displayLinkContext, to: CVDisplayLink.CallbackBox.self)
    return box.callback(displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext)
}
