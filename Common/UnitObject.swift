//
//  UnitObject.swift
//  TAassets
//
//  Created by Logan Jones on 5/6/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

struct UnitObject {
    
    var baseData: UnitData
    
}

extension UnitModel.Instance {
    
    init(for model: UnitModel) {
        self.init(count: model.pieces.count)
    }
    
    init(count: Int) {
        pieces = Array(repeating: UnitModel.PieceState(), count: count)
    }
    
}
