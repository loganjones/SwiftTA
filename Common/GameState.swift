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
    
    /**
     Temporary convenience initializer that loads a simple sandbox game on a predetermined map.
     The game's file tree is assumed to exist in a subdirectory/alias/link (either "Total Annihilation" or "Total Annihilation Kingdoms") of the supplied directory.
     */
    convenience init(testLoadFromDocumentsDirectory documentsDirectory: URL) throws {
        
        let taDirectoryName = "Total Annihilation"
        let mapName = "Coast to Coast"
//        let mapName = "Dark Side"
//        let mapName = "Great Divide"
//        let mapName = "King of the Hill"
//        let mapName = "Ring Atoll"
//        let mapName = "Two Continents"

//        let taDirectoryName = "Total Annihilation Kingdoms"
//        let mapName = "Athri Cay"
//        let mapName = "Black Heart Jungle"
//        let mapName = "The Old Riverbed"
//        let mapName = "Two Castles"
        
        #if os(macOS) || os(iOS)
        let taDir = try URL(resolvingAliasFileAt: documentsDirectory.appendingPathComponent(taDirectoryName, isDirectory: true))
        #else
        let taDir = documentsDirectory.appendingPathComponent(taDirectoryName, isDirectory: true)
        #endif
        
        print("Total Annihilation directory: \(taDir)")
        try self.init(loadFrom: try FileSystem(mergingHpisIn: taDir), mapName: mapName)
    }
    
}
