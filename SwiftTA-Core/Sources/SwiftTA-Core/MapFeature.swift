//
//  MapFeature.swift
//  TAassets
//
//  Created by Logan Jones on 3/23/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


public struct MapFeatureInfo {
    
    public var name: String
    public var footprint: Size2<Int>
    public var height: Int
    
    public var world: String?
    
    public var gafFilename: String?
    public var primaryGafItemName: String?
    public var shadowGafItemName: String?
    
    public var hitDensity: Int
    public var damage: Int
    
    public var energy: Int
    public var metal: Int
    
    public var isBlocking: Bool
    public var destructible: Destructible
    public var reclaimable: Reclaimable
    public var flammable: Flammable
    
}

extension MapFeatureInfo {
    
    private init(name: String, object: TdfParser.Object) throws {
        self.name = name
        
        footprint = Size2<Int>(width: object.numericProperty("footprintx", default: 1),
                           height: object.numericProperty("footprintz", default: 1))
        height = object.numericProperty("height", default: 0)
        
        world = object["world"]
        
        gafFilename = object["filename"]
        primaryGafItemName = object["seqname"]
        shadowGafItemName = object["seqnameshad"]
        
        hitDensity = object.numericProperty("hitdensity", default: 1)
        damage = object.numericProperty("damage", default: 1)
        
        energy = object.numericProperty("energy", default: 0)
        metal = object.numericProperty("damage", default: 0)
        
        isBlocking = object.boolProperty("blocking", default: true)
        destructible = Destructible(from: object)
        reclaimable = Reclaimable(from: object)
        flammable = Flammable(from: object)
    }
    
}

// MARK: Destructible

public extension MapFeatureInfo {
    
    enum Destructible {
        case no
        case yes(Properties)
        
        public struct Properties {
            var primaryGafItemName: String?
            var resultingFeature: String
        }
    }
    
    var isDestructible: Bool {
        switch destructible {
        case .no: return false
        case .yes: return true
        }
    }
    var isIndestructible: Bool { return !isDestructible }
    
}

public extension MapFeatureInfo.Destructible {
    
    var properties: Properties? {
        switch self {
        case .no: return nil
        case .yes(let p): return p
        }
    }
    
    init(from object: TdfParser.Object) {
        let isDestructible = !object.boolProperty("indestructible", default: false)
        self = isDestructible ? .yes(Properties(from: object)) : .no
    }
}

private extension MapFeatureInfo.Destructible.Properties {
    init(from object: TdfParser.Object) {
        primaryGafItemName = object["seqnamedie"]
        resultingFeature = (object["featuredead"] ?? "smudge01").lowercased()
    }
}

// MARK: Reclaimable

public extension MapFeatureInfo {
    
    enum Reclaimable {
        case no
        case yes(Properties)
        
        struct Properties {
            var primaryGafItemName: String?
            var resultingFeature: String
        }
    }
    
    var isReclaimable: Bool {
        switch reclaimable {
        case .no: return false
        case .yes: return true
        }
    }
    
}

public extension MapFeatureInfo.Reclaimable {
    
    var properties: Properties? {
        switch self {
        case .no: return nil
        case .yes(let p): return p
        }
    }
    
    fileprivate init(from object: TdfParser.Object) {
        let isReclaimable = object.boolProperty("reclaimable", default: false)
        self = isReclaimable ? .yes(Properties(from: object)) : .no
    }
}

private extension MapFeatureInfo.Reclaimable.Properties {
    init(from object: TdfParser.Object) {
        primaryGafItemName = object["seqnamereclamate"]
//        shadowGafItemName = object["seqnamereclamateshad"]
        resultingFeature = (object["featurereclamate"] ?? "smudge01").lowercased()
    }
}

// MARK: Flammable

public extension MapFeatureInfo {
    
    enum Flammable {
        case no
        case yes(Properties)
        
        struct Properties {
            var sparkTime: Int
            var burnTime: ClosedRange<Int>
            var spreadChance: Int
            var weapon: String
            var primaryGafItemName: String?
            var shadowGafItemName: String?
            var resultingFeature: String
        }
    }
    
    var isFlammable: Bool {
        switch flammable {
        case .no: return false
        case .yes: return true
        }
    }
    
}

public extension MapFeatureInfo.Flammable {
    
    var properties: Properties? {
        switch self {
        case .no: return nil
        case .yes(let p): return p
        }
    }
    
    fileprivate init(from object: TdfParser.Object) {
        let isFlammable = object.boolProperty("flamable", default: false)
        self = isFlammable ? .yes(Properties(from: object)) : .no
    }
}

private extension MapFeatureInfo.Flammable.Properties {
    init(from object: TdfParser.Object) {
        sparkTime = object.numericProperty("sparktime", default: 4)
        spreadChance = object.numericProperty("spreadchance", default: 90)
        
        let burnmin = object.numericProperty("burnmin", default: 5)
        let burnmax = object.numericProperty("burnmax", default: 15)
        burnTime = burnmin...burnmax
        
        weapon = object["burnweapon"] ?? "TreeBurn"
        
        primaryGafItemName = object["seqnameburn"]
        shadowGafItemName = object["seqnameburnshad"]
        resultingFeature = (object["featureburnt"] ?? "Tree1Dead").lowercased()
    }
}

