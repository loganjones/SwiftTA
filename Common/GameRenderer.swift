//
//  GameRenderer.swift
//  SwiftTA iOS
//
//  Created by Logan Jones on 8/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


struct GameViewState {
    var viewport = Rect4f.zero
    var objects: [GameViewObject] = []
}

protocol GameRenderer: class {
    var viewState: GameViewState { get set }
    init?(loadedState: GameState, viewState: GameViewState)
}

protocol RunLoopGameRenderer: GameRenderer {
    func drawFrame()
}

#if canImport(AppKit)
import AppKit
protocol GameViewProvider {
    var view: NSView { get }
}

#elseif canImport(UIKit)
import UIKit
protocol GameViewProvider {
    var view: UIView { get }
}

#endif

enum GameViewObject {
    case unit(GameViewUnit)
}

struct GameViewUnit {
    var type: UnitTypeId
    var position: Vertex3f
    var orientation: Vector3f
    var pose: UnitModel.Instance
}
extension GameViewUnit {
    init(_ unit: UnitInstance) {
        type = unit.type
        position = unit.worldPosition
        orientation = unit.orientation
        pose = unit.modelInstance
    }
}

func viewport(ofSize size: Size2<Int>, centeredOn start: Point2<Int>, in map: MapModel) -> Rect4<Int> {
    
    var rect = Rect4(origin: start, size: size)
    rect.origin.x -= size.width / 2
    rect.origin.y -= size.height / 2
    
    let bounds = Rect4(size: map.resolution)
    
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
    
    return rect
}
