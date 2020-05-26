//
//  Geometry+BoundingBox2D.swift
//  SwiftTA
//
//  Created by Logan Jones on 5/25/20.
//  Copyright © 2020 Logan Jones. All rights reserved.
//

import Foundation

public typealias BoundingBox2Df = BoundingBox2D<GameFloat>

/// An oriented rectangle composed of four points.
public struct BoundingBox2D<Element: SIMDScalar & FloatingPoint> {
    
    public let points: (a: Point2<Element>, b: Point2<Element>, c: Point2<Element>, d: Point2<Element>)
    
    /// An axis-aligned bounding box that encloses the `points` in their plane.
    public let enclosingRect: Rect4<Element>
    
    public init(center: Point2<Element> = .zero, size: Size2<Element> = Size2<Element>(1,1), orientation: Vector2<Element> = Vector2(1,0)) {
        
        let sizev = Vector2(size)
        let tl = -(sizev / 2)
        let br = tl + sizev
        
        points = (
            center + Point2(tl.x, tl.y).rotated(to: orientation),
            center + Point2(tl.x, br.y).rotated(to: orientation),
            center + Point2(br.x, br.y).rotated(to: orientation),
            center + Point2(br.x, tl.y).rotated(to: orientation)
        )
        
        let minX = min(points.a.x, points.b.x, points.c.x, points.d.x)
        let minY = min(points.a.y, points.b.y, points.c.y, points.d.y)
        let maxX = max(points.a.x, points.b.x, points.c.x, points.d.x)
        let maxY = max(points.a.y, points.b.y, points.c.y, points.d.y)
        
        enclosingRect = Rect4<Element>(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// Returns `true` if the given point lies within the receiver's bounding box.
    @inlinable
    func contains(_ point: Point2<Element>) -> Bool {
        
        let ab = points.b - points.a
        let ad = points.d - points.a
        let ap = point - points.a
        
        let apab = ap • ab
        let abab = ab • ab
        let apad = ap • ad
        let adad = ad • ad
        
        return 0 < apab && apab < abab
            && 0 < apad && apad < adad
    }
    
}
