//
//  MapFeatureTypeId.swift
//  HPIView
//
//  Created by Logan Jones on 10/9/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


/**
 The common identifer for a particular feature type. For example: "Tree1", "MarsVent02", or "AraHenge03".
 
 `FeatureTypeId` type is suitable for keyed lookups; equality checks are made against the lowercased hash of the identifier name.
 This `hashValue` is computed once, at init time.
 
 The identifier name is sourced from a features's TDF file (the object name in each section) or `MapFeatureInfo.name` if loaded.
 This identifier is referenced from other features, from TNT files, and other resources.
 These sources often mix up the casing of a feature's identifier; using `FeatureTypeId` with its case-insensitive equality checks will alleviate this issue.
 */
public struct FeatureTypeId: StringlyIdentifier {
    
    public let name: String
    public let hashValue: Int
    
    public init(named name: String) {
        self.name = name
        self.hashValue = name.lowercased().hashValue
    }
    
    public init(for featureInfo: MapFeatureInfo) {
        self.init(named: featureInfo.name)
    }
    
}
