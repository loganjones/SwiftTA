//
//  Geometry+Vector.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/16/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


public struct Vector2<Element: Numeric>: Vector2Protocol {
    public var values: (Element, Element)
    @inlinable public var x: Element { get { return values.0 } set(s) { values.0 = s } }
    @inlinable public var y: Element { get { return values.1 } set(s) { values.1 = s } }
    @inlinable public init(values: (Element, Element)) { self.values = values }
}

public extension Vector2 {
    
    @inlinable init(_ x: Element, _ y: Element) { self.init(values: (x, y)) }
    @inlinable init(x: Element, y: Element) { self.init(values: (x, y)) }
    @inlinable init(_ scalar: Element) { self.init(values: (scalar, scalar)) }
    @inlinable init() { self.init(0) }
    
    @inlinable static var zero: Vector2 { return Vector2() }
    @inlinable static var null: Vector2 { return Vector2() }
    
    @inlinable func map(transform: (Element) throws -> Element) rethrows -> Vector2 {
        return Vector2(try transform(x), try transform(y))
    }
    @inlinable func map<OtherElement: Numeric>(transform: (Element) throws -> OtherElement) rethrows -> Vector2<OtherElement> {
        return Vector2<OtherElement>(try transform(x), try transform(y))
    }
    
    @inlinable func makeRect(size: Size2<Element>) -> Rect4<Element> {
        return Rect4(origin: self, size: size)
    }
    
}

extension Vector2: CustomStringConvertible {
    @inlinable public var description: String { return "(\(x), \(y))" }
}

public extension Vector2 where Element: Comparable {
    @inlinable var min: Element { return Swift.min(x, y) }
    @inlinable var max: Element { return Swift.max(x, y) }
}
public extension Vector2 where Element: BinaryInteger {
    @inlinable func index(rowStride: Element) -> Element {
        return (rowStride * y) + x
    }
}

extension Vector2: Equatable {
    @inlinable public static func == (lhs: Vector2, rhs: Vector2) -> Bool { return lhs.values == rhs.values }
}
extension Vector2: Hashable where Element: Hashable {
    @inlinable public func hash(into hasher: inout Hasher) { hasher.combine(x); hasher.combine(y) }
}

public extension Vector2 {
    
    @inlinable static func + (lhs: Vector2, rhs: Vector2) -> Vector2 {
        return Vector2(
            lhs.x + rhs.x,
            lhs.y + rhs.y)
    }
    @inlinable static func += (lhs: inout Vector2, rhs: Element) {
        lhs.values.0 += rhs
        lhs.values.1 += rhs
    }
    
    @inlinable static func - (lhs: Vector2, rhs: Vector2) -> Vector2 {
        return Vector2(
            lhs.x - rhs.x,
            lhs.y - rhs.y)
    }
    @inlinable static func -= (lhs: inout Vector2, rhs: Vector2) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }
    
    @inlinable static func * (lhs: Vector2, rhs: Element) -> Vector2 {
        return Vector2(
            lhs.x * rhs,
            lhs.y * rhs)
    }
    @inlinable static func *= (lhs: inout Vector2, rhs: Element) {
        lhs.x *= rhs
        lhs.y *= rhs
    }
    
    @inlinable static func * (lhs: Vector2, rhs: Vector2) -> Vector2 {
        return Vector2(
            lhs.x * rhs.x,
            lhs.y * rhs.y)
    }
    @inlinable static func *= (lhs: inout Vector2, rhs: Vector2) {
        lhs.x *= rhs.x
        lhs.y *= rhs.y
    }
    @inlinable static func * (lhs: Vector2, rhs: Size2<Element>) -> Vector2 {
        return Vector2(
            lhs.x * rhs.width,
            lhs.y * rhs.height)
    }
    @inlinable static func *= (lhs: inout Vector2, rhs: Size2<Element>) {
        lhs.x *= rhs.width
        lhs.y *= rhs.height
    }
    
    @inlinable static func • (lhs: Vector2, rhs: Vector2) -> Element {
        return lhs.x * rhs.x + lhs.y * rhs.y
    }
    
    @inlinable var lengthSquared: Element {
        return (x * x) + (y * y)
    }
    
}

