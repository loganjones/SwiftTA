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
}

extension Size2D: CustomStringConvertible {
    var description: String { return "\(width)x\(height)" }
}

extension Size2D {
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

struct Point2D: Equatable {
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
    init(_ tuple: (Int, Int)) {
        x = tuple.0
        y = tuple.1
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
    
    static func / (size: Point2D, divisor: Int) -> Point2D {
        return Point2D(x: size.x / divisor, y: size.y / divisor)
    }
    static func /= (size: inout Point2D, divisor: Int) {
        size.x /= divisor
        size.y /= divisor
    }
    
    static func * (size: Point2D, multiplier: Int) -> Point2D {
        return Point2D(x: size.x * multiplier, y: size.y * multiplier)
    }
    static func *= (size: inout Point2D, multiplier: Int) {
        size.x *= multiplier
        size.y *= multiplier
    }
    
    static func * (size: Point2D, multiplier: Size2D) -> Point2D {
        return Point2D(x: size.x * multiplier.width, y: size.y * multiplier.height)
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
