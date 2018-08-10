//
//  Geometry.swift
//  TAassets
//
//  Created by Logan Jones on 2/19/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

// MARK:- Size & Point

struct Size2D: Equatable {
    var width: Int
    var height: Int
}

extension Size2D {
    static var zero: Size2D { return Size2D(width: 0, height: 0) }
    var area: Int { return width * height }
    var max: Int { return Swift.max(width,height) }
}

extension Size2D: CustomStringConvertible {
    var description: String { return "\(width)x\(height)" }
}

extension Size2D {
    init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
    }
    init(_ tuple: (Int, Int)) {
        width = tuple.0
        height = tuple.1
    }
    func map(apply: (Int) -> Int) -> Size2D {
        return Size2D(width: apply(width), height: apply(height))
    }
}

extension Size2D {
    
    static func / (size: Size2D, divisor: Int) -> Size2D {
        return Size2D(width: size.width / divisor, height: size.height / divisor)
    }
    static func /= (size: inout Size2D, divisor: Int) {
        size.width /= divisor
        size.height /= divisor
    }
    
    static func * (size: Size2D, multiplier: Int) -> Size2D {
        return Size2D(width: size.width * multiplier, height: size.height * multiplier)
    }
    static func *= (size: inout Size2D, multiplier: Int) {
        size.width *= multiplier
        size.height *= multiplier
    }
    
}

struct Point2D: Equatable, Hashable {
    var x: Int
    var y: Int
}

extension Point2D {
    static var zero: Point2D { return Point2D(x: 0, y: 0) }
}

extension Point2D: CustomStringConvertible {
    var description: String { return "(\(x), \(y))" }
}

extension Point2D {
    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }
    init(_ tuple: (Int, Int)) {
        x = tuple.0
        y = tuple.1
    }
    init(index: Int, stride: Int) {
        y = index / stride
        x = index - (y * stride)
    }
}

extension Point2D {
    
    func index(rowStride: Int) -> Int {
        return (rowStride * y) + x
    }
    
}

extension Point2D {
    
