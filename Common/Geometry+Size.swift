//
//  Geometry+Size.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/16/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


public struct Size2<Element: Numeric> {
    public var values: (Element, Element)
    @inlinable public var width: Element  { get { return values.0 } set(s) { values.0 = s } }
    @inlinable public var height: Element { get { return values.1 } set(s) { values.1 = s } }
    @inlinable public init(values: (Element, Element)) { self.values = values }
}

public extension Size2 {
    
    @inlinable init(_ width: Element, _ height: Element) { self.init(values: (width, height)) }
    @inlinable init(width: Element, height: Element) { self.init(values: (width, height)) }
    @inlinable init(_ scalar: Element) { self.init(values: (scalar, scalar)) }
    @inlinable init() { self.init(0) }
    @inlinable init(_ copy: Size2) { self.init(values: copy.values) }
    
    @inlinable static var zero: Size2 { return Size2() }
    
    @inlinable var area: Element { return width * height }
    
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
    @inlinable public var min: Element { return Swift.min(width, height) }
    @inlinable public var max: Element { return Swift.max(width, height) }
}

extension Size2: Equatable {
    @inlinable public static func == (lhs: Size2, rhs: Size2) -> Bool { return lhs.values == rhs.values }
}
extension Size2: Hashable where Element: Hashable {
    @inlinable public func hash(into hasher: inout Hasher) { hasher.combine(width); hasher.combine(height) }
}

public extension Size2 {
    
    @inlinable static func + (lhs: Size2, rhs: Size2) -> Size2 {
        return Size2(values: (lhs.width + rhs.width, lhs.height + rhs.height ))
    }
    @inlinable static func += (lhs: inout Size2, rhs: Size2) {
        lhs.width += rhs.width
        lhs.height += rhs.height
    }
    
    @inlinable static func * (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: (lhs.values.0 * rhs, lhs.values.1 * rhs))
    }
    @inlinable static func *= (lhs: inout Size2, rhs: Element) {
        lhs.values.0 *= rhs
        lhs.values.1 *= rhs
    }
    
}

public extension Size2 where Element: BinaryInteger {
    
    @inlinable static func * <FPElement>(lhs: Size2, rhs: FPElement) -> Size2<FPElement> where FPElement: BinaryFloatingPoint {
        return Size2<FPElement>(values: (FPElement(lhs.values.0) * rhs, FPElement(lhs.values.1) * rhs))
    }
    
    @inlinable static func / (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: (lhs.values.0 / rhs, lhs.values.1 / rhs))
    }
    @inlinable static func /= (lhs: inout Size2, rhs: Element) {
        lhs.values.0 /= rhs
        lhs.values.1 /= rhs
    }
    
    @inlinable static func % (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: (lhs.values.0 % rhs, lhs.values.1 % rhs))
    }
    @inlinable static func %= (lhs: inout Size2, rhs: Element) {
        lhs.values.0 %= rhs
        lhs.values.1 %= rhs
    }
    
    @inlinable static func / (lhs: Size2, rhs: Size2) -> Size2 {
        return Size2(values: (lhs.values.0 / rhs.values.0, lhs.values.1 / rhs.values.1))
    }
    @inlinable static func /= (lhs: inout Size2, rhs: Size2) {
        lhs.values.0 /= rhs.values.0
        lhs.values.1 /= rhs.values.1
    }
    
}

public extension Size2 where Element: FloatingPoint {
    
    @inlinable static func / (lhs: Size2, rhs: Element) -> Size2 {
        return Size2(values: (lhs.values.0 / rhs, lhs.values.1 / rhs))
    }
    @inlinable static func /= (lhs: inout Size2, rhs: Element) {
        lhs.values.0 /= rhs
        lhs.values.1 /= rhs
    }
    
    @inlinable static func / (lhs: Size2, rhs: Size2) -> Size2 {
        return Size2(values: (lhs.values.0 / rhs.values.0, lhs.values.1 / rhs.values.1))
    }
    @inlinable static func /= (lhs: inout Size2, rhs: Size2) {
        lhs.values.0 /= rhs.values.0
        lhs.values.1 /= rhs.values.1
    }
    
}
