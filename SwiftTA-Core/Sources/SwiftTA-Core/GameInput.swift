//
//  GameInput.swift
//  
//
//  Created by Logan Jones on 5/25/20.
//

import Foundation

public enum GameInput {
    case click(MouseInput)
    case key(KeyInput)
}

public enum ButtonState {
    case down, up
}

public struct MouseInput {
    public var button: Int
    public var state: ButtonState
    public var cursorLocation: Point2f
    
    public init(button: Int, state: ButtonState, cursorLocation: Point2f) {
        self.button = button
        self.state = state
        self.cursorLocation = cursorLocation
    }
}

public struct KeyInput {
    public var characters: String
    public var state: ButtonState
    public var isRepeat: Bool
    
    public init(characters: String, state: ButtonState, isRepeat: Bool) {
        self.characters = characters
        self.state = state
        self.isRepeat = isRepeat
    }
}