public extension Vector2 where Element: SignedNumeric {
    @inlinable static prefix func - (rhs: Vector2) -> Vector2 {
        return Vector2(
            -rhs.x,
            -rhs.y)
    }
}

public extension Vector2 where Element: BinaryInteger {
    
    @inlinable static func / (lhs: Vector2, rhs: Element) -> Vector2 {
        return Vector2(
            lhs.x / rhs,
            lhs.y / rhs)
    }
    @inlinable static func /= (lhs: inout Vector2, rhs: Element) {
        lhs.x /= rhs
        lhs.y /= rhs
    }
    
    @inlinable static func / (lhs: Vector2, rhs: Vector2) -> Vector2 {
        return Vector2(
            lhs.x / rhs.x,
            lhs.y / rhs.y)
    }
    @inlinable static func /= (lhs: inout Vector2, rhs: Vector2) {
        lhs.x /= rhs.x
        lhs.y /= rhs.y
    }
    
    @inlinable static func / (lhs: Vector2, rhs: Size2<Element>) -> Vector2 {
        return Vector2(
            lhs.x / rhs.width,
            lhs.y / rhs.height)
    }
    @inlinable static func /= (lhs: inout Vector2, rhs: Size2<Element>) {
        lhs.x /= rhs.width
        lhs.y /= rhs.height
    }
    
    @inlinable static func % (lhs: Vector2, rhs: Element) -> Vector2 {
        return Vector2(
            lhs.x % rhs,
            lhs.y % rhs)
    }
    @inlinable static func %= (lhs: inout Vector2, rhs: Element) {
        lhs.x %= rhs
        lhs.y %= rhs
    }
    
    @inlinable static func % (lhs: Vector2, rhs: Vector2) -> Vector2 {
        return Vector2(
            lhs.x % rhs.x,
            lhs.y % rhs.y)
    }
    @inlinable static func %= (lhs: inout Vector2, rhs: Vector2) {
        lhs.x %= rhs.x
        lhs.y %= rhs.y
    }
    
}

public extension Vector2 where Element: FloatingPoint {
    
    @inlinable static func / (lhs: Vector2, rhs: Element) -> Vector2 {
        return Vector2(
            lhs.x / rhs,
            lhs.y / rhs)
    }
    @inlinable static func /= (lhs: inout Vector2, rhs: Element) {
        lhs.x /= rhs
        lhs.y /= rhs
    }
    
    @inlinable static func / (lhs: Vector2, rhs: Vector2) -> Vector2 {
        return Vector2(
            lhs.x / rhs.x,
            lhs.y / rhs.y)
    }
    @inlinable static func /= (lhs: inout Vector2, rhs: Vector2) {
        lhs.x /= rhs.x
        lhs.y /= rhs.y
    }
    
    @inlinable static func / (lhs: Vector2, rhs: Size2<Element>) -> Vector2 {
        return Vector2(
            lhs.x / rhs.width,
            lhs.y / rhs.height)
    }
    @inlinable static func /= (lhs: inout Vector2, rhs: Size2<Element>) {
        lhs.x /= rhs.width
        lhs.y /= rhs.height
    }
    
    @inlinable var length: Element {
        return sqrt( (x * x) + (y * y) )
    }
    
    @inlinable var normalized: Vector2 {
        let f = 1 / self.length
        return self * f
    }
    @inlinable mutating func noramlize() {
        let f = 1 / self.length
        self *= f
    }
    
}

public extension Vector2 where Element: Division {
    @inlinable init(index: Element, stride: Element) {
        let y = index / stride
        let x = index - (y * stride)
        self.init(x, y)
    }
}


// MARK:- Vector3

public struct Vector3<Element: Numeric>: Vector3Protocol {
    public var values: (Element, Element, Element)
    @inlinable public var x: Element { get { return values.0 } set(s) { values.0 = s } }
    @inlinable public var y: Element { get { return values.1 } set(s) { values.1 = s } }
    @inlinable public var z: Element { get { return values.2 } set(s) { values.2 = s } }
    @inlinable public init(values: (Element, Element, Element)) { self.values = values }
}

public extension Vector3 {
    
