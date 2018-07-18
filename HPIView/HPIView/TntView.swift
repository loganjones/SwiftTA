//
//  TntView.swift
//  HPIView
//
//  Created by Logan Jones on 7/18/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import AppKit

class TntViewController: NSViewController {
    
    private var tntView: TntViewLoader!
    
    override func loadView() {
        let deafultFrame = NSRect(x: 0, y: 0, width: 640, height: 480)
        
        if false { /* Nothing to see here */ }
        else {
            let cocoa = CocoaTntView(frame: deafultFrame)
            view = cocoa
            tntView = cocoa
        }
    }
    
    func load<File>(contentsOf tntFile: File, from filesystem: FileSystem) throws
        where File: FileReadHandle
    {
        let map = try MapModel(contentsOf: tntFile)
        switch map {
        case .ta(let model):
            let palette = try Palette.standardTaPalette(from: filesystem)
            tntView?.load(model, using: palette)
        case .tak(let model):
            tntView?.load(model, from: filesystem)
        }
    }
    
    // The load methods without a filesystem are retained for HPIView support.
    // Consider this temporary.
    
    func load<File>(contentsOf tntFile: File, using palette: Palette) throws
        where File: FileReadHandle
    {
        let map = try MapModel(contentsOf: tntFile)
        switch map {
        case .ta(let model):
            tntView?.load(model, using: palette)
        case .tak(_):
            //tntView?.load(model, from: filesystem)
            print("!!! TAK TNT files are not supported for viewing when the complete filesystem is not available.")
            tntView?.clear()
        }
    }
    
}

protocol TntViewLoader {
    func load(_ map: TaMapModel, using palette: Palette)
    func load(_ map: TakMapModel, from filesystem: FileSystem)
    func clear()
}
