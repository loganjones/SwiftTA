//
//  OpenglCore3Renderer.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 9/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation

#if canImport(OpenGL)
import OpenGL
#else
import Cgl
#endif


class OpenglCore3Renderer: RunLoopGameRenderer {
    
    var viewState: GameViewState
    private var tnt: OpenglCore3TntDrawable?
    private var features: OpenglCore3FeatureDrawable?
    
    required init?(loadedState: GameState, viewState: GameViewState) {
        self.viewState = viewState
    }
    
    func load(state loaded: GameState) {
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
            features = try OpenglCore3FeatureDrawable(loaded.features, containedIn: loaded.map, filesystem: loaded.filesystem)
        }
        catch {
            print("Failed to load map: \(error)")
            printGlErrors(prefix: "OpenGL Errors: ")
        }
    }
    
    func drawFrame() {
        
        tnt?.setupNextFrame(viewState)
        features?.setupNextFrame(viewState)
        
        glClearColor(1, 0, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        tnt?.drawFrame()
        features?.drawFrame()
    }
    
}

protocol OpenglCore3TntDrawable {
    func setupNextFrame(_ viewState: GameViewState)
    func drawFrame()
}
