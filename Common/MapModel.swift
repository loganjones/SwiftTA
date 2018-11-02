//
//  MapModel.swift
//  TAassets
//
//  Created by Logan Jones on 3/13/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation
#if canImport(Ctypes)
import Ctypes
#endif


enum MapModel {
    case ta(TaMapModel)
    case tak(TakMapModel)
}

extension MapModel {
    
    init<File>(contentsOf tntFile: File) throws
        where File: FileReadHandle
    {
        let header = try tntFile.readValue(ofType: TA_TNT_HEADER.self)
        switch header.version {
        case TA_TNT_TOTAL_ANNIHILATION:
            self = .ta(try TaMapModel(header.mapSize, reading: tntFile))
        case TA_TNT_KINGDOMS:
            self = .tak(try TakMapModel(header.mapSize, reading: tntFile))
        default:
            throw LoadModelError.unsupportedTntVesion(header.version)
        }
    }
    
    enum LoadModelError: Error {
        case unsupportedTntVesion(Int32)
    }
    
}

protocol MapModelType {
    
    var mapSize: Size2<Int> { get }
    var resolution: Size2<Int> { get }
    
    var seaLevel: Int { get }
    var heightMap: HeightMap { get }
    
    var features: [FeatureTypeId] { get }
    var featureMap: [Int?] { get }
    
    var minimap: MinimapImage { get }
    
}

extension MapModelType {
    
    var resolution: Size2<Int> {
        return mapSize * 16
    }
    
    func height(at point: Point2<Int>) -> Int {
        return heightMap.height(atMapPosition: point)
    }
    
    func featureIndex(at point: Point2<Int>) -> Int? {
        let index = (point.y * mapSize.width) + point.x
        return featureMap[index]
    }
    
}

extension MapModel: MapModelType {
    
    var mapSize: Size2<Int> {
        switch self {
        case .ta(let model): return model.mapSize
        case .tak(let model): return model.mapSize
        }
    }
    
    var resolution: Size2<Int> {
        switch self {
        case .ta(let model): return model.resolution
        case .tak(let model): return model.resolution
        }
    }
    
    var seaLevel: Int {
        switch self {
        case .ta(let model): return model.seaLevel
        case .tak(let model): return model.seaLevel
        }
    }
    
    var heightMap: HeightMap {
        switch self {
        case .ta(let model): return model.heightMap
        case .tak(let model): return model.heightMap
        }
    }
    
    var features: [FeatureTypeId] {
        switch self {
        case .ta(let model): return model.features
        case .tak(let model): return model.features
        }
    }
    
    var featureMap: [Int?] {
        switch self {
        case .ta(let model): return model.featureMap
        case .tak(let model): return model.featureMap
        }
    }
    
    var minimap: MinimapImage {
        switch self {
        case .ta(let model): return model.minimap
        case .tak(let model): return model.minimap
        }
    }
    
}

private extension TA_TNT_HEADER {
    var mapSize: Size2<Int> {
        return Size2(width: Int(self.width), height: Int(self.height))
    }
}

// MARK:- Height Map

/**
 A collection of height samples across a 2D map grid.
 
 Use `height(atMapPosition:)` to get a specific height sample for a particular point on the map;
 
 or use `height(atWorldPosition:)` to interpolate the nearby height samples of a world position.
 */
struct HeightMap {
    
    /// The collection of height values that make up this height map.
    var samples: [Int]
    
    /// The number of samples in each dimension (width and height) of the 2D map grid.
    /// (where width * height denote the total count of samples)
    var sampleCount: Size2<Int>
    
    /// The size of each grid square in world space.
    /// (Usually 16x16)
    let sampleSize: Size2<Int>
    
    /// Initialize a height map with some samples.
    init(samples: [Int], count: Size2<Int>, sampleSize: Size2<Int> = Size2(16,16)) {
        self.samples = samples
        self.sampleCount = count
        self.sampleSize = sampleSize
    }
    
}

extension HeightMap {
    
