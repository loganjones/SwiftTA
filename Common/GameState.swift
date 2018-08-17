//
//  GameState.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 8/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


class GameState {
    
    let filesystem: FileSystem
    let map: MapModel
    let mapInfo: MapInfo
    let features: [String: MapFeatureInfo]
    let units: [String: UnitInfo]
    
    let startPosition: Point2D
    
    convenience init(loadFrom taDir: URL, mapName: String) throws {
        try self.init(loadFrom: try FileSystem(mergingHpisIn: taDir), mapName: mapName)
    }
    
    init(loadFrom filesystem: FileSystem, mapName: String) throws {
        self.filesystem = filesystem
        let beginGame = Date()
        
        let beginMap = Date()
        guard let otaFile = filesystem.root[filePath: "maps/" + mapName + ".ota"]
            else { throw FileSystem.Directory.ResolveError.notFound }
        mapInfo = try MapInfo(contentsOf: otaFile, in: filesystem)
        
        map = try MapModel(contentsOf: filesystem.openFile(at: "maps/\(mapName).tnt"))
        let endMap = Date()
        
        let beginUnits = Date()
        units = UnitInfo.collectUnits(from: filesystem)
        let endUnits = Date()
        
        let beginFeatures = Date()
        features = MapFeatureInfo.collectFeatures(
            Set(map.features), planet: mapInfo.planet,
            unitCorpses: units.values.reduce(into: Set()) { $0.insert($1.corpse.lowercased()) },
            filesystem: filesystem)
        let endFeatures = Date()
        
        startPosition = mapInfo.schema.first?.startPositions.first ?? Point2D(32, 32)
        
        let endGame = Date()
        
        print("""
            Game assets load time: \(endGame.timeIntervalSince(beginGame)) seconds
              Map(\(map.mapSize)): \(endMap.timeIntervalSince(beginMap)) seconds
              Units(\(units.count)): \(endUnits.timeIntervalSince(beginUnits)) seconds
              Features(\(features.count)): \(endFeatures.timeIntervalSince(beginFeatures)) seconds
            """)
    }
    
}
