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
    
    var map: TaMapModel? {
        didSet {
            guard let map = map else { return }
            minHeight = CGFloat(map.heightMap.min() ?? 0)
            maxHeight = CGFloat(map.heightMap.max() ?? 0)
        }
    }
    var palette: Palette?
    fileprivate var minHeight: CGFloat = 0
    fileprivate var maxHeight: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        guard let map = map, let palette = palette else {
            NSColor.white.setFill()
            context.fill(dirtyRect)
            return
        }
        
        NSColor.black.setFill()
        context.fill(dirtyRect)
        
        drawTiles(of: map, in: dirtyRect, with: context, palette: palette)
        
        //NSColor.yellow.setStroke()
        //strokeHeightGrid(of: map, in: dirtyRect)
        
        NSColor.red.setFill()
        fillFeatureDots(of: map, in: dirtyRect, with: context)
    }
    
    override var isFlipped: Bool {
        return true
    }
    
}

private extension TaMapTileView {
    
    final func drawTiles(of map: TaMapModel, in rect: NSRect, with context: CGContext, palette: Palette) {
        let tileSize = map.tileSet.tileSize
        var cache: [Int: CGImage] = [:]
        map.eachTile(in: rect) { (tile, index, column, row) in
            let image: CGImage
            if let cached = cache[index] { image = cached }
            else {
                image = CGImage.createWith(imageIndices: tile, size: tileSize, palette: palette, isFlipped: true)
                cache[index] = image
            }
            context.draw(image, in: CGRect(x: column * tileSize.width, y: row * tileSize.height, width: image.width, height: image.height))
        }
    }
    
    final func strokeHeightGrid(of map: TaMapModel, in rect: NSRect) {
        
        let minX = max(Int(floor(rect.minX / 16)), 0)
        let maxX = min(Int(ceil(rect.maxX / 16)), map.mapSize.width-1)
        let minY = max(Int(floor((rect.minY - maxHeight) / 16)), 0)
        let maxY = min(Int(ceil((rect.maxY + maxHeight) / 16)), map.mapSize.height-1)
        
        let path = NSBezierPath()
        for y in minY...maxY {
            let h0 = map.height(at: Point2D(x: minX, y: y))
            path.move(to: NSPoint(x: minX * 16, y: (y * 16) - h0))
            for x in (minX+1)...maxX {
                let h = map.height(at: Point2D(x: x, y: y))
                path.line(to: NSPoint(x: x * 16, y: (y * 16) - h))
            }
        }
        path.close()
        path.stroke()
    }
    
    final func fillFeatureDots(of map: TaMapModel, in rect: NSRect, with context: CGContext) {
        
        let minX = max(Int(floor(rect.minX / 16)), 0)
        let maxX = min(Int(ceil(rect.maxX / 16)), map.mapSize.width-1)
        let minY = max(Int(floor((rect.minY - maxHeight) / 16)), 0)
        let maxY = min(Int(ceil((rect.maxY + maxHeight) / 16)), map.mapSize.height-1)
        
        for y in minY...maxY {
            for x in minX...maxX {
                guard map.featureIndex(at: Point2D(x: x, y: y)) != nil else { continue }
                let h = map.height(at: Point2D(x: x, y: y))
                context.fillEllipse(in: CGRect(x: (x * 16) - 8, y: (y * 16) - (8 + h), width: 16, height: 16))
            }
        }
    }
    
}
