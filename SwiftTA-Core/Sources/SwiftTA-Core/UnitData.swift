//
//  UnitData.swift
//  TAassets
//
//  Created by Logan Jones on 5/7/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

struct UnitData {
    var info: UnitInfo
    var model: UnitModel
    var script: UnitScript
}

extension UnitData {
    init(loading unitInfo: UnitInfo, from filesystem: FileSystem) throws {
        info = unitInfo
        let modelFile = try filesystem.openFile(at: "objects3d/" + unitInfo.object + ".3DO")
        model = try UnitModel(contentsOf: modelFile)
        let scriptFile = try filesystem.openFile(at: "scripts/" + unitInfo.object + ".COB")
        script = try UnitScript(contentsOf: scriptFile)
    }
}
