//
//  Geometry+Rect.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/16/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


public struct Rect4<Element: SIMDScalar> {
    @usableFromInline internal var values: SIMD4<Element>
    @inlinable public var origin: Point2<Element>  { get { return Point2(values.x, values.y) } set(p) { values.x = p.x; values.y = p.y } }
    @inlinable public var size: Size2<Element>  { get { return Size2(values.z, values.w) } set(sz) { values.z = sz.width; values.w = sz.height } }
    @inlinable public init(values: SIMD4<Element>) { self.values = values }
    @inlinable public init(values: (Element, Element, Element, Element)) { self.values = SIMD4<Element>(values.0, values.1, values.2, values.3) }
}

public extension Rect4 {
    
    @inlinable init(_ x: Element, _ y: Element, _ width: Element, _ height: Element) { self.values = SIMD4<Element>(x, y, width, height) }
    @inlinable init(origin: Point2<Element> = .init(), size: Size2<Element>) { self.values = SIMD4<Element>(origin.x, origin.y, size.width, size.height) }
    @inlinable init(x: Element, y: Element, width: Element, height: Element) { self.values = SIMD4<Element>(x, y, width, height) }
    @inlinable init() { self.values = SIMD4<Element>() }
    @inlinable init(_ copy: Rect4) { self.values = copy.values }
    
    @inlinable static var zero: Rect4 { return Rect4() }
    
}

public extension Rect4 where Element: BinaryFloatingPoint {
    @inlinable init<OtherElement>(_ convert: Rect4<OtherElement>) where OtherElement: BinaryInteger {
        self.init(Element(convert.origin.x), Element(convert.origin.y), Element(convert.size.width), Element(convert.size.height))
    }
}
public extension Rect4 where Element: BinaryInteger {
    @inlinable init<OtherElement>(_ convert: Rect4<OtherElement>) where OtherElement: BinaryFloatingPoint {
        self.init(Element(convert.origin.x), Element(convert.origin.y), Element(convert.size.width), Element(convert.size.height))
    }
}

extension Rect4: CustomStringConvertible {
    @inlinable public var description: String { return "(origin: \(origin), size: \(size))" }
}

extension Rect4: Equatable {
    @inlinable public static func == (lhs: Rect4, rhs: Rect4) -> Bool { return lhs.values == rhs.values }
}
extension Rect4: Hashable where Element: Hashable {
    @inlinable public func hash(into hasher: inout Hasher) { hasher.combine(origin.x); hasher.combine(origin.y); hasher.combine(size.width); hasher.combine(size.height) }
}

public extension Rect4 where Element: SignedNumeric {
    
    @inlinable init(left: Element, top: Element, right: Element, bottom: Element) {
        self.init(left, top, right - left, bottom - top)
    }
    
    @inlinable var left: Element { return origin.x }
    @inlinable var right: Element { return origin.x + size.width }
    @inlinable var top: Element { return origin.y }
    @inlinable var bottom: Element { return origin.y + size.height }
    
    @inlinable var minX: Element { return origin.x }
    @inlinable var maxX: Element { return origin.x + size.width }
    @inlinable var minY: Element { return origin.y }
    @inlinable var maxY: Element { return origin.y + size.height }
    
}

public extension Rect4 where Element: SignedNumeric & Comparable {
    
    func clamp(within bounds: Rect4) -> Rect4 {
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
    
}

public extension Rect4 where Element: Strideable & SignedNumeric, Element.Stride: SignedInteger {
    @inlinable var widthRange: CountableRange<Element> { return minX..<maxX }
    @inlinable var heightRange: CountableRange<Element> { return minY..<maxY }
}

public extension Rect4 where Element: FixedWidthInteger  {
    
    @inlinable var area: Element { return size.area }
    
    @inlinable func insetBy(dx: Element, dy: Element) -> Rect4 {
        return Rect4(origin.x + dx,
                     origin.y + dy,
                     size.width - 2*dx,
                     size.height - 2*dy)
    }
    @inlinable func insetBy(_ ds: Element) -> Rect4 {
        return insetBy(dx: ds, dy: ds)
    }
    
    /// Returns `true` if the given point lies within the receiver's area.
    @inlinable
    func contains(_ point: Point2<Element>) -> Bool {
        let p = point &- origin
        return p.x >= 0 && p.y >= 0 && p.x < size.width && p.y < size.height
    }
    
}

public extension Rect4 where Element: FloatingPoint  {
    
    @inlinable var area: Element { return size.area }
    
    @inlinable func insetBy(dx: Element, dy: Element) -> Rect4 {
        return Rect4(origin.x + dx,
                     origin.y + dy,
                     size.width - 2*dx,
                     size.height - 2*dy)
    }
    @inlinable func insetBy(_ ds: Element) -> Rect4 {
        return insetBy(dx: ds, dy: ds)
    }
    
    /// Returns `true` if the given point lies within the receiver's area.
    @inlinable
    func contains(_ point: Point2<Element>) -> Bool {
        let p = point - origin
        return p.x >= 0 && p.y >= 0 && p.x < size.width && p.y < size.height
    }
    
}
