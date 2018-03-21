//
//  MapModel.swift
//  TAassets
//
//  Created by Logan Jones on 3/13/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


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

extension MapModel {
    
    var minimap: MinimapImage {
        switch self {
        case .ta(let model): return model.minimap
        case .tak(let model): return model.smallMinimap
        }
    }
    
    var resolution: Size2D {
        switch self {
        case .ta(let model): return model.resolution
        case .tak(let model): return model.resolution
        }
    }
    
}

private extension TA_TNT_HEADER {
    var mapSize: Size2D {
        return Size2D(width: Int(self.width), height: Int(self.height))
    }
}

// MARK:- TA

struct TaMapModel {
    
    var mapSize: Size2D
    
    var tileSet: TileSet
    var tileIndexMap: TileIndexMap
    
    var heightMap: [Int]
    var featureMap: [Int?]
    var features: [String]
    
    var minimap: MinimapImage
    
}

extension TaMapModel {
    
    var resolution: Size2D {
        return mapSize * 16
    }
    
    // TEMP
    func height(at point: Point2D) -> Int {
        let index = (point.y * mapSize.width) + point.x
        return heightMap[index]
    }
    func featureIndex(at point: Point2D) -> Int? {
        let index = (point.y * mapSize.width) + point.x
        return featureMap[index]
    }
    
}

extension TaMapModel {
    
    func tileColumns(in rect: NSRect) -> CountableClosedRange<Int> {
        let tileWidth = tileSet.tileSize.width
        let start = Int(floor(rect.minX)) / tileWidth
        var end = Int(ceil(rect.maxX)) / tileWidth
        if CGFloat(end * tileWidth) < rect.maxX { end += 1 }
        return max(start,0)...min(end, tileIndexMap.size.width-1)
    }
    
    func tileRows(in rect: NSRect) -> CountableClosedRange<Int> {
        let tileheight = tileSet.tileSize.height
        let start = Int(floor(rect.minY)) / tileheight
        var end = Int(ceil(rect.maxY)) / tileheight
        if CGFloat(end * tileheight) < rect.maxY { end += 1 }
        return max(start,0)...min(end, tileIndexMap.size.height-1)
    }
    
    func eachTile(in rect: NSRect, visit: (_ tile: Data, _ index: Int, _ column: Int, _ row: Int) -> ()) {
        let rows = tileRows(in: rect)
        let columns = tileColumns(in: rect)
        tileIndexMap.eachIndex(inColumns: columns, rows: rows) { (index, column, row) in
            let tile = tileSet[index]
            visit(tile, index, column, row)
        }
    }
    
}

private extension TaMapModel {
    
    init<File>(_ mapSize: Size2D, reading tntFile: File) throws where File: FileReadHandle {
        self.mapSize = mapSize
        
        let header = try tntFile.readValue(ofType: TA_TNT_EXT_HEADER.self)
        let seaLevel = Int(header.seaLevel)
        
        tntFile.seek(toFileOffset: header.offsetToTileIndexArray)
        let tileIndexCount = mapSize / 2
        let tileIndexData = try tntFile.readData(verifyingLength: tileIndexCount.area * MemoryLayout<UInt16>.size)
        tileIndexMap = TileIndexMap(indices: tileIndexData, size: tileIndexCount)
        
        tntFile.seek(toFileOffset: header.offsetToMapInfoArray)
        let entries = try tntFile.readArray(ofType: TA_TNT_MAP_ENTRY.self, count: mapSize.area)
        heightMap = entries.map { Int($0.elevation) - seaLevel }
        
        tntFile.seek(toFileOffset: header.offsetToTileArray)
        let tileSize = Size2D(width: 32, height: 32)
        let tiles = try tntFile.readData(verifyingLength: Int(header.numberOfTiles) * tileSize.area)
        tileSet = TileSet(tiles: tiles, count: Int(header.numberOfTiles), tileSize: tileSize)
        
        tntFile.seek(toFileOffset: header.offsetToFeatureEntryArray)
        features = try tntFile.readArray(ofType: TA_TNT_FEATURE_ENTRY.self, count: Int(header.numberOfFeatures)).map { $0.nameString }
        
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
        let tileSize: Size2D
        
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
        var size: Size2D
        
        func eachIndex(inColumns columns: CountableClosedRange<Int>, rows: CountableClosedRange<Int>, visit: (_ index: Int, _ column: Int, _ row: Int) -> ()) {
            indices.withUnsafeBytes() { (buffer: UnsafePointer<UInt8>) in
                let p = UnsafeRawPointer(buffer).bindMemoryBuffer(to: UInt16.self, capacity: size.area)
                for row in rows {
                    for column in columns {
                        let index = p[(row * size.width) + column]
                        visit(Int(index), column, row)
                    }
                }
            }
        }
        
    }
    
}

// MARK:- TAK

struct TakMapModel {
    var mapSize: Size2D
    var largeMinimap: MinimapImage
    var smallMinimap: MinimapImage
}

extension TakMapModel {
    
    var resolution: Size2D {
        return mapSize * 16
    }
    
}

private extension TakMapModel {
    
    init<File>(_ mapSize: Size2D, reading tntFile: File) throws where File: FileReadHandle {
        self.mapSize = mapSize
        
        let header = try tntFile.readValue(ofType: TAK_TNT_EXT_HEADER.self)

        tntFile.seek(toFileOffset: header.offsetToLargeMiniMap)
        largeMinimap = try MinimapImage.readFrom(file: tntFile)
        
        tntFile.seek(toFileOffset: header.offsetToSmallMiniMap)
        smallMinimap = try MinimapImage.readFrom(file: tntFile)
    }
    
}

// MARK:- MinimapImage

struct MinimapImage {
    var size: Size2D
    var data: Data
}

extension MinimapImage {
    
    static func readFrom<File>(file: File) throws -> MinimapImage
    where File: FileReadHandle
    {
        let width = Int( try file.readValue(ofType: UInt32.self) )
        let height = Int( try file.readValue(ofType: UInt32.self) )
        let data = try file.readData(verifyingLength: width * height)
        return MinimapImage(size: Size2D(width: width, height: height), data: data)
    }
    
}
