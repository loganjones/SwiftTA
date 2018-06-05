//
//  OpenGLViewController.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 5/22/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL
import OpenGL.GL3


class OpenGLViewController: NSViewController {
    
    private var displayLink: CVDisplayLink?
    private var oglView: OpenGLView? { return self.view as? OpenGLView }
    
    private let knownRenderers: [OpenGLRenderer.Type] = [OpenGLCore3Renderer.self]
    private var renderer: OpenGLRenderer!
    
    deinit {
        if let displayLink = displayLink { CVDisplayLinkStop(displayLink) }
    }
    
    override func loadView() {
        
        var format: NSOpenGLPixelFormat?
        for r in knownRenderers {
            if let f = NSOpenGLPixelFormat(attributes: r.desiredPixelFormatAttributes) {
                renderer = r.init()
                format = f
                break
            }
        }
        
        let defaultFrame = CGRect(x: 0, y: 0, width: 640, height: 480)
        guard let oglView = OpenGLView(frame: defaultFrame, pixelFormat: format) else {
            self.view = NSView(frame: defaultFrame)
            return;
        }
        
        oglView.wantsBestResolutionOpenGLSurface = true
        oglView.didPrepareOpenGL = { [weak self] (context) in
            self?.setupDisplayLink()
            self?.renderer.initializeOpenglState()
        }
        
        self.view = oglView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        guard let oglView = self.view as? OpenGLView else {
//            print("View attached to GameViewController is not an OpenGLView")
//            return
//        }
        
    }
    
//    override func viewWillAppear() {
//        super.viewWillAppear()
//        setupDisplayLink()
//    }
//
//    override func viewWillDisappear() {
//        super.viewWillDisappear()
//        if let displayLink = displayLink {
//            CVDisplayLinkStop(displayLink)
//        }
//    }
    
    private func setupDisplayLink() {
        
        guard displayLink == nil else {
            CVDisplayLinkStart(displayLink!)
            return
        }
        
        func DisplayLinkCallback(displayLink: CVDisplayLink,
                                 now: UnsafePointer<CVTimeStamp>,
                                 outputTime: UnsafePointer<CVTimeStamp>,
                                 flagsIn: CVOptionFlags,
                                 flagsOut: UnsafeMutablePointer<CVOptionFlags>,
                                 displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
            
            let currentTime = Double(now.pointee.videoTime) / Double(now.pointee.videoTimeScale)
            let deltaTime = 1.0 / (outputTime.pointee.rateScalar * Double(outputTime.pointee.videoTimeScale) / Double(outputTime.pointee.videoRefreshPeriod))
            //print("Frame: time:\(currentTime) delta:\(deltaTime)")
            
            let controller = unsafeBitCast(displayLinkContext, to: OpenGLViewController.self)
            
            guard let context = controller.oglView?.openGLContext
                else { return kCVReturnError }
            context.makeCurrentContext()
            
            guard let cgl = context.cglContextObj
                else { return kCVReturnError }
            CGLLockContext(cgl)
            
            controller.renderer.drawFrame(currentTime, deltaTime)
            
            CGLFlushDrawable(cgl)
            CGLUnlockContext(cgl)
            return kCVReturnSuccess
        }
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else { return }
        
        CVDisplayLinkSetOutputCallback(displayLink, DisplayLinkCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        CVDisplayLinkStart(displayLink)
    }
    
}

// MARK:- OpenGLView

class OpenGLView: NSOpenGLView {
    
    var didPrepareOpenGL: (NSOpenGLContext) -> () = { _ in }
    var frameDidChange: (NSRect, NSRect) -> () = { _,_ in }
    
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        guard let context = openGLContext
            else { return }
        
        var swapInt: GLint = 1
        context.setValues(&swapInt, for: .swapInterval)
        
        didPrepareOpenGL(context)
    }
    
    override var frame: NSRect {
        didSet { frameDidChange(frame, bounds) }
    }
    
}

// MARK:- Renderer

protocol OpenGLRenderer {
    
    static var desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] { get }
    init()
    func initializeOpenglState()
    func drawFrame(_ currentTime: Double, _ deltaTime: Double)
    
}

class OpenGLCore3Renderer: OpenGLRenderer {
    
    static let desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAAllowOfflineRenderers),
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFADoubleBuffer),
        UInt32(NSOpenGLPFADepthSize), UInt32(24),
        UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
        0
    ]
    
    required init() {
    }
    
    func initializeOpenglState() {
    }
    
    func drawFrame(_ currentTime: Double, _ deltaTime: Double) {
        glClearColor(1, 0, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
    }
    
}
