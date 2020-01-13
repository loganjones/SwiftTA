//
//  MapInfo.swift
//  TAassets
//
//  Created by Logan Jones on 3/23/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


public struct MapInfo {
    
    public var name: String
    public var description: String
    public var planet: String?
     
    public var tidalStrength: Int
    public var solarStrength: Int
    public var windSpeed: ClosedRange<Int>
    public var gravity: Int
    
    public var schema: [Schema]
    
    public struct Schema {
        public var type: SchemaType
        public var aiProfile: String
        public var startPositions: [Point2<Int>]
    }
    
    public enum SchemaType {
        case sandbox
        case easy
        case medium
        case hard
    }
    
}

public extension MapInfo {
    
    init(contentsOf ota: FileSystem.File, in filesystem: FileSystem) throws {
        
        let info: TdfParser.Object = try {
            let parser = TdfParser(try filesystem.openFile(ota))
            guard parser.skipToObject(named: "GlobalHeader")
                else { throw LoadError.globalHeaderNotFound }
            return parser.extractObject(normalizeKeys: true)
        }()
        
        name = info.stringProperty("missionname", default: ota.baseName)
        description = info.stringProperty("missiondescription")
        planet = (try? info.requiredStringProperty("planet")) ?? (try? info.requiredStringProperty("kingdom"))
        
        tidalStrength = info.numericProperty("tidalstrength", default: 20)
        solarStrength = info.numericProperty("solarstrength", default: 20)
        
        let minwindspeed: Int = info.numericProperty("minwindspeed", default: 0)
        let maxwindspeed: Int = info.numericProperty("maxwindspeed", default: 2000)
        windSpeed = minwindspeed...max(minwindspeed, maxwindspeed)
        
        gravity = info.numericProperty("gravity", default: 112)
        
        schema = MapInfo.loadSchema(from: info)
    }
    
    enum LoadError: Error {
        case globalHeaderNotFound
    }
    
    private static func loadSchema(from info: TdfParser.Object) -> [Schema] {
        var schemaList = [Schema]()
        
        if info.subobjects["Schema 0"] != nil {
            var num = 0
            while let schemaObject = info.subobjects["Schema \(num)"] {
                schemaList.append(Schema(taFormat: schemaObject))
                num += 1
            }
        }
        else if let takSchema = info.subobjects["Map Data"] {
            schemaList.append(Schema(takFormat: takSchema))
        }
        
        return schemaList
    }
    
}

public extension MapInfo.Schema {
    
    init(taFormat info: TdfParser.Object) {
        type = MapInfo.SchemaType(otaValue: info["type"])
        aiProfile = info["aiprofile"] ?? "DEFAULT"
        startPositions = MapInfo.Schema.loadSpecialsStartPositions(from: info.subobjects["specials"])
    }
    
    init(takFormat info: TdfParser.Object) {
        type = MapInfo.SchemaType(otaValue: info["type"])
        aiProfile = info["aiprofile"] ?? "DEFAULT"
        startPositions = MapInfo.Schema.loadSpecialsStartPositions(from: info.subobjects["specials"])
    }
    
    private static func loadSpecialsStartPositions(from specials: TdfParser.Object?) -> [Point2<Int>] {
        guard let specials = specials else { return [] }
        
        var maxNum = 0
        var positions = [Int: Point2<Int>]()
        
        for special in specials.subobjects where special.key.starts(with: "special") {
            guard let what = special.value["specialwhat"], what.starts(with: "StartPos") else { continue }
            let numString = what[what.index(what.startIndex, offsetBy: 8)...]
            guard let num = Int(numString) else { continue }
            let position = Point2<Int>(x: special.value.numericProperty("xpos", default: 0),
                                   y: special.value.numericProperty("zpos", default: 0))
            positions[num] = position
            maxNum = max(num, maxNum)
        }
        
        var startPositions = [Point2<Int>](repeating: .zero, count: maxNum)
        for i in startPositions.indices {
            guard let p = positions[i+1] else { continue }
            startPositions[i] = p
        }
        
        return startPositions
    }
    
}

public extension MapInfo.SchemaType {
    
    init(otaValue: String?) {
        guard let otaValue = otaValue?.lowercased() else { self = .sandbox; return }
        guard !otaValue.starts(with: "network") else { self = .sandbox; return }
        switch otaValue {
        case "easy": self = .easy
        case "medium": self = .medium
        case "hard": self = .hard
        default: self = .sandbox
        }
    }
    
}