    /// Computes the map index of the given point in map space.
    /// NOTE: No bounds checking is performed. A point out of bounds will not result in a valid map index.
    func index(ofMapPosition point: Point2<Int>) -> Int {
        return point.index(rowStride: sampleSize.width)
    }
    
    /// The height sample of the given map index.
    /// NOTE: No bounds checking is performed. An index out of bounds will trap when the sample access is attempted.
    func height(atMapIndex index: Int) -> Int {
        return samples[index]
    }
    
    /// The height sample of the given point in map space.
    /// NOTE: No bounds checking is performed. A point out of bounds will trap when the sample access is attempted.
    func height(atMapPosition point: Point2<Int>) -> Int {
        let index = point.index(rowStride: sampleSize.width)
        return samples[index]
    }
    
    /**
     Approximates the height of a given world position from the height map.
     
     The world position is mapped into a grid square of the height map. Each of the nearest four corner's samples is then interpolated to estimate the height at `p`.
     ```
     a-------b
     |       |
     |   p   |   ->   bilinearInterpolation(a,b,c,d)   ->   height
     |       |
     c-------d
     ```
     */
    func height(atWorldPosition p: Point2f) -> GameFloat {
        
        let ps = p / Size2f(sampleSize)
        let sc = Size2f(sampleCount)
        
        // If the position is outside one of the map's bounds,
        // try to do a simpler linear interpolation.
        
        // Outside of the width?
        guard ps.x > 0 else { return height(atSamplePositionY: ps.y, x0: 0) }
        guard ps.x < sc.width-1 else { return height(atSamplePositionY: ps.y, x0: sampleCount.width-1) }
        // Outside of the height?
        guard ps.y > 0 else { return height(atSamplePositionX: ps.x, y0: 0) }
        guard ps.y < sc.height-1 else { return height(atSamplePositionX: ps.x, y0: sampleCount.height-1) }
        
        // The nearest top-left map point is `p0`.
        // We will interpolate `p0`, the point right of it, the point beneath it, and the point beneath and to the right of it.
        
        let p0 = ps.map { Int(floor($0)) }
        let w = sampleCount.width
        let i = p0.index(rowStride: w)
        
        let h00 = GameFloat(samples[i])
        let h10 = GameFloat(samples[i+1])
        let h01 = GameFloat(samples[i+w])
        let h11 = GameFloat(samples[i+w+1])
        
        return bilinearInterpolation(h00, h10, h01, h11, ps.x - GameFloat(p0.x), ps.y - GameFloat(p0.y))
    }
    
    /// With the `x` position fixed, reduce the approximation to a linear interpolation between a sample above and below.
    private func height(atSamplePositionY ys: GameFloat, x0: Int) -> GameFloat {
        
        // If the 'y' position is outside of the map's height bounds,
        // then just return the sample at the nearest corner.
        guard ys > 0 else { return GameFloat(height(atMapPosition: Point2(x0,0))) }
        guard ys < GameFloat(sampleCount.height) else { return GameFloat(height(atMapPosition: Point2(x0,sampleCount.height-1))) }
        
        // The nearest top-left map point is `x0,y0`.
        // We will interpolate `x0,y0` and the point beneath it.
        
        let y0 = Int(floor(ys))
        let w = sampleCount.width
        let i = Point2(x0,y0).index(rowStride: w)
        
        let h0 = GameFloat(samples[i])
        let h1 = GameFloat(samples[i+w])
        
        return linearInterpolation(h0, h1, ys - GameFloat(y0))
    }
    
    /// With the `y` position fixed, reduce the approximation to a linear interpolation between a sample left and right.
    private func height(atSamplePositionX xs: GameFloat, y0: Int) -> GameFloat {
        
        // NOTE: height(atWorldPosition:) should have already checked the `x` position against the map's width bounds, no need to do it again.
        
        // The nearest top-left map point is `x0,y0`.
        // We will interpolate `x0,y0` and the point right of it.
        
        let x0 = Int(floor(xs))
        let w = sampleCount.width
        let i = Point2(x0,y0).index(rowStride: w)
        
        let h0 = GameFloat(samples[i])
        let h1 = GameFloat(samples[i+1])
        
        return linearInterpolation(h0, h1, xs - GameFloat(x0))
    }
    
}

