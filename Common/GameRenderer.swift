//
//  GameRenderer.swift
//  SwiftTA iOS
//
//  Created by Logan Jones on 8/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation

// TEMP?
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif


struct GameViewState {
    var viewport = CGRect.zero
}

protocol GameRenderer: AnyObject {
    
    var viewState: GameViewState { get set }
    init?(loadedState: GameState, viewState: GameViewState)
    
    #if canImport(AppKit)
    var view: NSView { get }
    #elseif canImport(UIKit)
    var view: UIView { get }
    #endif
    
}
