//
//  UnitInfo.swift
//  TAassets
//
//  Created by Logan Jones on 5/7/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

public struct UnitInfo {
    public var name: String = ""
    public var side: String = ""
    public var object: String = ""
    public var corpse: String?
    
    public var title: String = ""
    public var description: String = ""
    
    public var footprint: Size2<Int> = Size2<Int>(width: 1 , height: 1)
    public var capabilities: Capabilities = .defaults
    public var categories: Set<String> = []
    public var tedClass: String = ""
    
    public var acceleration: GameFloat
    public var maxVelocity: GameFloat
    public var brakeRate: GameFloat
    public var turnRate: GameFloat
}

 extension UnitInfo {
    public struct Capabilities: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        static let move = Capabilities(rawValue: 1 << 0) // "canmove"
        static let stop = Capabilities(rawValue: 1 << 1) // "canstop"
        static let attack = Capabilities(rawValue: 1 << 2) // "canattack"
        static let `guard` = Capabilities(rawValue: 1 << 3) // "canguard"
        static let patrol = Capabilities(rawValue: 1 << 4) // "canpatrol"
        static let reclamate = Capabilities(rawValue: 1 << 5) // "canreclamate"
        static let load = Capabilities(rawValue: 1 << 6) // "canload"
        static let onoffable = Capabilities(rawValue: 1 << 7) // "onoffable"
        
        static let activateWhenBuilt = Capabilities(rawValue: 1 << 10) // "ActivateWhenBuilt"
        
        static let builder = Capabilities(rawValue: 1 << 20) // "builder"
        static let flying = Capabilities(rawValue: 1 << 21) // "canfly"
        static let floater = Capabilities(rawValue: 1 << 22) // "floater"
        static let hover = Capabilities(rawValue: 1 << 23) // "canhover"
        static let tidalGenerator = Capabilities(rawValue: 1 << 24) // "TidalGenerator"
        static let targeting = Capabilities(rawValue: 1 << 25) // "istargetingupgrade"
        
        static let defaults: Capabilities = []
    }
}

public extension UnitInfo {
    
    init(contentsOf file: FileSystem.FileHandle) throws {
        
        let info: TdfParser.Object = {
            let parser = TdfParser(file)
            parser.skipToObject(named: "UNITINFO")
            return parser.extractObject(normalizeKeys: true)
        }()
        
        name = try info.requiredStringProperty("unitname")
        object = try info.requiredStringProperty("objectname")
        side = try info.requiredStringProperty("side")
        title = try info.requiredStringProperty("name")
        description = try info.requiredStringProperty("description")
        categories = Set(try info.requiredStringProperty("category").components(separatedBy: " "))
        tedClass = try info.requiredStringProperty("tedclass")
        corpse = info["corpse"]
        
        let footprintX = try info.requiredStringProperty("footprintx")
        let footprintZ = try info.requiredStringProperty("footprintz")
        footprint = Size2<Int>(width: Int(footprintX) ?? 1, height: Int(footprintZ) ?? 1)
        
        capabilities = .defaults
        
        if info.boolProperty("canmove") { capabilities.update(with: .move) }
        if info.boolProperty("canstop") { capabilities.update(with: .stop) }
        if info.boolProperty("canattack") { capabilities.update(with: .attack) }
        if info.boolProperty("canguard") { capabilities.update(with: .guard) }
        if info.boolProperty("canpatrol") { capabilities.update(with: .move) }
        if info.boolProperty("canreclamate") { capabilities.update(with: .stop) }
        if info.boolProperty("canload") { capabilities.update(with: .load) }
        if info.boolProperty("onoffable") { capabilities.update(with: .onoffable) }
        
        if info.boolProperty("activatewhenbuilt") { capabilities.update(with: .activateWhenBuilt) }
        
        if info.boolProperty("builder") { capabilities.update(with: .builder) }
        if info.boolProperty("canfly") { capabilities.update(with: .flying) }
        if info.boolProperty("floater") { capabilities.update(with: .floater) }
        if info.boolProperty("canhover") { capabilities.update(with: .hover) }
        if info.boolProperty("tidalgenerator") { capabilities.update(with: .tidalGenerator) }
        if info.boolProperty("istargetingupgrade") { capabilities.update(with: .targeting) }
        
        acceleration = info.numericProperty("acceleration")
        maxVelocity = info.numericProperty("maxvelocity")
        brakeRate = info.numericProperty("brakerate")
        turnRate = (info.numericProperty("turnrate") / ANGULAR_CONSTANT) * (GameFloat.pi / 180.0)
    }
    
}

public extension UnitInfo {
    
    var canMove: Bool { return capabilities.contains(.move) }
    var canStop: Bool { return capabilities.contains(.stop) }
    var canAttack: Bool { return capabilities.contains(.attack) }
    var canGuard: Bool { return capabilities.contains(.guard) }
    var canPatrol: Bool { return capabilities.contains(.patrol) }
    var canReclamate: Bool { return capabilities.contains(.reclamate) }
    var canLoad: Bool { return capabilities.contains(.load) }
    var isOnOffable: Bool { return capabilities.contains(.onoffable) }
    
    var activateWhenBuilt: Bool { return capabilities.contains(.activateWhenBuilt) }
    
    var isBuilder: Bool { return capabilities.contains(.builder) }
    var canFly: Bool { return capabilities.contains(.flying) }
    var canHover: Bool { return capabilities.contains(.hover) }
    
}

// MARK: Load Units

public extension UnitInfo {
    
    static func collectUnits(from filesystem: FileSystem) -> [UnitInfo] {
        
        guard let unitsDirectory = filesystem.root[directory: "units"] else { return [] }
        
        let units = unitsDirectory.files(withExtension: "fbi")
            .compactMap { try? filesystem.openFile($0) }
            .compactMap { try? UnitInfo(contentsOf: $0) }
        
        return units
    }
    
    static func collectUnits(from filesystem: FileSystem, onlyAllowing allowedUnits: [String]) -> [UnitInfo] {
        
        guard let unitsDirectory = filesystem.root[directory: "units"] else { return [] }
        
        let allowed = Set(allowedUnits.map { $0.lowercased() })
        
        let units = unitsDirectory.files(withExtension: "fbi")
            .filter { allowed.contains($0.baseName.lowercased()) }
            .compactMap { try? filesystem.openFile($0) }
            .compactMap { try? UnitInfo(contentsOf: $0) }
        
        return units
    }
    
}
