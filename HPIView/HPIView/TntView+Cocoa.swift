//
//  TntView+Cocoa.swift
//  HPIView
//
//  Created by Logan Jones on 6/3/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import AppKit
import SwiftTA_Core

class CocoaTntView: NSView, TntViewLoader {
    
    private unowned let scrollView: NSScrollView
    
    typealias DrawFeaturesMethod = (_ rect: CGRect, _ context: CGContext) -> ()
    var drawFeatures: CocoaTntView.DrawFeaturesMethod?
    
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
    
    func load(_ map: TaMapModel, using palette: Palette) {
        let contentView = TaMapTileView(frame: NSRect(size: map.resolution))
        contentView.load(map, using: palette)
        contentView.drawFeatures = drawFeatures
        scrollView.documentView = contentView
    }
    
    func load(_ map: TakMapModel, from filesystem: FileSystem) {
        let contentView = TakMapTileView(frame: NSRect(size: map.resolution))
        contentView.load(map, filesystem)
        contentView.drawFeatures = drawFeatures
        scrollView.documentView = contentView
    }
    
    func clear() {
        drawFeatures = nil
        scrollView.documentView = nil
    }
    
}

protocol TntViewFeatureProvider: class {
    func drawFeatures(in rect: CGRect, with context: CGContext)
}

// MARK:- TA

class TaMapTileView: NSView {
    
    var drawFeatures: CocoaTntView.DrawFeaturesMethod?
    var showHeightMap: Bool = false
    
    fileprivate var map: TaMapModel?
    fileprivate var minHeight: CGFloat = 0
    fileprivate var maxHeight: CGFloat = 0
    fileprivate var tileSet = TileSet(tiles: [])
    
    func load(_ map: TaMapModel, using palette: Palette) {
        self.map = map
        minHeight = CGFloat(map.heightMap.samples.min() ?? 0)
        maxHeight = CGFloat(map.heightMap.samples.max() ?? 0)
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
        let rows = map.tileRows(in: Rect4f(rect))
        let columns = map.tileColumns(in: Rect4f(rect))
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
            let h0 = map.height(at: Point2<Int>(x: minX, y: y)) / 2
            path.move(to: NSPoint(x: minX * 16, y: (y * 16) - h0))
            for x in (minX+1)...maxX {
                let h = map.height(at: Point2<Int>(x: x, y: y)) / 2
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
                guard map.featureIndex(at: Point2<Int>(x: x, y: y)) != nil else { continue }
                let h = map.height(at: Point2<Int>(x: x, y: y)) / 2
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
            guard tiles.indices.contains(index) else { return nil }
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
            let image = try! CGImage.createWith(imageIndices: tile, size: tileSet.tileSize, palette: palette, isFlipped: true)
            tiles.append(image)
            offset += tileByteLength
        }
    }
    
}

// MARK:- TAK

class TakMapTileView: NSView {
    
    var drawFeatures: CocoaTntView.DrawFeaturesMethod?
    var showHeightMap: Bool = false
    
    fileprivate var map: TakMapModel?
    fileprivate var minHeight: CGFloat = 0
    fileprivate var maxHeight: CGFloat = 0
    fileprivate var terrain = TerrainSet(images: [:])
    
    func load(_ map: TakMapModel, _ filesystem: FileSystem) {
        self.map = map
        minHeight = CGFloat(map.heightMap.samples.min() ?? 0)
        maxHeight = CGFloat(map.heightMap.samples.max() ?? 0)
        terrain = TerrainSet(map.tileIndexMap.uniqueNames, filesystem)
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

private extension TakMapTileView {
    
    final func drawTiles(of map: TakMapModel, in rect: NSRect, with context: CGContext) {
        
        let tileSize = map.tileSize
        let rows = map.tileRows(in: Rect4f(rect))
        let columns = map.tileColumns(in: Rect4f(rect))
        
        map.tileIndexMap.eachTile(inColumns: columns, rows: rows) { (name, imageColumn, imageRow, mapColumn, mapRow) in
            
            let rect = CGRect(x: mapColumn * tileSize.width, y: mapRow * tileSize.height, width: tileSize.width, height: tileSize.height)
            
            guard let image = terrain[name],
                let tile = image.cropping(to: CGRect(x: imageColumn * tileSize.width, y: imageRow * tileSize.height, width: tileSize.width, height: tileSize.height)) else {
                context.fill(rect)
                return
            }
            
            context.saveGState()
            context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(tile, in: CGRect(x: rect.origin.x, y: 0, width: rect.size.width, height: rect.size.height))
            context.restoreGState()
        }
        
    }
    
    final func strokeHeightGrid(of map: TakMapModel, in rect: NSRect) {
        
        let minX = max(Int(floor(rect.minX / 16)), 0)
        let maxX = min(Int(ceil(rect.maxX / 16)), map.mapSize.width-1)
        let minY = max(Int(floor((rect.minY - maxHeight) / 16)), 0)
        let maxY = min(Int(ceil((rect.maxY + maxHeight) / 16)), map.mapSize.height-1)
        
        let path = NSBezierPath()
        for y in minY...maxY {
            let h0 = map.height(at: Point2<Int>(x: minX, y: y)) / 2
            path.move(to: NSPoint(x: minX * 16, y: (y * 16) - h0))
            for x in (minX+1)...maxX {
                let h = map.height(at: Point2<Int>(x: x, y: y)) / 2
                path.line(to: NSPoint(x: x * 16, y: (y * 16) - h))
            }
        }
        path.close()
        path.stroke()
    }
    
    final func fillFeatureDots(of map: TakMapModel, in rect: NSRect, with context: CGContext) {
        
        let minX = max(Int(floor(rect.minX / 16)), 0)
        let maxX = min(Int(ceil(rect.maxX / 16)), map.mapSize.width-1)
        let minY = max(Int(floor((rect.minY - maxHeight) / 16)), 0)
        let maxY = min(Int(ceil((rect.maxY + maxHeight) / 16)), map.mapSize.height-1)
        
        for y in minY...maxY {
            for x in minX...maxX {
                guard map.featureIndex(at: Point2<Int>(x: x, y: y)) != nil else { continue }
                let h = map.height(at: Point2<Int>(x: x, y: y)) / 2
                context.fillEllipse(in: CGRect(x: (x * 16) + 8, y: (y * 16) + 8 - h, width: 16, height: 16))
            }
        }
    }
    
}

private extension TakMapTileView {
    
    struct TerrainSet {
        
        var images: [UInt32: CGImage]
        
        subscript(index: UInt32) -> CGImage? {
            return images[index]
        }
        
    }
    
}

private extension TakMapTileView.TerrainSet {
    
    init(_ nameSet: Set<UInt32>, _ filesystem: FileSystem) {
        images = [UInt32: CGImage]()
        images.reserveCapacity(nameSet.count)
        
        guard let terrrainDirectory = filesystem.root[directory: "terrain"] else { return }
        
        nameSet.forEach {
            let filename = String($0, radix: 16).padLeft(with: "0", toLength: 8)
            guard let f = terrrainDirectory[file: "\(filename).jpg"], let file = try? filesystem.openFile(f) else { return }
            let data = file.readDataToEndOfFile()
            guard let image = CGImage(jpegDataProviderSource: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
            images[$0] = image
        }
        
    }
    
}
