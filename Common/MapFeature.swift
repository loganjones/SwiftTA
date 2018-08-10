//
//  MapFeature.swift
//  TAassets
//
//  Created by Logan Jones on 3/23/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


struct MapFeatureInfo {
    
    var name: String
    var footprint: Size2D
    var height: Int
    
    var world: String?
    
    var gafFilename: String?
    var primaryGafItemName: String?
    var shadowGafItemName: String?
    
}

extension MapFeatureInfo {
    
    private init(name: String, object: TdfParser.Object) throws {
        self.name = name
        
        let footprintX = try object.requiredStringProperty("footprintx")
        let footprintZ = try object.requiredStringProperty("footprintz")
        footprint = Size2D(width: Int(footprintX) ?? 1, height: Int(footprintZ) ?? 1)
        height = Int(try object.requiredStringProperty("height")) ?? 0
        
        world = object["world"]
        
        gafFilename = object["filename"]
        primaryGafItemName = object["seqname"]
        shadowGafItemName = object["seqnameshad"]
    }
    
}

extension MapFeatureInfo {
    
    typealias FeatureInfoCollection = [String: MapFeatureInfo]
    
    static func collectFeatures(named featureNames: Set<String>, strartingWith planet: String?, from filesystem: FileSystem) -> FeatureInfoCollection {
        
        guard let featuresDirectory = filesystem.root[directory: "features"] else { return [:] }
        
        var features: FeatureInfoCollection = [:]
        var alreadyLoaded = ""
        
        if let planetDirectoryName = directoryName(forPlanet: planet), let planetDirectory = featuresDirectory[directory: planetDirectoryName] {
            let planetFeatures = collectFeatures(named: featureNames, in: planetDirectory, of: filesystem)
            features = planetFeatures
            alreadyLoaded = planetDirectoryName
        }
        
        if features.count >= featureNames.count {
            return features
        }
        
        if let allWorldsDirectory = featuresDirectory[directory: "All Worlds"] {
            let allWorldsFeatures = collectFeatures(named: featureNames, in: allWorldsDirectory, of: filesystem)
            features.merge(allWorldsFeatures, uniquingKeysWith: { (a, b) in b })
        }
        
        if features.count >= featureNames.count {
            return features
        }
        
        for directory in featuresDirectory.items.compactMap({ $0.asDirectory() }) {
            guard !FileSystem.compareNames(directory.name, alreadyLoaded) else { continue }
            guard !FileSystem.compareNames(directory.name, "All Worlds") else { continue }
            
            let moreFeatures = collectFeatures(named: featureNames, in: directory, of: filesystem)
            features.merge(moreFeatures, uniquingKeysWith: { (a, b) in b })
            
            if features.count >= featureNames.count {
                return features
            }
        }
        
        return features
    }
    
    static func collectFeatures(named featureNames: Set<String>, from filesystem: FileSystem) -> FeatureInfoCollection {
        let featuresDirectory = filesystem.root[directory: "features"] ?? FileSystem.Directory()
        let features = featuresDirectory.items
            .compactMap { $0.asDirectory() }
            .map { collectFeatures(named: featureNames, in: $0, of: filesystem) }
            .reduce([:]) { $0.merging($1, uniquingKeysWith: { (a, b) in b }) }
        return features
    }
    
    static func collectFeatures(named featureNames: Set<String>, in directory: FileSystem.Directory, of filesystem: FileSystem) -> FeatureInfoCollection {
        let features = directory.items
            .compactMap { $0.asFile() }
            .filter { $0.hasExtension("tdf") }
            .compactMap { try? collectFeatures(named: featureNames, in: $0, of: filesystem) }
            .reduce([:]) { $0.merging($1, uniquingKeysWith: { (a, b) in b }) }
        return features
    }
    
    static func collectFeatures(named featureNames: Set<String>, in tdf: FileSystem.File, of filesystem: FileSystem) throws -> FeatureInfoCollection {
        
        var found = FeatureInfoCollection()
        
        let parser = TdfParser(try filesystem.openFile(tdf))
        while let object = parser.skipToNextObject() {
            if featureNames.contains(object) {
                let info = try? MapFeatureInfo(name: object, object: parser.extractObject())
                found[object] = info
            }
            else {
                parser.skipObject()
            }
        }
        
        return found
    }
    
}

private extension MapFeatureInfo {
    
    static func directoryName(forPlanet planet: String) -> String {
        switch planet.lowercased() {
        case "archipelago":
            return "archi"
        case "green planet":
            return "green"
        case "lunar":
            return "moon"
        case "red planet":
            return "mars"
        case "water world":
            return "water"
        default:
            return planet
        }
    }
    
    static func directoryName(forPlanet planet: String?) -> String? {
        guard let p = planet, !p.isEmpty else { return nil }
        return directoryName(forPlanet: p) as String
    }
    
}

extension MapFeatureInfo {
    
    typealias MapFeaturesGafCollator = (_ name: String, _ info: MapFeatureInfo, _ item: GafItem, _ gafHandle: FileSystem.FileHandle, _ gafListing: GafListing) -> ()
    
    static func collateFeatureGafItems(_ featureInfo: FeatureInfoCollection, from filesystem: FileSystem, collator: MapFeaturesGafCollator) {
        
        let byGaf = Dictionary(grouping: featureInfo, by: { a in a.value.gafFilename ?? "" })
        
        for (gafName, featuresInGaf) in byGaf {
            
            guard let gaf = try? filesystem.openFile(at: "anims/" + gafName + ".gaf"),
                let listing = try? GafListing(withContentsOf: gaf)
                else { continue }
            
            for (name, info) in featuresInGaf {
                guard let itemName = info.primaryGafItemName, let item = listing[itemName] else { continue }
                collator(name, info, item, gaf, listing)
            }
        }
    }
        
    static func loadFeaturePalettes(_ featureInfo: MapFeatureInfo.FeatureInfoCollection, from filesystem: FileSystem) -> [String: Palette] {
        return featureInfo.reduce(into: [String: Palette]()) { (palettes, info) in
            let world = info.value.world ?? ""
            guard palettes[world] == nil else { return }
            if let palette = try? Palette.featurePalette(forWorld: world, from: filesystem) {
                palettes[world] = palette
            }
            else if let palette = try? Palette.featurePaletteForTa(from: filesystem) {
                palettes[world] = palette
            }
        }
    }
    
}
