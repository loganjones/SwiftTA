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
    var properties: [String: String]
    var schema: [String: TdfParser.Object]
}

extension MapInfo {
    
    init(contentsOf ota: FileSystem.File, in filesystem: FileSystem) throws {
        
        name = ota.baseName
        
        let info: TdfParser.Object = try {
            let parser = TdfParser(try filesystem.openFile(ota))
            parser.skipToObject(named: "GlobalHeader")
            return parser.extractObject()
        }()
        properties = info.properties
        schema = info.subobjects
    }
    
}
