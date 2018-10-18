//
//  UnitTypeId.swift
//  HPIView
//
//  Created by Logan Jones on 10/9/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


/**
 The common identifer for a particular unit type. For example: "ARMAMD", "CORHP", or "CREDRAG".
 
 `UnitTypeId` type is suitable for keyed lookups; equality checks are made against the lowercased hash of the identifier name.
 This `hashValue` is computed once, at init time.
 
 The identifier name is sourced from a unit's FBI file (the "UnitName" field) or `UnitInfo.name` if loaded.
 */
struct UnitTypeId: StringlyIdentifier {
    
    let name: String
    let hashValue: Int
    
    init(named name: String) {
        self.name = name
        self.hashValue = name.lowercased().hashValue
    }
    
    init(for unitInfo: UnitInfo) {
        self.init(named: unitInfo.name)
    }
    
}
