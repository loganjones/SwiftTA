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
        
        name = try info.requiredStringProperty("unitname")
        object = try info.requiredStringProperty("objectname")
        side = try info.requiredStringProperty("side")
        title = try info.requiredStringProperty("name")
        description = try info.requiredStringProperty("description")
        categories = Set(try info.requiredStringProperty("category").components(separatedBy: " "))
        tedClass = try info.requiredStringProperty("tedclass")
    }
    
}
