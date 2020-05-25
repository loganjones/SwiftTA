//
//  Cursor.swift
//  
//
//  Created by Logan Jones on 4/4/20.
//

import Foundation

/// The shape and appearance of the mouse cursor within the visible GUI.
///
/// For Total Annihilation, each cursor is loaded from a GAF file in the anims folder (see `gafFilename` and `gafFilePath`).
/// The image(s) loaded for a cursor can be a sinle frame or an animated cursor made of many frames.
public enum Cursor: CaseIterable {
    /// The normal "pointer" cursor. This is usually an upwards, slightly pointing left, arrow.
    case normal
    /// This cursor appears over selectable objects, mostly units, in the game world.
    case select
    /// Used when the "Move" action mode is toggled; the next click will dispatch a move action.
    case move
    /// Used when the "Attack" action mode is toggled; the next click will dispatch an attack action.
    /// This cursor also appears over enemy units in the game world.
    case attack
}

public extension Cursor {
    
    /// The TA GAF file that contains a listing of each cursor.
    static let gafFilename = "cursors.gaf"
    
    /// The complete `FileSystem` path for `gafFilename` where a listing of each cursor can be found.
    static let gafFilePath = "anims/\(gafFilename)"
    
    /// The string that this cursor is listed under in the cursor GAF file.
    var gafItemName: String {
        switch self {
        case .normal: return "cursornormal"
        case .select: return "cursorselect"
        case .move: return "cursormove"
        case .attack: return "cursorattack"
        }
    }
    
}