// MARK:- TA

struct TaMapModel: MapModelType {
    
    var mapSize: Size2<Int>
    
    var tileSet: TileSet
    var tileIndexMap: TileIndexMap
    
    var seaLevel: Int
    var heightMap: HeightMap
    var featureMap: [Int?]
    var features: [FeatureTypeId]
    
    var minimap: MinimapImage
    
}

extension TaMapModel {
    
    func tileColumns(in rect: Rect4f) -> CountableClosedRange<Int> {
        let tileWidth = tileSet.tileSize.width
        let start = Int(floor(rect.minX)) / tileWidth
        var end = Int(ceil(rect.maxX)) / tileWidth
        if GameFloat(end * tileWidth) < rect.maxX { end += 1 }
        return max(start,0)...min(end, tileIndexMap.size.width-1)
    }
    
    func tileRows(in rect: Rect4f) -> CountableClosedRange<Int> {
        let tileheight = tileSet.tileSize.height
        let start = Int(floor(rect.minY)) / tileheight
        var end = Int(ceil(rect.maxY)) / tileheight
        if GameFloat(end * tileheight) < rect.maxY { end += 1 }
        return max(start,0)...min(end, tileIndexMap.size.height-1)
    }
    
    func eachTile(in rect: Rect4f, visit: (_ tile: Data, _ index: Int, _ column: Int, _ row: Int) -> ()) {
        let rows = tileRows(in: rect)
        let columns = tileColumns(in: rect)
        tileIndexMap.eachIndex(inColumns: columns, rows: rows) { (index, column, row) in
            let tile = tileSet[index]
            visit(tile, index, column, row)
        }
    }
    
}

private extension TaMapModel {
    
    init<File>(_ mapSize: Size2<Int>, reading tntFile: File) throws where File: FileReadHandle {
        self.mapSize = mapSize
        let tileSize = Size2<Int>(32, 32)
        
        let header = try tntFile.readValue(ofType: TA_TNT_EXT_HEADER.self)
        seaLevel = Int(header.seaLevel)
        
        tntFile.seek(toFileOffset: header.offsetToTileIndexArray)
        let tileIndexCount = mapSize / 2
        let tileIndexData = try tntFile.readData(verifyingLength: tileIndexCount.area * MemoryLayout<UInt16>.size)
        tileIndexMap = TileIndexMap(indices: tileIndexData, size: tileIndexCount, tileSize: tileSize)
        
        tntFile.seek(toFileOffset: header.offsetToMapInfoArray)
        let entries = try tntFile.readArray(ofType: TA_TNT_MAP_ENTRY.self, count: mapSize.area)
        heightMap = HeightMap(samples: entries.map { Int($0.elevation) }, count: mapSize)
        
        tntFile.seek(toFileOffset: header.offsetToTileArray)
        let tiles = try tntFile.readData(verifyingLength: Int(header.numberOfTiles) * tileSize.area)
        tileSet = TileSet(tiles: tiles, count: Int(header.numberOfTiles), tileSize: tileSize)
        
        tntFile.seek(toFileOffset: header.offsetToFeatureEntryArray)
        features = try tntFile.readArray(ofType: TA_TNT_FEATURE_ENTRY.self, count: Int(header.numberOfFeatures)).map { FeatureTypeId(named: $0.nameString) }
        
        let featureIndexRange = 0..<features.count
        featureMap = entries.map {
            let i = Int($0.special)
            guard featureIndexRange.contains(i) else { return nil }
            return i
        }
        
        tntFile.seek(toFileOffset: header.offsetToMiniMap)
        minimap = try MinimapImage.readFrom(file: tntFile)
        
    }
    
}

private extension TA_TNT_FEATURE_ENTRY {
    var nameString: String {
        var tuple = self.name
        return withUnsafePointer(to: &tuple) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 128) { String(cString: $0) }
        }
    }
}

