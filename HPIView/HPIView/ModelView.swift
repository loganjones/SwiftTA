//
//  ModelView.swift
//  HPIView
//
//  Created by Logan Jones on 7/5/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import AppKit
import SwiftTA_Core

class ModelViewController: NSViewController {
    
    private(set) var viewState = ModelViewState()
    private var modelLoader: ModelViewLoader!
    
    override func loadView() {
        let defaultFrame = NSRect(x: 0, y: 0, width: 640, height: 480)
        
        if let modelView: NSView & ModelViewLoader = nil
            ?? MetalModelView(modelViewFrame: defaultFrame, stateProvider: self)
            ?? OpenglModelView(modelViewFrame: defaultFrame, stateProvider: self)
        {
            view = modelView
            modelLoader = modelView
        }
        else {
            view = NSView(frame: defaultFrame)
            modelLoader = DummyModelViewLoader()
        }
    }
    
    func load(_ model: UnitModel) throws {
        try modelLoader.load(model)
    }
    
}

extension ModelViewController: ModelViewStateProvider {
    
    func viewportChanged(to size: CGSize) {
        viewState.viewportSize = size
        viewState.aspectRatio = Float(viewState.viewportSize.height) / Float(viewState.viewportSize.width)
        let w = Float(160)//Float( (unit.info.footprint.width + 8) * ModelViewState.gridSize )
        viewState.sceneSize = (width: w, height: w * viewState.aspectRatio)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if event.modifierFlags.contains(.shift) { viewState.rotateX += GLfloat(event.deltaX) }
        else if event.modifierFlags.contains(.option) { viewState.rotateY += GLfloat(event.deltaX) }
        else { viewState.rotateZ += GLfloat(event.deltaX) }
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.characters {
        case .some("w"):
            var drawMode = viewState.drawMode
            let i = drawMode.rawValue
            if let mode = ModelViewState.DrawMode(rawValue: i+1) { drawMode = mode }
            else { drawMode = .solid }
            viewState.drawMode = drawMode
//        case .some("t"):
//            viewState.textured = !viewState.textured
        case .some("l"):
            viewState.lighted = !viewState.lighted
        default:
            ()
        }
    }
    
}

struct ModelViewState {
    
    var viewportSize = CGSize()
    var aspectRatio: Float = 1
    var sceneSize: (width: Float, height: Float) = (0,0)
    
    static let gridSize = 16
    
    var drawMode = DrawMode.outlined
    var textured = false
    var lighted = true
    
    var rotateZ: GLfloat = 160
    var rotateX: GLfloat = 0
    var rotateY: GLfloat = 0
    
    enum DrawMode: Int {
        case solid
        case wireframe
        case outlined
    }
    
}

protocol ModelViewLoader {
    func load(_ model: UnitModel) throws
}
protocol ModelViewStateProvider: AnyObject {
    var viewState: ModelViewState { get }
    func viewportChanged(to size: CGSize)
    func mouseDragged(with event: NSEvent)
    func keyDown(with event: NSEvent)
}

private struct DummyModelViewLoader: ModelViewLoader {
    func load(_ model: UnitModel) throws {
        throw RuntimeError("No valid model view available to load model.")
    }
}