// MARK: Load Features

public extension MapFeatureInfo {
    
    typealias FeatureInfoCollection = [FeatureTypeId: MapFeatureInfo]
    
    static func collectFeatures(_ mapFeatures: Set<FeatureTypeId>, planet: String?, unitCorpses: Set<FeatureTypeId> = Set(), filesystem: FileSystem) -> FeatureInfoCollection {
        
        guard let featuresDirectory = filesystem.root[directory: "features"] else { return [:] }
        
        var toLoad = mapFeatures.union(unitCorpses)
        var features: FeatureInfoCollection = [:]
        
        if let planetDirectoryName = directoryName(forPlanet: planet), let planetDirectory = featuresDirectory[directory: planetDirectoryName] {
            collectFeatures(named: &toLoad, into: &features, from: planetDirectory, of: filesystem)
        }
        
        if unitCorpses.isEmpty == false, let corpsesDirectory = featuresDirectory[directory: "corpses"] {
            collectFeatures(named: &toLoad, into: &features, from: corpsesDirectory, of: filesystem)
        }
        
        if toLoad.isEmpty {
            return features
        }
        
        if let allWorldsDirectory = featuresDirectory[directory: "All Worlds"] {
            collectFeatures(named: &toLoad, into: &features, from: allWorldsDirectory, of: filesystem)
        }
        
        if toLoad.isEmpty {
            return features
        }
        
        var featuresAddedDuringThisLoop = 0
        outer: repeat {
            featuresAddedDuringThisLoop = 0
            for directory in featuresDirectory.items.compactMap({ $0.asDirectory() }) {
                featuresAddedDuringThisLoop += collectFeatures(named: &toLoad, into: &features, from: directory, of: filesystem)
                if toLoad.isEmpty { break outer }
            }
        }
        while toLoad.isEmpty == false && featuresAddedDuringThisLoop > 0
        
        return features
    }
    
    @discardableResult
    private static func collectFeatures(named toLoad: inout Set<FeatureTypeId>, into loaded: inout FeatureInfoCollection, from directory: FileSystem.Directory, of filesystem: FileSystem) -> Int
    {
        let files = directory.files(withExtension: "tdf")
        var count = 0
        
        for tdf in files.sorted(by: { FileSystem.sortNames($0.name, $1.name) }) {
            guard let reader = try? filesystem.openFile(tdf) else { continue }
            count += collectFeatures(named: &toLoad, into: &loaded, from: reader)
        }
        
        return count
    }
    
    @discardableResult
    private static func collectFeatures<File>(named toLoad: inout Set<FeatureTypeId>, into loaded: inout FeatureInfoCollection, from tdf: File) -> Int
        where File: FileReadHandle
    {
        let parser = TdfParser(tdf)
        var count = 0
        
        while let featureName = parser.skipToNextObject()?.lowercased() {
            let featureId = FeatureTypeId(named: featureName)
            if toLoad.contains(featureId) && loaded[featureId] == nil, let featureInfo = try? MapFeatureInfo(name: featureName, object: parser.extractObject()) {
                loaded[featureId] = featureInfo
                toLoad.remove(featureId)
                for childId in featureInfo.childFeatures where toLoad.contains(childId) == false && loaded[childId] == nil {
                    toLoad.insert(childId)
                }
                count += 1
            }
            else {
                parser.skipObject()
            }
        }
        
        return count
    }
    
    var childFeatures: Set<FeatureTypeId> {
        var additional = Set<FeatureTypeId>()
        if let f = destructible.properties?.resultingFeature { additional.insert(FeatureTypeId(named: f)) }
        if let f = reclaimable.properties?.resultingFeature { additional.insert(FeatureTypeId(named: f)) }
        if let f = flammable.properties?.resultingFeature { additional.insert(FeatureTypeId(named: f)) }
        return additional
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
    
    typealias MapFeaturesGafCollator = (_ id: FeatureTypeId, _ info: MapFeatureInfo, _ item: GafItem, _ gafHandle: FileSystem.FileHandle, _ gafListing: GafListing) -> ()
    
    static func collateFeatureGafItems(_ featureInfo: FeatureInfoCollection, from filesystem: FileSystem, collator: MapFeaturesGafCollator) {
        
        let byGaf = Dictionary(grouping: featureInfo, by: { a in a.value.gafFilename ?? "" })
        
        for (gafName, featuresInGaf) in byGaf {
            
            guard let gaf = try? filesystem.openFile(at: "anims/" + gafName + ".gaf"),
                let listing = try? GafListing(withContentsOf: gaf)
                else { continue }
            
            for (id, info) in featuresInGaf {
                guard let itemName = info.primaryGafItemName, let item = listing[itemName] else { continue }
                collator(id, info, item, gaf, listing)
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
