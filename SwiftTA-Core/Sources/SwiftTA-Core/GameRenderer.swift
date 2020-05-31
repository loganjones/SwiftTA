//
//  GameRenderer.swift
//  SwiftTA iOS
//
//  Created by Logan Jones on 8/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


public struct GameViewState {
    public var viewport = Rect4f.zero
    public var screenSize = Size2f.zero
    public var cursorLocation = Point2f.zero
    public var cursorType = Cursor.normal
    public var objects: [GameViewObject] = []
    
    public init(viewport: Rect4f = .zero, objects: [GameViewObject] = []) {
        self.viewport = viewport
        self.screenSize = viewport.size
        self.objects = objects
    }
}

public protocol GameRenderer: class {
    var viewState: GameViewState { get set }
    init?(loadedState: GameState, viewState: GameViewState)
}

public protocol RunLoopGameRenderer: GameRenderer {
    func drawFrame()
}

#if canImport(AppKit)
import AppKit
public protocol GameViewProvider {
    var view: NSView { get }
}

#elseif canImport(UIKit)
import UIKit
public protocol GameViewProvider {
    var view: UIView { get }
}

#endif

public enum GameViewObject {
    case unit(GameViewUnit)
}

public struct GameViewUnit {
    public var type: UnitData
    public var position: Vertex3f
    public var orientation: Vector3f
    public var pose: UnitModel.Instance
    public var selected: Bool
}
public extension GameViewUnit {
    init(_ unit: UnitInstance, isSelected: Bool = false) {
        type = unit.type
        position = unit.worldPosition
        orientation = unit.orientation
        pose = unit.modelInstance
        selected = isSelected
    }
}

public func viewport(ofSize size: Size2<Int>, centeredOn start: Point2<Int>, in map: MapModel) -> Rect4<Int> {
    
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
