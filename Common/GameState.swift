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
    let features: [FeatureTypeId: MapFeatureInfo]
    let units: [UnitTypeId: UnitData]
    let sides: [SideInfo]
    
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
        units = UnitInfo.collectUnits(from: filesystem, onlyAllowing: ["armcom", "corcom", "araking", "tarnecro", "vermage", "zonhunt", "cresage"])
            .compactMap { try? UnitData(loading: $0, from: filesystem) }
            .reduce(into: [:]) { $0[UnitTypeId(for: $1.info)] = $1 }
        let endUnits = Date()
        
        let beginFeatures = Date()
        let corpses = units.values.lazy
            .compactMap { $0.info.corpse }
            .reduce(into: Set()) { $0.insert(FeatureTypeId(named: $1)) }
        features = MapFeatureInfo.collectFeatures(
            Set(map.features), planet: mapInfo.planet,
            unitCorpses: corpses,
            filesystem: filesystem)
        let endFeatures = Date()
        
        let beginSides = Date()
        let sidedata = try filesystem.openFile(at: "gamedata/sidedata.tdf")
        sides = try SideInfo.load(contentsOf: sidedata)
        let endSides = Date()
        
        startPosition = mapInfo.schema.first?.startPositions.first ?? Point2D(32, 32)
        
        let endGame = Date()
        
        print("""
            Game assets load time: \(endGame.timeIntervalSince(beginGame)) seconds
              Map(\(map.mapSize)): \(endMap.timeIntervalSince(beginMap)) seconds
              Units(\(units.count)): \(endUnits.timeIntervalSince(beginUnits)) seconds
              Features(\(features.count)): \(endFeatures.timeIntervalSince(beginFeatures)) seconds
              Sides(\(sides.count)): \(endSides.timeIntervalSince(beginSides)) seconds
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
    
    func generateInitialViewState(viewportSize: Size2D) -> GameViewState {
        
//        // TEMP
//        var startingObjects: [GameViewObject] = []
//
//        if let unit = randomStartingUnit() {
//            startingObjects.append(.unit(GameViewUnit(name: unit.info.name.lowercased(),
//                                                      position: Vertex3(Double(startPosition.x), Double(startPosition.y), 0),
//                                                      orientation: .zero,
//                                                      pose: UnitModel.Instance(for: unit.model))))
//        }
        
        return GameViewState(viewport: viewport(ofSize: viewportSize, centeredOn: startPosition, in: map),
                             objects: [])
    }
    
//    private func randomStartingUnit() -> UnitData? {
//        if let taUnitName = ["armcom", "corcom"].randomElement(), let taUnit = units[taUnitName] {
//            return taUnit
//        }
//        else if let takUnitName = ["araking", "tarnecro", "vermage", "zonhunt", "cresage"].randomElement(), let takUnit = units[takUnitName] {
//            return takUnit
//        }
//        else {
//            return nil
//        }
//    }
    
}
