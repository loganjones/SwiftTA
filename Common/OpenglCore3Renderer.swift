//
//  OpenglCore3Renderer.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 9/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation
import SwiftTA_Core

#if canImport(OpenGL)
import OpenGL
#else
import Cgl
#endif


class OpenglCore3Renderer: SwiftTA_Core.RunLoopGameRenderer {
    
    var viewState: GameViewState
    private var tnt: OpenglCore3TntDrawable?
    private var features: OpenglCore3FeatureDrawable?
    private var units: OpenglCore3UnitDrawable?
    
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
            units = try OpenglCore3UnitDrawable(loaded.units, sides: loaded.sides, filesystem: loaded.filesystem)
        }
        catch {
            print("Failed to load map: \(error)")
            printGlErrors(prefix: "OpenGL Errors: ")
        }
    }
    
    func drawFrame() {
        guard let tnt = tnt, let features = features, let units = units else { return }
        
        tnt.setupNextFrame(viewState)
        features.setupNextFrame(viewState)
        let ufs = units.setupNextFrame(viewState)
        
        glClearColor(1, 0, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        tnt.drawFrame()
        features.drawFrame()
        units.drawFrame(ufs)
    }
    
}

protocol OpenglCore3TntDrawable {
    func setupNextFrame(_ viewState: GameViewState)
    func drawFrame()
}