    @inlinable init(_ x: Element, _ y: Element, _ z: Element) { self.init(values: (x, y, z)) }
    @inlinable init(x: Element, y: Element, z: Element) { self.init(values: (x, y, z)) }
    @inlinable init(_ scalar: Element) { self.init(values: (scalar, scalar, scalar)) }
    @inlinable init() { self.init(0) }
    
    @inlinable init(xy v: Vector2<Element>, z: Element = 0) { self.init(values: (v.x, v.y, z)) }
    
    @inlinable static var zero: Vector3 { return Vector3() }
    @inlinable static var null: Vector3 { return Vector3() }
    
    @inlinable var xy: Vector2<Element> { return Vector2(x,y) }
    
    @inlinable func map(transform: (Element) throws -> Element) rethrows -> Vector3 {
        return Vector3(try transform(x), try transform(y), try transform(z))
    }
    @inlinable func map<OtherElement: Numeric>(transform: (Element) throws -> OtherElement) rethrows -> Vector3<OtherElement> {
        return Vector3<OtherElement>(try transform(x), try transform(y), try transform(z))
    }
    
}

extension Vector3: CustomStringConvertible {
    @inlinable public var description: String { return "(\(x), \(y)), \(z))" }
}

public extension Vector3 where Element: Comparable {
    @inlinable var min: Element { return Swift.min(x,y,z) }
    @inlinable var max: Element { return Swift.max(x,y,z) }
}

extension Vector3: Equatable {
    @inlinable public static func == (lhs: Vector3, rhs: Vector3) -> Bool { return lhs.values == rhs.values }
}
extension Vector3: Hashable where Element: Hashable {
    @inlinable public func hash(into hasher: inout Hasher) { hasher.combine(x); hasher.combine(y); hasher.combine(z) }
}

public extension Vector3 {
    
    @inlinable static func + (lhs: Vector3, rhs: Element) -> Vector3 {
        return Vector3(
            lhs.x + rhs,
            lhs.y + rhs,
            lhs.z + rhs
        )
    }
    @inlinable static func += (lhs: inout Vector3, rhs: Element) {
        lhs.x += rhs
        lhs.y += rhs
        lhs.z += rhs
    }
    
    @inlinable static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(
            lhs.x + rhs.x,
            lhs.y + rhs.y,
            lhs.z + rhs.z
        )
    }
    @inlinable static func += (lhs: inout Vector3, rhs: Vector3) {
        lhs.x += rhs.x
        lhs.y += rhs.y
        lhs.z += rhs.z
    }
    
    @inlinable static func - (lhs: Vector3, rhs: Element) -> Vector3 {
        return Vector3(
            lhs.x - rhs,
            lhs.y - rhs,
            lhs.z - rhs
        )
    }
    @inlinable static func -= (lhs: inout Vector3, rhs: Element) {
        lhs.x -= rhs
        lhs.y -= rhs
        lhs.z -= rhs
    }
    
    @inlinable static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(
            lhs.x - rhs.x,
            lhs.y - rhs.y,
            lhs.z - rhs.z
        )
    }
    @inlinable static func -= (lhs: inout Vector3, rhs: Vector3) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
        lhs.z -= rhs.z
    }
    
    @inlinable static func * (lhs: Vector3, rhs: Element) -> Vector3 {
        return Vector3(
            lhs.x * rhs,
            lhs.y * rhs,
            lhs.z * rhs)
    }
    @inlinable static func *= (lhs: inout Vector3, rhs: Element) {
        lhs.x *= rhs
        lhs.y *= rhs
        lhs.z *= rhs
    }
    
    @inlinable static func * (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(
            lhs.x * rhs.x,
            lhs.y * rhs.y,
            lhs.z * rhs.z)
    }
    @inlinable static func *= (lhs: inout Vector3, rhs: Vector3) {
        lhs.x *= rhs.x
        lhs.y *= rhs.y
        lhs.z *= rhs.z
    }
    
    @inlinable static func • (lhs: Vector3, rhs: Vector3) -> Element {
        return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }
    
    @inlinable static func × (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(values: (
            lhs.y * rhs.z - lhs.z * rhs.y,
            lhs.z * rhs.x - lhs.x * rhs.z,
            lhs.x * rhs.y - lhs.y * rhs.x
        ))
    }
    
    @inlinable var lengthSquared: Element {
        return (x * x) + (y * y) + (z * z)
    }
    
}

