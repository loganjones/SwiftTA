//
//  Geometry+Size.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/16/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


public struct Size2<Element: SIMDScalar> {
    @usableFromInline internal var values: SIMD2<Element>
    @inlinable public var width: Element  { get { return values.x } set(s) { values.x = s } }
    @inlinable public var height: Element { get { return values.y } set(s) { values.y = s } }
    @inlinable public init(values: SIMD2<Element>) { self.values = values }
    @inlinable public init(values: (Element, Element)) { self.values = SIMD2(values.0, values.1) }
}

public extension Size2 {
    
    @inlinable init(_ width: Element, _ height: Element) { self.values = SIMD2(width, height) }
    @inlinable init(width: Element, height: Element) { self.values = SIMD2(width, height) }
    @inlinable init(_ scalar: Element) { self.values = SIMD2(scalar, scalar) }
    @inlinable init() { self.values = SIMD2() }
    @inlinable init(_ copy: Size2) { self.values = copy.values }
    
    @inlinable static var zero: Size2 { return Size2() }
    
    @inlinable func map(transform: (Element) throws -> Element) rethrows -> Size2 {
        return Size2(try transform(width), try transform(height))
    }
    @inlinable func map<OtherElement: Numeric>(transform: (Element) throws -> OtherElement) rethrows -> Size2<OtherElement> {
        return Size2<OtherElement>(try transform(width), try transform(height))
    }
    
}

public extension Size2 where Element: BinaryFloatingPoint {
    @inlinable init<OtherElement>(_ convert: Size2<OtherElement>) where OtherElement: BinaryInteger {
        self.init(Element(convert.width), Element(convert.height))
    }
}
public extension Size2 where Element: BinaryInteger {
    @inlinable init<OtherElement>(_ convert: Size2<OtherElement>) where OtherElement: BinaryFloatingPoint {
        self.init(Element(convert.width), Element(convert.height))
    }
}

extension Size2: CustomStringConvertible {
    @inlinable public var description: String { return "\(width)x\(height)" }
}

extension Size2 where Element: Comparable {
    @inlinable public func min() -> Element { return values.min() }
    @inlinable public func max() -> Element { return values.max() }
}

extension Size2: Equatable {
    @inlinable public static func == (lhs: Size2, rhs: Size2) -> Bool { return lhs.values == rhs.values }
}
extension Size2: Hashable where Element: Hashable {
    @inlinable public func hash(into hasher: inout Hasher) { hasher.combine(width); hasher.combine(height) }
}

public extension Size2 where Element: FixedWidthInteger {
    
    @inlinable var area: Element { return width * height }
    
    @inlinable static func + (lhs: Size2, rhs: Size2) -> Size2 {
        return Size2(values: lhs.values &+ rhs.values)
    }
    @inlinable static func += (lhs: inout Size2, rhs: Size2) {
        lhs.values &+= rhs.values
    }
    
    @inlinable static func * (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: lhs.values &* rhs)
    }
    @inlinable static func *= (lhs: inout Size2, rhs: Element) {
        lhs.values &*= rhs
    }
    
    @inlinable static func * <FPElement>(lhs: Size2, rhs: FPElement) -> Size2<FPElement> where FPElement: BinaryFloatingPoint {
        return Size2<FPElement>(lhs) * rhs
    }
    
    @inlinable static func / (lhs: Size2, rhs: Size2) -> Size2 {
        return Size2(values: lhs.values / rhs.values)
    }
    @inlinable static func /= (lhs: inout Size2, rhs: Size2) {
        lhs.values /= rhs.values
    }
    
    @inlinable static func / (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: lhs.values / rhs)
    }
    @inlinable static func /= (lhs: inout Size2, rhs: Element) {
        lhs.values /= rhs
    }
    
    @inlinable static func % (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: lhs.values % rhs)
    }
    @inlinable static func %= (lhs: inout Size2, rhs: Element) {
        lhs.values %= rhs
    }
    
}

public extension Size2 where Element: FloatingPoint {
    
    @inlinable var area: Element { return width * height }
    
    @inlinable static func + (lhs: Size2, rhs: Size2) -> Size2 {
        return Size2(values: lhs.values + rhs.values)
    }
    @inlinable static func += (lhs: inout Size2, rhs: Size2) {
        lhs.values += rhs.values
    }
    
    @inlinable static func * (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: lhs.values * rhs)
    }
    @inlinable static func *= (lhs: inout Size2, rhs: Element) {
        lhs.values *= rhs
    }
    
    @inlinable static func / (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: lhs.values / rhs)
    }
    @inlinable static func /= (lhs: inout Size2, rhs: Element) {
        lhs.values /= rhs
    }
    
    @inlinable static func / (lhs: Size2, rhs: Size2) -> Size2 {
        return Size2(values: lhs.values / rhs.values)
    }
    @inlinable static func /= (lhs: inout Size2, rhs: Size2) {
        lhs.values /= rhs.values
    }
    
}
