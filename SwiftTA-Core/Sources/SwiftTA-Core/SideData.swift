//
//  SideData.swift
//  TAassets
//
//  Created by Logan Jones on 3/29/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


public struct SideInfo {
    
    public var name: String
    public var namePrefix: String
     
    public var commander: String?
    public var palette: String?
    
    public var properties: [String: String]
    
}

public extension SideInfo {
    
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

// MARK:- Sequence specializations

extension Sequence where Element == SideInfo {
    
    func first(withName name: String) -> SideInfo? {
        return self.first(where: { $0.name == name || $0.namePrefix == name })
    }
    
}