public extension Vector3 where Element: SignedNumeric {
    @inlinable static prefix func - (rhs: Vector3) -> Vector3 {
        return Vector3(-rhs.x, -rhs.y, -rhs.z)
    }
}

public extension Vector3 where Element: BinaryInteger {
    
    @inlinable static func / (lhs: Vector3, rhs: Element) -> Vector3 {
        return Vector3(
            lhs.x / rhs,
            lhs.y / rhs,
            lhs.z / rhs)
    }
    @inlinable static func /= (lhs: inout Vector3, rhs: Element) {
        lhs.x /= rhs
        lhs.y /= rhs
        lhs.z /= rhs
    }
    
    @inlinable static func / (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(
            lhs.x / rhs.x,
            lhs.y / rhs.y,
            lhs.z / rhs.z)
    }
    @inlinable static func /= (lhs: inout Vector3, rhs: Vector3) {
        lhs.x /= rhs.x
        lhs.y /= rhs.y
        lhs.z /= rhs.z
    }
    
    @inlinable static func % (lhs: Vector3, rhs: Element) -> Vector3 {
        return Vector3(
            lhs.x % rhs,
            lhs.y % rhs,
            lhs.z % rhs)
    }
    @inlinable static func %= (lhs: inout Vector3, rhs: Element) {
        lhs.x %= rhs
        lhs.y %= rhs
        lhs.z %= rhs
    }
    
    @inlinable static func % (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(
            lhs.x % rhs.x,
            lhs.y % rhs.y,
            lhs.z % rhs.z)
    }
    @inlinable static func %= (lhs: inout Vector3, rhs: Vector3) {
        lhs.x %= rhs.x
        lhs.y %= rhs.y
        lhs.z %= rhs.z
    }
    
}

public extension Vector3 where Element: FloatingPoint {
    
    @inlinable static func / (lhs: Vector3, rhs: Element) -> Vector3 {
        return Vector3(
            lhs.x / rhs,
            lhs.y / rhs,
            lhs.z / rhs)
    }
    @inlinable static func /= (lhs: inout Vector3, rhs: Element) {
        lhs.x /= rhs
        lhs.y /= rhs
        lhs.z /= rhs
    }
    
    @inlinable static func / (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(
            lhs.x / rhs.x,
            lhs.y / rhs.y,
            lhs.z / rhs.z)
    }
    @inlinable static func /= (lhs: inout Vector3, rhs: Vector3) {
        lhs.x /= rhs.x
        lhs.y /= rhs.y
        lhs.z /= rhs.z
    }
    
    @inlinable var length: Element {
        return sqrt( (x * x) + (y * y) + (z * z) )
    }
    
    @inlinable var normalized: Vector3 {
        let f = 1 / self.length
        return self * f
    }
    @inlinable mutating func noramlize() {
        let f = 1 / self.length
        self *= f
    }
    
}


// MARK:- Vector4

public struct Vector4<Element: Numeric>: Vector4Protocol {
    public var values: (Element, Element, Element, Element)
    @inlinable public var x: Element { get { return values.0 } set(s) { values.0 = s } }
    @inlinable public var y: Element { get { return values.1 } set(s) { values.1 = s } }
    @inlinable public var z: Element { get { return values.2 } set(s) { values.2 = s } }
    @inlinable public var w: Element { get { return values.3 } set(s) { values.3 = s } }
    @inlinable public init(values: (Element, Element, Element, Element)) { self.values = values }
}

public extension Vector4 {
    
    @inlinable init(_ x: Element, _ y: Element, _ z: Element, _ w: Element) { self.init(values: (x, y, z, w)) }
    @inlinable init(x: Element, y: Element, z: Element, w: Element) { self.init(values: (x, y, z, w)) }
    @inlinable init(_ scalar: Element) { self.init(values: (scalar, scalar, scalar, scalar)) }
    @inlinable init() { self.init(0) }
    @inlinable init(_ copy: Vector4) { self.init(values: copy.values) }
    