    static func + (lhs: Point2D, rhs: Size2D) -> Point2D {
        return Point2D(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
    }
    
    static func - (lhs: Point2D, rhs: Point2D) -> Point2D {
        return Point2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func / (point: Point2D, divisor: Int) -> Point2D {
        return Point2D(x: point.x / divisor, y: point.y / divisor)
    }
    static func /= (point: inout Point2D, divisor: Int) {
        point.x /= divisor
        point.y /= divisor
    }
    
    static func / (point: Point2D, divisor: Size2D) -> Point2D {
        return Point2D(x: point.x / divisor.width, y: point.y / divisor.height)
    }
    static func /= (point: inout Point2D, divisor: Size2D) {
        point.x /= divisor.width
        point.y /= divisor.height
    }
    
    static func * (point: Point2D, multiplier: Int) -> Point2D {
        return Point2D(x: point.x * multiplier, y: point.y * multiplier)
    }
    static func *= (point: inout Point2D, multiplier: Int) {
        point.x *= multiplier
        point.y *= multiplier
    }
    
    static func * (point: Point2D, multiplier: Size2D) -> Point2D {
        return Point2D(x: point.x * multiplier.width, y: point.y * multiplier.height)
    }
    
}

struct Rect2D: Equatable {
    var origin: Point2D
    var size: Size2D
}

extension Rect2D: CustomStringConvertible {
    var description: String { return "(origin: \(origin), size: \(size))" }
}

extension Rect2D {
    
    static var zero: Rect2D { return Rect2D(origin: .zero, size: .zero) }
    
    init(size: Size2D) {
        self.init(origin: .zero, size: size)
    }
    
    init(x: Int, y: Int, width: Int, height: Int) {
        origin = Point2D(x: x, y: y)
        size = Size2D(width: width, height: height)
    }
    
}

extension Rect2D {
    
    var left: Int { return origin.x }
    var right: Int { return origin.x + size.width }
    var top: Int { return origin.y }
    var bottom: Int { return origin.y + size.height }
    
    init(left: Int, top: Int, right: Int, bottom: Int) {
        origin = Point2D(x: left, y: top)
        size = Size2D(width: right - left, height: bottom - top)
    }
    
    var minX: Int { return origin.x }
    var maxX: Int { return origin.x + size.width }
    var minY: Int { return origin.y }
    var maxY: Int { return origin.y + size.height }
    
    var widthRange: CountableRange<Int> { return minX..<maxX }
    var heightRange: CountableRange<Int> { return minY..<maxY }
    
}

extension Rect2D {
    
    func clamp(within bounds: Rect2D) -> Rect2D {
        var rect = self
        if rect.origin.x < bounds.origin.x {
            rect.size.width -= bounds.origin.x - rect.origin.x
            rect.origin.x = bounds.origin.x
        }
        if rect.origin.y < bounds.origin.y {
            rect.size.height -= bounds.origin.y - rect.origin.y
            rect.origin.y = bounds.origin.y
        }
        if rect.right > bounds.right {
            rect.size.width = bounds.right - rect.origin.x
        }
        if rect.bottom > bounds.bottom {
            rect.size.height = bounds.bottom - rect.origin.y
        }
        return rect
    }
    
    func insetBy(dx: Int, dy: Int) -> Rect2D {
        return Rect2D(
            origin: Point2D(x: origin.x + dx,
                            y: origin.y + dy),
            size: Size2D(width: size.width - 2*dx,
                         height: size.height - 2*dy))
    }
    func insetBy(_ ds: Int) -> Rect2D {
        return insetBy(dx: ds, dy: ds)
    }
    
}

// MARK:- Vertex & Vector

struct Vertex3 {
    var x: Double
    var y: Double
    var z: Double
}
struct Vector3 {
    var x: Double
    var y: Double
    var z: Double
}
struct Vertex2 {
    var x: Double
    var y: Double
}
struct Vector2 {
    var x: Double
    var y: Double
}

extension Vertex3: CustomStringConvertible {
    var description: String {
        return "(\(x), \(y), \(z))"
    }
}
extension Vector3: CustomStringConvertible {
    var description: String {
        return "->(\(x), \(y), \(z))"
    }
}
extension Vertex2: CustomStringConvertible {
    var description: String {
        return "(\(x), \(y))"
    }
}
extension Vector2: CustomStringConvertible {
    var description: String {
        return "->(\(x), \(y))"
    }
}

func +(lhs: Vertex3, rhs: Vector3) -> Vertex3 {
    return Vertex3(
        x: lhs.x + rhs.x,
        y: lhs.y + rhs.y,
        z: lhs.z + rhs.z
    )
}
func +(lhs: Vector3, rhs: Vector3) -> Vector3 {
    return Vector3(
        x: lhs.x + rhs.x,
        y: lhs.y + rhs.y,
        z: lhs.z + rhs.z
    )
}
func +(lhs: Vertex2, rhs: Vertex2) -> Vertex2 {
    return Vertex2(
        x: lhs.x + rhs.x,
        y: lhs.y + rhs.y
    )
}
func +(lhs: Vector2, rhs: Vector2) -> Vector2 {
    return Vector2(
        x: lhs.x + rhs.x,
        y: lhs.y + rhs.y
    )
}

func -(lhs: Vertex3, rhs: Vertex3) -> Vector3 {
    return Vector3(
        x: lhs.x - rhs.x,
        y: lhs.y - rhs.y,
        z: lhs.z - rhs.z
    )
}

infix operator •: MultiplicationPrecedence
func •(lhs: Vector3, rhs: Vector3) -> Double {
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}
func •(lhs: Vector2, rhs: Vector2) -> Double {
    return lhs.x * rhs.x + lhs.y * rhs.y
}

infix operator ×: MultiplicationPrecedence
func ×(lhs: Vector3, rhs: Vector3) -> Vector3 {
    return Vector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}

extension Vertex3 {
    static var zero: Vertex3 { return Vertex3(x: 0, y: 0, z: 0) }
}
extension Vector3 {
    static var zero: Vector3 { return Vector3(x: 0, y: 0, z: 0) }
}
extension Vertex2 {
    static var zero: Vertex2 { return Vertex2(x: 0, y: 0) }
}
extension Vector2 {
    static var zero: Vector2 { return Vector2(x: 0, y: 0) }
}

extension Vector3 {
    func map(_ transform: (Double) throws -> Double) rethrows -> Vector3 {
        return Vector3(
            x: try transform(x),
            y: try transform(y),
            z: try transform(z)
        )
    }
}

extension Vector2 {
    func map(_ transform: (Double) throws -> Double) rethrows -> Vector2 {
        return Vector2(
            x: try transform(x),
            y: try transform(y)
        )
    }
}
