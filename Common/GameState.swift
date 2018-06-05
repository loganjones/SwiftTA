//
//  GameState.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 8/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


class GameState {
    
    let filesystem: FileSystem
    let map: MapModel
    
    init(_ filesystem: FileSystem, _ map: MapModel) {
        self.filesystem = filesystem
        self.map = map
    }
    
}

extension GameState {
    
    static func loadStuff(from taDir: URL, mapName: String) throws -> GameState {
        
        print("Loading TA file heirarchy...", terminator: "")
        let filesystem = try FileSystem(mergingHpisIn: taDir)
        print(" done.")
        
        print("Loading map...", terminator: "")
        let map = try MapModel(contentsOf: filesystem.openFile(at: "maps/\(mapName).tnt"))
        print(" done.")
        
        return GameState(filesystem, map)
    }
    
}
