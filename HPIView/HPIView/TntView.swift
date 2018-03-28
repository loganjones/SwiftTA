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
    
    typealias DrawFeaturesMethod = (_ rect: CGRect, _ context: CGContext) -> ()
    var drawFeatures: TntView.DrawFeaturesMethod?
    
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
        load(map, using: palette)
    }
    
    func load(_ map: MapModel, using palette: Palette) {
        switch map {
        case .ta(let model):
            let contentView = TaMapTileView(frame: NSRect(size: model.resolution))
            contentView.load(model, using: palette)
            contentView.drawFeatures = drawFeatures
            scrollView.documentView = contentView
        default:
            scrollView.documentView = nil
        }
    }
}

protocol TntViewFeatureProvider: class {
    func drawFeatures(in rect: CGRect, with context: CGContext)
}

class TaMapTileView: NSView {
    
    var drawFeatures: TntView.DrawFeaturesMethod?
    var showHeightMap: Bool = false
    
    fileprivate var map: TaMapModel?
    fileprivate var minHeight: CGFloat = 0
    fileprivate var maxHeight: CGFloat = 0
    fileprivate var tileSet = TileSet(tiles: [])
    
    func load(_ map: TaMapModel, using palette: Palette) {
        self.map = map
        minHeight = CGFloat(map.heightMap.min() ?? 0)
        maxHeight = CGFloat(map.heightMap.max() ?? 0)
        tileSet = TileSet(map.tileSet, palette)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        guard let map = map else {
            NSColor.white.setFill()
            context.fill(dirtyRect)
            return
        }
        
        NSColor.black.setFill()
        context.fill(dirtyRect)
        
        drawTiles(of: map, in: dirtyRect, with: context)
        
        if showHeightMap {
            NSColor.yellow.setStroke()
            strokeHeightGrid(of: map, in: dirtyRect)
        }
        
        if let drawFeatures = drawFeatures { drawFeatures(dirtyRect, context) }
        else {
            NSColor.red.setFill()
            fillFeatureDots(of: map, in: dirtyRect, with: context)
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
}

private extension TaMapTileView {
    
    final func drawTiles(of map: TaMapModel, in rect: NSRect, with context: CGContext) {
        let tileSize = map.tileSet.tileSize
        let rows = map.tileRows(in: rect)
        let columns = map.tileColumns(in: rect)
        map.tileIndexMap.eachIndex(inColumns: columns, rows: rows) { (index, column, row) in
            let tile = tileSet[index]
            context.draw(tile, in: CGRect(x: column * tileSize.width, y: row * tileSize.height, width: tile.width, height: tile.height))
        }
    }
    
    final func strokeHeightGrid(of map: TaMapModel, in rect: NSRect) {
        
        let minX = max(Int(floor(rect.minX / 16)), 0)
        let maxX = min(Int(ceil(rect.maxX / 16)), map.mapSize.width-1)
        let minY = max(Int(floor((rect.minY - maxHeight) / 16)), 0)
        let maxY = min(Int(ceil((rect.maxY + maxHeight) / 16)), map.mapSize.height-1)
        
        let path = NSBezierPath()
        for y in minY...maxY {
            let h0 = map.height(at: Point2D(x: minX, y: y)) / 2
            path.move(to: NSPoint(x: minX * 16, y: (y * 16) - h0))
            for x in (minX+1)...maxX {
                let h = map.height(at: Point2D(x: x, y: y)) / 2
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
                let h = map.height(at: Point2D(x: x, y: y)) / 2
                context.fillEllipse(in: CGRect(x: (x * 16) + 8, y: (y * 16) + 8 - h, width: 16, height: 16))
            }
        }
    }
    
}

private extension TaMapTileView {
    
    struct TileSet {
        
        var tiles: [CGImage]
        
        subscript(index: Int) -> CGImage {
            return tiles[index]
        }
        
        subscript(safe index: Int) -> CGImage? {
            guard tiles.indexRange.contains(index) else { return nil }
            return tiles[index]
        }
        
    }
    
}

private extension TaMapTileView.TileSet {
    
    init(_ tileSet: TaMapModel.TileSet, _ palette: Palette) {
        tiles = [CGImage]()
        tiles.reserveCapacity(tileSet.count)
        
        let tileByteLength = tileSet.tileSize.area
        var offset = 0
        
        for _ in 0..<tileSet.count {
            let tile = tileSet.tiles.subdata(in: offset..<(offset+tileByteLength))
            let image = CGImage.createWith(imageIndices: tile, size: tileSet.tileSize, palette: palette, isFlipped: true)
            tiles.append(image)
            offset += tileByteLength
        }
    }
    
}
