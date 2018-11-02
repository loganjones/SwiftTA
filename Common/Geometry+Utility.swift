//
//  Geometry+Utility.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/12/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


infix operator •: MultiplicationPrecedence
infix operator ×: MultiplicationPrecedence

public typealias Point2 = Vector2
public typealias Point3 = Vector3
public typealias Vertex2 = Vector2
public typealias Vertex3 = Vector3


// MARK:- Division Protocol

public protocol Division {
    static func / (lhs: Self, rhs: Self) -> Self
    static func /= (lhs: inout Self, rhs: Self)
}
extension Int: Division {}
extension Float: Division {}
extension Double: Division {}


// MARK:- cos & sin Protocol

public protocol TrigonometricFloatingPoint: FloatingPoint {
    var sine: Self { get }
    var cosine: Self { get }
    var arccosine: Self { get }
}
extension Float: TrigonometricFloatingPoint {
    @inlinable public var sine: Float { return sin(self) }
    @inlinable public var cosine: Float { return cos(self) }
    @inlinable public var arccosine: Float { return acos(self) }
}
extension Double: TrigonometricFloatingPoint {
    @inlinable public var sine: Double { return sin(self) }
    @inlinable public var cosine: Double { return cos(self) }
    @inlinable public var arccosine: Double { return acos(self) }
}


// MARK:- Vector Protocols

protocol Vector2Protocol {
    associatedtype Element: Numeric
    var x: Element { get set }
    var y: Element { get set }
    init(x: Element, y: Element)
}

extension Vector2Protocol {
    init<Other>(_ copy: Other) where Other: Vector2Protocol, Other.Element == Self.Element {
        self.init(x: copy.x, y: copy.y)
    }
}
extension Vector2Protocol where Element: BinaryFloatingPoint {
    init<Other>(_ convert: Other) where Other: Vector2Protocol, Other.Element: BinaryInteger {
        self.init(x: Element(convert.x), y: Element(convert.y))
    }
}
extension Vector2Protocol where Element: BinaryInteger {
    init<Other>(_ convert: Other) where Other: Vector2Protocol, Other.Element: BinaryFloatingPoint {
        self.init(x: Element(convert.x), y: Element(convert.y))
    }
}

protocol Vector3Protocol {
    associatedtype Element: Numeric
    var x: Element { get set }
    var y: Element { get set }
    var z: Element { get set }
    init(x: Element, y: Element, z: Element)
}

extension Vector3Protocol {
    init<Other>(_ copy: Other) where Other: Vector3Protocol, Other.Element == Self.Element {
        self.init(x: copy.x, y: copy.y, z: copy.z)
    }
}
extension Vector3Protocol where Element: BinaryFloatingPoint {
    init<Other>(_ convert: Other) where Other: Vector3Protocol, Other.Element: BinaryInteger {
        self.init(x: Element(convert.x), y: Element(convert.y), z: Element(convert.z))
    }
}
extension Vector3Protocol where Element: BinaryInteger {
    init<Other>(_ convert: Other) where Other: Vector3Protocol, Other.Element: BinaryFloatingPoint {
        self.init(x: Element(convert.x), y: Element(convert.y), z: Element(convert.z))
    }
}

protocol Vector4Protocol {
    associatedtype Element: Numeric
    var x: Element { get set }
    var y: Element { get set }
    var z: Element { get set }
    var w: Element { get set }
    init(x: Element, y: Element, z: Element, w: Element)
}

extension Vector4Protocol {
    init<Other>(_ copy: Other) where Other: Vector4Protocol, Other.Element == Self.Element {
        self.init(x: copy.x, y: copy.y, z: copy.z, w: copy.w)
    }
}
extension Vector4Protocol where Element: BinaryFloatingPoint {
    init<Other>(_ convert: Other) where Other: Vector4Protocol, Other.Element: BinaryInteger {
        self.init(x: Element(convert.x), y: Element(convert.y), z: Element(convert.z), w: Element(convert.w))
    }
}
extension Vector4Protocol where Element: BinaryInteger {
    init<Other>(_ convert: Other) where Other: Vector4Protocol, Other.Element: BinaryFloatingPoint {
        self.init(x: Element(convert.x), y: Element(convert.y), z: Element(convert.z), w: Element(convert.w))
    }
}

// Size

extension Vector2Protocol {
    init(_ size: Size2<Element>) {
        self.init(x: size.width, y: size.height)
    }
}
extension Vector2Protocol where Element: BinaryFloatingPoint {
    init<OtherElement>(_ convert: Size2<OtherElement>) where OtherElement: BinaryInteger {
        self.init(x: Element(convert.width), y: Element(convert.height))
    }
}
extension Vector2Protocol where Element: BinaryInteger {
    init<OtherElement>(_ convert: Size2<OtherElement>) where OtherElement: BinaryFloatingPoint {
        self.init(x: Element(convert.width), y: Element(convert.height))
    }
}


// MARK:- Utility Functions

/**
 Simple linear interpolation on a unit line.
 Where `s` is the unit distance from `f0` to `f1`.
 ```
 f0---(s)---f1
 ```
 - parameters:
     - f0: **Left** point value on the unit line.
     - f1: **Right** point value on the unit line.
     - s: Unit distance from left to right. Where 0 is full left, and 1 is full right.
 */
func linearInterpolation<N: FloatingPoint>(_ f0: N, _ f1: N, _ s: N) -> N {
    return (1 - s) * f0 + s * f1
}

/**
 Simple bilinear interpolation in a unit square.
 Where `x` is the unit distance from left to right
 and `y` is the unit distance from top to bottom.
 ```
 f00-----f10
  |       |
  | (x,y) |
  |       |
 f01-----f11
 ```
 - parameters:
    - f00: **Top Left** point value on the unit square.
    - f10: **Top Right** point value on the unit square.
    - f01: **Bottom Left** point value on the unit square.
    - f11: **Bottom Right** point value on the unit square.
    - x: Unit distance from left to right. Where 0 is full left, and 1 is full right.
    - y: Unit distance from top to bottom. Where 0 is full top, and 1 is full bottom.
 */
func bilinearInterpolation<N: FloatingPoint>(_ f00: N, _ f10: N, _ f01: N, _ f11: N, _ x: N, _ y: N) -> N {
    let a = f00 * (1 - x) * (1 - y)
    let b = f10 * x * (1 - y)
    let c = f01 * (1 - x) * y
    let d = f11 * x * y
    return a + b + c + d
}