extension TaMapModel {
    
    struct TileSet {
        var tiles: Data
        var count: Int
        let tileSize: Size2<Int>
        
        subscript(index: Int) -> Data {
            let count = tileSize.area
            let offset = index * count
            return tiles.subdata(in: offset..<(offset + count))
        }
        
        subscript(safe index: Int) -> Data? {
            guard (0..<count).contains(index) else { return nil }
            return self[index]
        }
    }
    
}

extension TaMapModel {
    
    struct TileIndexMap {
        var indices: Data
        var size: Size2<Int>
        let tileSize: Size2<Int>
        
        func eachIndex<R>(inColumns columns: R, rows: R, visit: (_ index: Int, _ column: Int, _ row: Int) -> ())
            where R: Sequence, R.Element == Int
        {
            indices.withUnsafeBytes() { (buffer: UnsafePointer<UInt8>) in
                let p = UnsafeRawPointer(buffer).bindMemoryBuffer(to: UInt16.self, capacity: size.area)
                for row in rows {
                    if row >= size.height { break }
                    for column in columns {
                        if column >= size.width { break }
                        let index = p[(row * size.width) + column]
                        visit(Int(index), column, row)
                    }
                }
            }
        }
        
        func eachIndex(in rect: Rect4<Int>, visit: (_ index: Int, _ column: Int, _ row: Int) -> ()) {
            eachIndex(inColumns: rect.widthRange, rows: rect.heightRange, visit: visit)
        }
        
    }
    
}

extension TaMapModel {
    
    func convertTilesBGRA(using palette: Palette) -> UnsafeBufferPointer<UInt8> {
        
        let tntTileSize = tileSet.tileSize
        let tileBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: tileSet.count * tntTileSize.area * 4)
        
        tileSet.tiles.withUnsafeBytes() {
            (sourceTiles: UnsafePointer<UInt8>) in
            let sourceCount = tntTileSize.area * tileSet.count
            for sourceIndex in 0..<sourceCount {
                let destinationIndex = sourceIndex * 4
                let colorIndex = Int(sourceTiles[sourceIndex])
                tileBuffer[destinationIndex+0] = palette[colorIndex].blue
                tileBuffer[destinationIndex+1] = palette[colorIndex].green
                tileBuffer[destinationIndex+2] = palette[colorIndex].red
                tileBuffer[destinationIndex+3] = 255
            }
        }
        
        return UnsafeBufferPointer(tileBuffer)
    }
    
}

// MARK:- TAK

struct TakMapModel: MapModelType {
    var mapSize: Size2<Int>
    
    var seaLevel: Int
    var heightMap: HeightMap
    var featureMap: [Int?]
    var features: [FeatureTypeId]
    
    var tileIndexMap: TileIndexMap
    
    var largeMinimap: MinimapImage
    var smallMinimap: MinimapImage
    
    let tileSize: Size2<Int>
}

extension TakMapModel {
    
    var minimap: MinimapImage {
        return smallMinimap
    }
    
}

extension TakMapModel {
    
    func tileColumns(in rect: Rect4f) -> CountableClosedRange<Int> {
        let tileWidth = tileSize.width
        let start = Int(floor(rect.minX)) / tileWidth
        var end = Int(ceil(rect.maxX)) / tileWidth
        if GameFloat(end * tileWidth) < rect.maxX { end += 1 }
        return max(start,0)...min(end, tileIndexMap.size.width-1)
    }
    
    func tileRows(in rect: Rect4f) -> CountableClosedRange<Int> {
        let tileheight = tileSize.height
        let start = Int(floor(rect.minY)) / tileheight
        var end = Int(ceil(rect.maxY)) / tileheight
        if GameFloat(end * tileheight) < rect.maxY { end += 1 }
        return max(start,0)...min(end, tileIndexMap.size.height-1)
    }
    
}

private extension TakMapModel {
    
