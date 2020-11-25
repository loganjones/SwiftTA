//
//  OpenglCore3Renderer+Cocoa.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 9/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import AppKit
import OpenGL
import SwiftTA_Core


class OpenglCore3CocoaRenderer: OpenglCore3Renderer, GameViewProvider {
    
    fileprivate let openglView: NSOpenGLView
    private let displayLink: CVDisplayLink
    
    private let desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAAllowOfflineRenderers),
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFADoubleBuffer),
        UInt32(NSOpenGLPFADepthSize), UInt32(24),
        UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
        0
    ]
    
    required init?(loadedState: GameState, viewState: GameViewState) {
        
        guard let format = NSOpenGLPixelFormat(attributes: desiredPixelFormatAttributes) else { return nil }
        guard let openglView = CustomOpenglView(frame: CGRect(size: viewState.viewport.size), pixelFormat: format) else { return nil }
        openglView.wantsBestResolutionOpenGLSurface = true
        
        var dl: CVDisplayLink?
        let rv = CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let displayLink = dl else {
            print("Failed to create CVDisplayLink! \(rv)")
            return nil
        }
        
        self.openglView = openglView
        self.displayLink = displayLink
        super.init(loadedState: loadedState, viewState: viewState)
        
        let p = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(displayLink, CVDisplayLinkCallbackFunc, p)
        
        openglView.didPrepareOpenGL = { [weak self]
            context in
            guard let self = self else { return }
            
            var swapInt: GLint = 1
            context.setValues(&swapInt, for: .swapInterval)
            
            // Think about moving the load off of the main thread.
            // (Though OpenGL does not leave us many easy options for that)
            self.load(state: loadedState)
            
            CVDisplayLinkStart(self.displayLink)
        }
    }
    
    deinit {
        CVDisplayLinkStop(displayLink)
    }
    
    #if canImport(AppKit)
    var view: NSView { return openglView }
    #elseif canImport(UIKit)
    var view: UIView { return openglView }
    #endif
    
}

private func CVDisplayLinkCallbackFunc(
    displayLink: CVDisplayLink,
    now: UnsafePointer<CVTimeStamp>,
    outputTime: UnsafePointer<CVTimeStamp>,
    flagsIn: CVOptionFlags,
    flagsOut: UnsafeMutablePointer<CVOptionFlags>,
    displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn
{
    let renderer = unsafeBitCast(displayLinkContext, to: OpenglCore3CocoaRenderer.self)
    
    guard let context = renderer.openglView.openGLContext
        else { return kCVReturnError }
    context.makeCurrentContext()
    
    guard let cgl = context.cglContextObj
        else { return kCVReturnError }
    CGLLockContext(cgl)
    
    renderer.drawFrame()
    
    CGLFlushDrawable(cgl)
    CGLUnlockContext(cgl)
    return kCVReturnSuccess
}

/**
 This custom NSOpenGLView wrapper serves only to allow us to provide an override for NSOpenGLView's prepareOpenGL().
 
 NSOpenGLView, being an AppKit mechanism, generally must run its code on the main thread. This is true of prepareOpenGL() as well.
 A race exists in the CVDisplayLink code above where sometimes prepareOpenGL() has not been called yet by the NSOpenGLView implementation before the first run of CVDisplayLinkCallbackFunc.
 In this case, prepareOpenGL() gets called implicitly on the CVDisplayLink thread. To prevent this off-main-thread access. We can wait to start the CVDisplayLink until after prepareOpenGL() has been called.
 
 This also allows us a convenient place to do some one-time initialization of the OpenGL context; *but remember*, this is running on the main thread.
 */
private class CustomOpenglView: NSOpenGLView {
    
    typealias PrepareOpenglHandler = (_ context: NSOpenGLContext) -> ()
    
    /**
     CustomOpenglView will call didPrepareOpenGL (if non-nil) when its prepareOpenGL() method gets run by the NSOpenGLView implementation.
     
     didPrepareOpenGL is set to nil at the end of its prepareOpenGL() override.
     
     Setting didPrepareOpenGL *after* prepareOpenGL() has already been called will do nothing but retain the handler for the lifetime of the NSOpenGLView.
     So make sure and set didPrepareOpenGL early in the object's lifecycle. (ie. before it has a chance to draw)
     */
    var didPrepareOpenGL: PrepareOpenglHandler? = nil
    
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        guard let context = openGLContext
            else { print("Failed to obtain an NSOpenGLContext!"); return }
        
        didPrepareOpenGL?(context)
        didPrepareOpenGL = nil
    }
    
}