    @inlinable init(xyz v: Vector3<Element>, w: Element = 0) { self.init(values: (v.x, v.y, v.z, w)) }
    
    @inlinable static var zero: Vector4 { return Vector4() }
    @inlinable static var null: Vector4 { return Vector4() }
    
    @inlinable var xyz: Vector3<Element> { return Vector3(x,y,z) }
    
    @inlinable func map(transform: (Element) throws -> Element) rethrows -> Vector4 {
        return Vector4(try transform(x), try transform(y), try transform(z), try transform(w))
    }
    @inlinable func map<OtherElement: Numeric>(transform: (Element) throws -> OtherElement) rethrows -> Vector4<OtherElement> {
        return Vector4<OtherElement>(try transform(x), try transform(y), try transform(z), try transform(w))
    }
    
}

extension Vector4: CustomStringConvertible {
    @inlinable public var description: String { return "(\(x), \(y)), \(z), \(w))" }
}

public extension Vector4 where Element: Comparable {
    @inlinable var min: Element { return Swift.min(x,y,z,w) }
    @inlinable var max: Element { return Swift.max(x,y,z,w) }
}

extension Vector4: Equatable {
    @inlinable public static func == (lhs: Vector4, rhs: Vector4) -> Bool { return lhs.values == rhs.values }
}
extension Vector4: Hashable where Element: Hashable {
    @inlinable public func hash(into hasher: inout Hasher) { hasher.combine(x); hasher.combine(y); hasher.combine(z); hasher.combine(w) }
}

public extension Vector4 {
    
    @inlinable static func + (lhs: Vector4, rhs: Element) -> Vector4 {
        return Vector4(
            lhs.x + rhs,
            lhs.y + rhs,
            lhs.z + rhs,
            lhs.w + rhs
        )
    }
    @inlinable static func += (lhs: inout Vector4, rhs: Element) {
        lhs.x += rhs
        lhs.y += rhs
        lhs.z += rhs
        lhs.w += rhs
    }
    
    @inlinable static func + (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return Vector4(
            lhs.x + rhs.x,
            lhs.y + rhs.y,
            lhs.z + rhs.z,
            lhs.w + rhs.w
        )
    }
    @inlinable static func += (lhs: inout Vector4, rhs: Vector4) {
        lhs.x += rhs.x
        lhs.y += rhs.y
        lhs.z += rhs.z
        lhs.w += rhs.w
    }
    
    @inlinable static func - (lhs: Vector4, rhs: Element) -> Vector4 {
        return Vector4(
            lhs.x - rhs,
            lhs.y - rhs,
            lhs.z - rhs,
            lhs.w - rhs
        )
    }
    @inlinable static func -= (lhs: inout Vector4, rhs: Element) {
        lhs.x -= rhs
        lhs.y -= rhs
        lhs.z -= rhs
        lhs.w -= rhs
    }
    
    @inlinable static func - (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return Vector4(
            lhs.x - rhs.x,
            lhs.y - rhs.y,
            lhs.z - rhs.z,
            lhs.w - rhs.w
        )
    }
    @inlinable static func -= (lhs: inout Vector4, rhs: Vector4) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
        lhs.z -= rhs.z
        lhs.w -= rhs.w
    }
    
    @inlinable static func * (lhs: Vector4, rhs: Element) -> Vector4 {
        return Vector4(
            lhs.x * rhs,
            lhs.y * rhs,
            lhs.z * rhs,
            lhs.w * rhs)
    }
    @inlinable static func *= (lhs: inout Vector4, rhs: Element) {
        lhs.x *= rhs
        lhs.y *= rhs
        lhs.z *= rhs
        lhs.w *= rhs
    }
    
    @inlinable static func * (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return Vector4(
            lhs.x * rhs.x,
            lhs.y * rhs.y,
            lhs.z * rhs.z,
            lhs.w * rhs.w)
    }
    @inlinable static func *= (lhs: inout Vector4, rhs: Vector4) {
        lhs.x *= rhs.x
        lhs.y *= rhs.y
        lhs.z *= rhs.z
        lhs.w *= rhs.w
    }
    
    @inlinable static func • (lhs: Vector4, rhs: Vector4) -> Element {
        return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z + lhs.w * rhs.w
    }
    
    @inlinable var lengthSquared: Element {
        return (x * x) + (y * y) + (z * z) + (w * w)
    }
    
}

