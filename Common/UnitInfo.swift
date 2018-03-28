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
    
    init(contentsOf file: FileSystem.FileHandle) {
        
        let info: TdfParser.Object = {
            let parser = TdfParser(file)
            parser.skipToObject(named: "UNITINFO")
            return parser.extractObject()
        }()
        
        name = info["UnitName"] ?? ""
        side = info["Side"] ?? ""
        object = info["Objectname"] ?? ""
        title = info["Name"] ?? ""
        description = info["Description"] ?? ""
        categories = Set((info["Category"] ?? "").components(separatedBy: " "))
        tedClass = info["TEDClass"] ?? ""
    }
    
}
