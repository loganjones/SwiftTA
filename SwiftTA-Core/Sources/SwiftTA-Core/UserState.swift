//
//  UserState.swift
//  
//
//  Created by Logan Jones on 5/29/20.
//

import Foundation

public struct UserState {
    
    public var selection: Set<GameObjectId> = []
    
    public var inputMode: InputMode = .select
    
    public enum InputMode {
        case select
        case move
    }

}
