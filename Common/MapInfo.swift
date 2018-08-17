//
//  MapInfo.swift
//  TAassets
//
//  Created by Logan Jones on 3/23/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


struct MapInfo {
    
    var name: String
    var description: String
    var planet: String?
    
    var tidalStrength: Int
    var solarStrength: Int
    var windSpeed: ClosedRange<Int>
    var gravity: Int
    
    var schema: [Schema]
    
    struct Schema {
        var type: SchemaType
        var aiProfile: String
        var startPositions: [Point2D]
    }
    
    enum SchemaType {
        case sandbox
        case easy
        case medium
        case hard
    }
    
}

extension MapInfo {
    
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

extension MapInfo.Schema {
    
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
    
    private static func loadSpecialsStartPositions(from specials: TdfParser.Object?) -> [Point2D] {
        guard let specials = specials else { return [] }
        
        var maxNum = 0
        var positions = [Int: Point2D]()
        
        for special in specials.subobjects where special.key.starts(with: "special") {
            guard let what = special.value["specialwhat"], what.starts(with: "StartPos") else { continue }
            let numString = what[what.index(what.startIndex, offsetBy: 8)...]
            guard let num = Int(numString) else { continue }
            let position = Point2D(x: special.value.numericProperty("xpos", default: 0),
                                   y: special.value.numericProperty("zpos", default: 0))
            positions[num] = position
            maxNum = max(num, maxNum)
        }
        
        var startPositions = [Point2D](repeating: .zero, count: maxNum)
        for i in startPositions.indices {
            guard let p = positions[i+1] else { continue }
            startPositions[i] = p
        }
        
        return startPositions
    }
    
}

extension MapInfo.SchemaType {
    
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
