//
//  Geometry+Vector.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/16/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation

public typealias Point2 = SIMD2
public typealias Point3 = SIMD3
public typealias Vertex2 = SIMD2
public typealias Vertex3 = SIMD3
public typealias Vector2 = SIMD2
public typealias Vector3 = SIMD3
public typealias Vector4 = SIMD4


// MARK:- Vector2

public extension Vector2 {
    
    typealias Element = Scalar
    
    @inlinable init(_ size: Size2<Element>) {
        self = size.values
    }
    
    @inlinable func map(transform: (Element) throws -> Element) rethrows -> Vector2<Element> {
        return Vector2(try transform(x), try transform(y))
    }
    @inlinable func map<OtherElement: Numeric>(transform: (Element) throws -> OtherElement) rethrows -> Vector2<OtherElement> {
        return Vector2<OtherElement>(try transform(x), try transform(y))
    }
    
    @inlinable func makeRect(size: Size2<Element>) -> Rect4<Element> {
        return Rect4(origin: self, size: size)
    }
    
}

public extension Vector2 where Element: SignedNumeric & Comparable {
    
    @inlinable func clamped(to rect: Rect4<Element>) -> Vector2<Element> {
        return Vector2(
            Swift.min(Swift.max(rect.minX, x), rect.maxX),
            Swift.min(Swift.max(rect.minY, y), rect.maxY)
        )
    }
    
}

public extension Vector2 where Element: FixedWidthInteger {
    
    @inlinable init<Other>(_ size: Size2<Other>) where Other: SIMDScalar & BinaryFloatingPoint {
        self.init(size.values)
    }
    
    @inlinable init(index: Element, stride: Element) {
        let y = index / stride
        let x = index - (y * stride)
        self.init(x, y)
    }
    
    @inlinable static func * (lhs: Vector2<Element>, rhs: Size2<Element>) -> Vector2<Element> {
        return lhs &* rhs.values
    }
    @inlinable static func *= (lhs: inout Vector2<Element>, rhs: Size2<Element>) {
        lhs &*= rhs.values
    }
    
    @inlinable static func / (lhs: Vector2<Element>, rhs: Size2<Element>) -> Vector2<Element> {
        return lhs / rhs.values
    }
    @inlinable static func /= (lhs: inout Vector2<Element>, rhs: Size2<Element>) {
        lhs /= rhs.values
    }
    
    @inlinable static func • (lhs: Vector2<Element>, rhs: Vector2<Element>) -> Element {
        return (lhs &* rhs).wrappedSum()
    }
    
    @inlinable var lengthSquared: Element {
        return (self &* self).wrappedSum()
    }
    
    @inlinable func index(rowStride: Element) -> Element {
        return (rowStride * y) + x
    }
    
}

public extension Vector2 where Element: FloatingPoint {
    
    @inlinable init(index: Element, stride: Element) {
        let y = index / stride
        let x = index - (y * stride)
        self.init(x, y)
    }
    
    @inlinable static func * (lhs: Vector2<Element>, rhs: Size2<Element>) -> Vector2<Element> {
        return lhs * rhs.values
    }
    @inlinable static func *= (lhs: inout Vector2<Element>, rhs: Size2<Element>) {
        lhs *= rhs.values
    }
    
    @inlinable static func / (lhs: Vector2<Element>, rhs: Size2<Element>) -> Vector2<Element> {
        return lhs / rhs.values
    }
    @inlinable static func /= (lhs: inout Vector2<Element>, rhs: Size2<Element>) {
        lhs /= rhs.values
    }
    
    @inlinable static func • (lhs: Vector2<Element>, rhs: Vector2<Element>) -> Element {
        return (lhs * rhs).sum()
    }
    
    @inlinable var length: Element {
        return self.lengthSquared.squareRoot()
    }
    
    @inlinable var lengthSquared: Element {
        return (self * self).sum()
    }
    
    @inlinable var normalized: Vector2<Element> {
        let f = 1 / self.length
        return self * f
    }
    @inlinable mutating func noramlize() {
        let f = 1 / self.length
        self *= f
    }
    
    @inlinable func truncated(to maxLength: Element) -> Vector2<Element> {
        guard lengthSquared > sqr(maxLength) else { return self }
        let f = maxLength / length
        return self * f
    }
    
    @inlinable func clamped(to rect: Rect4<Element>) -> Vector2<Element> {
        return Vector2(
            Swift.min(Swift.max(rect.minX, x), rect.maxX),
            Swift.min(Swift.max(rect.minY, y), rect.maxY)
        )
    }
    
}

public extension Vector2 where Element: BinaryFloatingPoint {
    
    @inlinable init<Other>(_ size: Size2<Other>) where Other: SIMDScalar & FixedWidthInteger {
        self.init(size.values)
    }
    