public extension Vector4 where Element: SignedNumeric {
    @inlinable static prefix func - (rhs: Vector4) -> Vector4 {
        return Vector4(-rhs.x, -rhs.y, -rhs.z, -rhs.w)
    }
}

public extension Vector4 where Element: BinaryInteger {
    
    @inlinable static func / (lhs: Vector4, rhs: Element) -> Vector4 {
        return Vector4(
            lhs.x / rhs,
            lhs.y / rhs,
            lhs.z / rhs,
            lhs.w / rhs)
    }
    @inlinable static func /= (lhs: inout Vector4, rhs: Element) {
        lhs.x /= rhs
        lhs.y /= rhs
        lhs.z /= rhs
        lhs.w /= rhs
    }
    
    @inlinable static func / (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return Vector4(
            lhs.x / rhs.x,
            lhs.y / rhs.y,
            lhs.z / rhs.z,
            lhs.w / rhs.w)
    }
    @inlinable static func /= (lhs: inout Vector4, rhs: Vector4) {
        lhs.x /= rhs.x
        lhs.y /= rhs.y
        lhs.z /= rhs.z
        lhs.w /= rhs.w
    }
    
    @inlinable static func % (lhs: Vector4, rhs: Element) -> Vector4 {
        return Vector4(
            lhs.x % rhs,
            lhs.y % rhs,
            lhs.z % rhs,
            lhs.w % rhs)
    }
    @inlinable static func %= (lhs: inout Vector4, rhs: Element) {
        lhs.x %= rhs
        lhs.y %= rhs
        lhs.z %= rhs
        lhs.w %= rhs
    }
    
    @inlinable static func % (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return Vector4(
            lhs.x % rhs.x,
            lhs.y % rhs.y,
            lhs.z % rhs.z,
            lhs.w % rhs.w)
    }
    @inlinable static func %= (lhs: inout Vector4, rhs: Vector4) {
        lhs.x %= rhs.x
        lhs.y %= rhs.y
        lhs.z %= rhs.z
        lhs.w %= rhs.w
    }
    
}

public extension Vector4 where Element: FloatingPoint {
    
    @inlinable static func / (lhs: Vector4, rhs: Element) -> Vector4 {
        return Vector4(
            lhs.x / rhs,
            lhs.y / rhs,
            lhs.z / rhs,
            lhs.w / rhs)
    }
    @inlinable static func /= (lhs: inout Vector4, rhs: Element) {
        lhs.x /= rhs
        lhs.y /= rhs
        lhs.z /= rhs
        lhs.w /= rhs
    }
    
    @inlinable static func / (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return Vector4(
            lhs.x / rhs.x,
            lhs.y / rhs.y,
            lhs.z / rhs.z,
            lhs.w / rhs.w)
    }
    @inlinable static func /= (lhs: inout Vector4, rhs: Vector4) {
        lhs.x /= rhs.x
        lhs.y /= rhs.y
        lhs.z /= rhs.z
        lhs.w /= rhs.w
    }
    
    @inlinable var length: Element {
        return sqrt( (x * x) + (y * y) + (z * z) + (w * w) )
    }

    @inlinable var normalized: Vector4 {
        let f = 1 / self.length
        return self * f
    }
    @inlinable mutating func noramlize() {
        let f = 1 / self.length
        self *= f
    }
    
}


// MARK:- Free Functions

@inlinable public func dotProduct<T: Numeric>(_ a: Vector2<T>, _ b: Vector2<T>) -> T { return a • b }
@inlinable public func dotProduct<T: Numeric>(_ a: Vector3<T>, _ b: Vector3<T>) -> T { return a • b }
@inlinable public func dotProduct<T: Numeric>(_ a: Vector4<T>, _ b: Vector4<T>) -> T { return a • b }

@inlinable public func crossProduct<T: Numeric>(_ a: Vector3<T>, _ b: Vector3<T>) -> Vector3<T> { return a × b }