    init<File>(_ mapSize: Size2<Int>, reading tntFile: File) throws where File: FileReadHandle {
        self.mapSize = mapSize
        tileSize = Size2<Int>(32, 32)
        
        let header = try tntFile.readValue(ofType: TAK_TNT_EXT_HEADER.self)
        seaLevel = Int(header.seaLevel)
        
        tntFile.seek(toFileOffset: header.offsetToHeightMap)
        let heights = try tntFile.readArray(ofType: UInt8.self, count: mapSize.area).map { Int($0) }
        heightMap = HeightMap(samples: heights, count: mapSize)
        
        tntFile.seek(toFileOffset: header.offsetToFeatureEntryArray)
        features = try tntFile.readArray(ofType: TA_TNT_FEATURE_ENTRY.self, count: Int(header.numberOfFeatures)).map { FeatureTypeId(named: $0.nameString) }
        
        let featureIndexRange = 0..<features.count
        tntFile.seek(toFileOffset: header.offsetToFeatureSpotArray)
        featureMap = try tntFile.readArray(ofType: UInt16.self, count: mapSize.area).map {
            let i = Int($0)
            guard featureIndexRange.contains(i) else { return nil }
            return i
        }
        
        let tileIndexCount = mapSize / 2
        tntFile.seek(toFileOffset: header.offsetToTileNameArray)
        let tileNames = try tntFile.readArray(ofType: UInt32.self, count: tileIndexCount.area)
        tntFile.seek(toFileOffset: header.offsetToColumnIndexArray)
        let tileColumns = try tntFile.readArray(ofType: UInt8.self, count: tileIndexCount.area)
        tntFile.seek(toFileOffset: header.offsetToRowIndexArray)
        let tileRows = try tntFile.readArray(ofType: UInt8.self, count: tileIndexCount.area)
        tileIndexMap = TileIndexMap(names: tileNames, columns: tileColumns, rows: tileRows, size: tileIndexCount, tileSize: tileSize)

        tntFile.seek(toFileOffset: header.offsetToLargeMiniMap)
        largeMinimap = try MinimapImage.readFrom(file: tntFile)
        
        tntFile.seek(toFileOffset: header.offsetToSmallMiniMap)
        smallMinimap = try MinimapImage.readFrom(file: tntFile)
    }
    
}

extension TakMapModel {
    
    struct TileIndexMap {
        var names: [UInt32]
        var columns: [UInt8]
        var rows: [UInt8]
        var size: Size2<Int>
        let tileSize: Size2<Int>
    }
    
}

extension TakMapModel.TileIndexMap {
    
    var uniqueNames: Set<UInt32> {
        return names.reduce(into: Set<UInt32>()) { $0.insert($1) }
    }
    
    func eachTile<R>(inColumns mapColumns: R, rows mapRows: R, visit: (_ imageName: UInt32, _ imageColumn: Int, _ imageRow: Int, _ mapColumn: Int, _ mapRow: Int) -> ())
        where R: Sequence, R.Element == Int
    {
        for mapRow in mapRows {
            if mapRow >= size.height { break }
            for mapColumn in mapColumns {
                if mapColumn >= size.width { break }
                let mapIndex = (mapRow * size.width) + mapColumn
                visit(names[mapIndex], Int(columns[mapIndex]), Int(rows[mapIndex]), mapColumn, mapRow)
            }
        }
    }
    
    func eachTile(in rect: Rect4<Int>, visit: (_ imageName: UInt32, _ imageColumn: Int, _ imageRow: Int, _ mapColumn: Int, _ mapRow: Int) -> ()) {
        eachTile(inColumns: rect.widthRange, rows: rect.heightRange, visit: visit)
    }
    
}

// MARK:- MinimapImage

struct MinimapImage {
    var size: Size2<Int>
    var data: Data
}

extension MinimapImage {
    
    static func readFrom<File>(file: File) throws -> MinimapImage
    where File: FileReadHandle
    {
        let width = Int( try file.readValue(ofType: UInt32.self) )
        let height = Int( try file.readValue(ofType: UInt32.self) )
        let data = try file.readData(verifyingLength: width * height)
        return MinimapImage(size: Size2(width, height), data: data)
    }
    
}
