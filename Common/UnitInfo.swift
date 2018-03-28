//
//  UnitInfo.swift
//  TAassets
//
//  Created by Logan Jones on 5/7/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

struct UnitInfo {
    var name: String = ""
    var side: String = ""
    var object: String = ""
    
    var title: String = ""
    var description: String = ""
    
    var categories: Set<String> = []
    var tedClass: String = ""
}

extension UnitInfo {
    
    init(contentsOf file: FileSystem.FileHandle) throws {
        
        let info: TdfParser.Object = {
            let parser = TdfParser(file)
            parser.skipToObject(named: "UNITINFO")
            return parser.extractObject(normalizeKeys: true)
        }()
        
        name = try UnitInfo.requiredStringProperty(info, "unitname")
        object = try UnitInfo.requiredStringProperty(info, "objectname")
        side = try UnitInfo.requiredStringProperty(info, "side")
        title = try UnitInfo.requiredStringProperty(info, "name")
        description = try UnitInfo.requiredStringProperty(info, "description")
        categories = Set(try UnitInfo.requiredStringProperty(info, "category").components(separatedBy: " "))
        tedClass = try UnitInfo.requiredStringProperty(info, "tedclass")
    }
    
    enum LoadError: Error {
        case requiredPropertyNotFound(String)
    }
    
    private static func requiredStringProperty(_ info: TdfParser.Object, _ name: String) throws -> String {
        guard let value = info.properties[name]
            else { throw LoadError.requiredPropertyNotFound(name) }
        return value
    }
    
}