    @inlinable init<Other>(_ size: Size2<Other>) where Other: SIMDScalar & BinaryFloatingPoint {
        self.init(size.values)
    }
    
}

public extension Vector2 where Element: TrigonometricFloatingPoint {
    
    init(polar angle: Element, length: Element = 1) {
        self.init(angle.cosine * length, angle.sine * length)
    }
    
    var angle: Element {
        return (y >= 0) ? x.arccosine : -x.arccosine
    }
    
}

@inlinable public func determinant<T: Numeric>(_ a: Vector2<T>, _ b: Vector2<T>) -> T {
    return (a.x * b.y) - (a.y * b.x)
}


// MARK:- Vector3

public extension Vector3 {
    
    typealias Element = Scalar
    
    @inlinable init(xy v: Vector2<Element>, z: Element) { self.init(v.x, v.y, z) }
    
    @inlinable var xy: Vector2<Element> { get { return Vector2(x,y) } set(v) { x = v.x; y = v.y } }
    
    @inlinable func map(transform: (Element) throws -> Element) rethrows -> Vector3<Element> {
        return Vector3<Element>(try transform(x), try transform(y), try transform(z))
    }
    @inlinable func map<OtherElement: Numeric>(transform: (Element) throws -> OtherElement) rethrows -> Vector3<OtherElement> {
        return Vector3<OtherElement>(try transform(x), try transform(y), try transform(z))
    }
    
}

public extension Vector3 where Element: FixedWidthInteger {
    
    @inlinable static func • (lhs: Vector3<Element>, rhs: Vector3<Element>) -> Element {
        return (lhs &* rhs).wrappedSum()
    }
    
    @inlinable static func × (lhs: Vector3<Element>, rhs: Vector3<Element>) -> Vector3<Element> {
        return Vector3<Element>(
            lhs.y * rhs.z - lhs.z * rhs.y,
            lhs.z * rhs.x - lhs.x * rhs.z,
            lhs.x * rhs.y - lhs.y * rhs.x
        )
    }
    
    @inlinable var lengthSquared: Element {
        return (self &* self).wrappedSum()
    }
    
}

public extension Vector3 where Element: FloatingPoint {
    
    @inlinable static func • (lhs: Vector3<Element>, rhs: Vector3<Element>) -> Element {
        return (lhs * rhs).sum()
    }
    
    @inlinable static func × (lhs: Vector3<Element>, rhs: Vector3<Element>) -> Vector3<Element> {
        return Vector3<Element>(
            lhs.y * rhs.z - lhs.z * rhs.y,
            lhs.z * rhs.x - lhs.x * rhs.z,
            lhs.x * rhs.y - lhs.y * rhs.x
        )
    }
    
    @inlinable var length: Element {
        return self.lengthSquared.squareRoot()
    }
    
    @inlinable var lengthSquared: Element {
        return (self * self).sum()
    }
    
    @inlinable var normalized: Vector3<Element> {
        let f = 1 / self.length
        return self * f
    }
    @inlinable mutating func noramlize() {
        let f = 1 / self.length
        self *= f
    }
    
}


// MARK:- Vector4

public extension Vector4 {
    
    typealias Element = Scalar
    
    @inlinable init(xyz v: Vector3<Element>, w: Element) { self.init(v.x, v.y, v.z, w) }
    
    @inlinable var xyz: Vector3<Element> { return Vector3(x,y,z) }
    
    @inlinable func map(transform: (Element) throws -> Element) rethrows -> Vector4<Element> {
        return Vector4<Element>(try transform(x), try transform(y), try transform(z), try transform(w))
    }
    @inlinable func map<OtherElement: Numeric>(transform: (Element) throws -> OtherElement) rethrows -> Vector4<OtherElement> {
        return Vector4<OtherElement>(try transform(x), try transform(y), try transform(z), try transform(w))
    }
    
}

public extension Vector4 where Element: FixedWidthInteger {
    
    @inlinable static func • (lhs: Vector4<Element>, rhs: Vector4<Element>) -> Element {
        return (lhs &* rhs).wrappedSum()
    }
    
    @inlinable var lengthSquared: Element {
        return (self &* self).wrappedSum()
    }
    
}

public extension Vector4 where Element: FloatingPoint {
    
    @inlinable static func • (lhs: Vector4<Element>, rhs: Vector4<Element>) -> Element {
        return (lhs * rhs).sum()
    }
    
    @inlinable var lengthSquared: Element {
        return (self * self).sum()
    }
    
    @inlinable var length: Element {
        return self.lengthSquared.squareRoot()
    }

    @inlinable var normalized: Vector4<Element> {
        let f = 1 / self.length
        return self * f
    }
    @inlinable mutating func noramlize() {
        let f = 1 / self.length
        self *= f
    }
    
}
