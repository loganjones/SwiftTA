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

protocol GameRenderer: class {
    
    var viewState: GameViewState { get set }
    init?(loadedState: GameState, viewState: GameViewState)
    
    #if canImport(AppKit)
    var view: NSView { get }
    #elseif canImport(UIKit)
    var view: UIView { get }
    #else
    func drawFrame()
    #endif
    
}

func viewport(ofSize size: Size2D, centeredOn start: Point2D, in map: MapModel) -> CGRect {
    
    var rect = Rect2D(origin: start, size: size)
    rect.origin.x -= size.width / 2
    rect.origin.y -= size.height / 2
    
    let bounds = Rect2D(size: map.resolution)
    
    if rect.origin.x < bounds.origin.x {
        rect.origin.x = bounds.origin.x
    }
    if rect.origin.y < bounds.origin.y {
        rect.origin.y = bounds.origin.y
    }
    if rect.right > bounds.right {
        rect.origin.x = bounds.right - size.width
    }
    if rect.bottom > bounds.bottom {
        rect.origin.y = bounds.bottom - size.height
    }
    
    return CGRect(rect)
}
