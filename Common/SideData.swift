//
//  SideData.swift
//  TAassets
//
//  Created by Logan Jones on 3/29/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


struct SideInfo {
    
    var name: String
    var namePrefix: String
    
    var commander: String?
    var palette: String?
    
    var properties: [String: String]
    
}

extension SideInfo {
    
    static func load<File>(contentsOf tdf: File) throws -> [SideInfo]
        where File: FileReadHandle
    {
        var sides = [SideInfo]()
        
        let parser = TdfParser(tdf)
        while let sideNum = parser.skipToNextObject() {
            
            guard sideNum.prefix(4).caseInsensitiveCompare("side") == .orderedSame else {
                parser.skipObject()
                continue
            }
            
            let info = parser.extractObject(normalizeKeys: true)
            
            guard let side = try? SideInfo(info) else {
                continue
            }
            
            sides.append(side)
        }
        
        return sides
    }
    
    private init(_ info: TdfParser.Object) throws {
        name = try info.requiredStringProperty("name")
        namePrefix = try info.requiredStringProperty("nameprefix")
        commander = info["commander"]
        palette = info["palette"]
        properties = info.properties
    }
    
}
