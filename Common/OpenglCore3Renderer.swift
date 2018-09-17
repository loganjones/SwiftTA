//
//  OpenglCore3Renderer.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 9/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import OpenGL


class OpenglCore3Renderer: GameRenderer {
    
    var viewState: GameViewState
    fileprivate let openglView: NSOpenGLView
    private let displayLink: CVDisplayLink
    private var tnt: OpenglCore3TntDrawable?
    
    fileprivate var loadedState: GameState?
    
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
        guard let openglView = NSOpenGLView(frame: CGRect(size: viewState.viewport.size), pixelFormat: format) else { return nil }
        openglView.wantsBestResolutionOpenGLSurface = true
        
        var dl: CVDisplayLink?
        let rv = CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let displayLink = dl else {
            print("Failed to create CVDisplayLink! \(rv)")
            return nil
        }
        
        self.loadedState = loadedState
        self.viewState = viewState
        self.openglView = openglView
        self.displayLink = displayLink
        
        let p = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(displayLink, CVDisplayLinkCallbackFunc, p)
        CVDisplayLinkStart(displayLink)
    }
    
    deinit {
        CVDisplayLinkStop(displayLink)
    }
    
    #if canImport(AppKit)
    var view: NSView { return openglView }
    #elseif canImport(UIKit)
    var view: UIView { return openglView }
    #endif
    
    fileprivate func prepareOpenGL(context: NSOpenGLContext) {
        var swapInt: GLint = 1
        context.setValues(&swapInt, for: .swapInterval)
    }
    
    fileprivate func load(state loaded: GameState) {
        
        do {
            let tnt: OpenglCore3TntDrawable
            
            if false {//loaded.map.resolution.max > metalDevice.maximum2dTextureSize {
                fatalError("Using tiled tnt renderer")
                //tnt = MetalTiledTntDrawable(metalDevice)
            }
            else {
                print("Using simple tnt renderer")
                tnt = try OpenglCore3OneTextureTntDrawable(for: loaded.map, from: loaded.filesystem)
            }
            
            self.tnt = tnt
        }
        catch {
            print("Failed to load map: \(error)")
        }
    }
    
    fileprivate func drawFrame(_ currentTime: Double, _ deltaTime: Double) {
        
        tnt?.setupNextFrame(viewState)
        
        glClearColor(1, 0, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        tnt?.drawFrame()
    }
    
}

protocol OpenglCore3TntDrawable {
    func setupNextFrame(_ viewState: GameViewState)
    func drawFrame()
}

private func CVDisplayLinkCallbackFunc(
    displayLink: CVDisplayLink,
    now: UnsafePointer<CVTimeStamp>,
    outputTime: UnsafePointer<CVTimeStamp>,
    flagsIn: CVOptionFlags,
    flagsOut: UnsafeMutablePointer<CVOptionFlags>,
    displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn
{
    let renderer = unsafeBitCast(displayLinkContext, to: OpenglCore3Renderer.self)
    
    let currentTime = Double(now.pointee.videoTime) / Double(now.pointee.videoTimeScale)
    let deltaTime = 1.0 / (outputTime.pointee.rateScalar * Double(outputTime.pointee.videoTimeScale) / Double(outputTime.pointee.videoRefreshPeriod))
    
    guard let context = renderer.openglView.openGLContext
        else { return kCVReturnError }
    context.makeCurrentContext()
    
    guard let cgl = context.cglContextObj
        else { return kCVReturnError }
    CGLLockContext(cgl)
    
    if let firstTimeLoad = renderer.loadedState {
        renderer.prepareOpenGL(context: context)
        renderer.load(state: firstTimeLoad)
        renderer.loadedState = nil
    }
    
    renderer.drawFrame(currentTime, deltaTime)
    
    CGLFlushDrawable(cgl)
    CGLUnlockContext(cgl)
    return kCVReturnSuccess
}
