//
//  TntView.swift
//  HPIView
//
//  Created by Logan Jones on 6/3/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import AppKit


class TntView: NSView {
    
    private unowned let scrollView: NSScrollView
    
    override init(frame frameRect: NSRect) {
        
        let scrollView = NSScrollView(frame: frameRect)
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.wantsLayer = true
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        
        self.scrollView = scrollView
        super.init(frame: frameRect)
        
        addSubview(scrollView)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func load<File>(contentsOf tntFile: File, using palette: Palette) throws
        where File: FileReadHandle
    {
        let map = try MapModel(contentsOf: tntFile)
        switch map {
        case .ta(let model):
            let contentView = TaMapTileView(frame: NSRect(size: model.resolution))
            contentView.map = model
            contentView.palette = palette
            scrollView.documentView = contentView
        default:
            scrollView.documentView = nil
        }
    }
}

class TaMapTileView: NSView {
    
    var map: TaMapModel?
    var palette: Palette?

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        guard let map = map, let palette = palette else {
            NSColor.white.setFill()
            context.fill(dirtyRect)
            return
        }
        
        NSColor.black.setFill()
        context.fill(dirtyRect)
        
        var cache: [Int: CGImage] = [:]
        map.eachTile(in: dirtyRect) { (tile, index, column, row) in
            let image: CGImage
            if let cached = cache[index] { image = cached }
            else {
                image = CGImage.createWith(imageIndices: tile, size: map.tileSize, palette: palette, isFlipped: true)
                cache[index] = image
            }
            context.draw(image, in: CGRect(x: column * map.tileSize.width, y: row * map.tileSize.height, width: image.width, height: image.height))
        }
        
    }
    
    override var isFlipped: Bool {
        return true
    }
    
}
