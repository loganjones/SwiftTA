//
//  Geometry+Matrix.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/15/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation
#if canImport(simd)
import simd
#endif


// MARK:- Matrix 3x3

public struct Matrix3x3<Element: Numeric> {
    public var m: (Element, Element, Element,
                   Element, Element, Element,
                   Element, Element, Element)
    @inlinable public init(m: (
        Element, Element, Element,
        Element, Element, Element,
        Element, Element, Element)) {
        self.m = m
    }
}

public extension Matrix3x3 {
    
    @inlinable init(_ m00: Element, _ m01: Element, _ m02: Element,
                    _ m10: Element, _ m11: Element, _ m12: Element,
                    _ m20: Element, _ m21: Element, _ m22: Element) {
        m = (m00, m01, m02,
             m10, m11, m12,
             m20, m21, m22)
    }
    
    @inlinable init(topLeftOf m44: Matrix4x4<Element>) {
        self.init(m: (m44.m.0, m44.m.1, m44.m.2,
                      m44.m.4, m44.m.5, m44.m.6,
                      m44.m.8, m44.m.9, m44.m.10))
    }
    
    @inlinable static var identity: Matrix3x3 {
        return Matrix3x3(m: (1, 0, 0,
                             0, 1, 0,
                             0, 0, 1))
    }
    
}

public extension Matrix3x3 where Element == Float {
    
    var inverseTranspose: Matrix3x3 {
        return Matrix3x3(m: makeInverseTranspose(of: self.m))
    }
    
}


// MARK:- Matrix 4x4

public struct Matrix4x4<Element: Numeric> {
    public var m: (Element, Element, Element, Element,
                   Element, Element, Element, Element,
                   Element, Element, Element, Element,
                   Element, Element, Element, Element)
    @inlinable public init(m: (
        Element, Element, Element, Element,
        Element, Element, Element, Element,
        Element, Element, Element, Element,
        Element, Element, Element, Element)) {
        self.m = m
    }
}

public extension Matrix4x4 {
    
    @inlinable init(_ m00: Element, _ m01: Element, _ m02: Element, _ m03: Element,
                    _ m10: Element, _ m11: Element, _ m12: Element, _ m13: Element,
                    _ m20: Element, _ m21: Element, _ m22: Element, _ m23: Element,
                    _ m30: Element, _ m31: Element, _ m32: Element, _ m33: Element) {
        m = (m00, m01, m02, m03,
             m10, m11, m12, m13,
             m20, m21, m22, m23,
             m30, m31, m32, m33)
    }
    
    @inlinable static var identity: Matrix4x4 {
        return Matrix4x4(m: (1, 0, 0, 0,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 1))
    }
    
    @inlinable static func translation(_ x: Element, _ y: Element, _ z: Element) -> Matrix4x4 {
        return Matrix4x4(m: (1, 0, 0, 0,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             x, y, z, 1))
    }
    @inlinable static func translation(_ v: Vector3<Element>) -> Matrix4x4 {
        return Matrix4x4(m: (1, 0, 0, 0,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             v.x, v.y, v.z, 1))
    }
    @inlinable static func translation(_ v: Vector2<Element>, _ z: Element = 0) -> Matrix4x4 {
        return Matrix4x4(m: (1, 0, 0, 0,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             v.x, v.y, z, 1))
    }
    
}

public extension Matrix4x4 where Element: TrigonometricFloatingPoint {
    
    @inlinable static func rotation(radians: Element, axis: Vector3<Element>) -> Matrix4x4 {
        let unitAxis = axis.normalized
        let ct = radians.cosine
        let st = radians.sine
        let ci = 1 - ct
        let x = unitAxis.x
        let y = unitAxis.y
        let z = unitAxis.z
        return Matrix4x4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0,
                         x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0,
                         x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0,
                                           0,                   0,                   0, 1)
    }
    
}

public extension Matrix4x4 where Element == Float {
    static func * (lhs: Matrix4x4, rhs: Matrix4x4) -> Matrix4x4 {
        #if canImport(simd)
        return Matrix4x4( matrix_float4x4(lhs) * matrix_float4x4(rhs) )
        #else
        return Matrix4x4(m: multMatrix4x4(lhs.m, rhs.m))
        #endif
    }
}

public extension Matrix4x4 where Element: BinaryFloatingPoint {
    @inlinable static var taPerspective: Matrix4x4 {
        let s: Element = 0.5
        return Matrix4x4(m: (-1,   0,   0,   0,
                             0,   1,   0,   0,
                             0,  -s,   1,   0,
                             0,   0,   0,   1))
    }
}

public extension Matrix4x4 where Element: Division & SignedNumeric {
    
    @inlinable static func ortho(_ left: Element, _ right: Element, _ bottom: Element, _ top: Element, _ nearZ: Element, _ farZ: Element) -> Matrix4x4 {
        
        let two: Element = 2
        let ral = right + left
        let rsl = right - left
        let tab = top + bottom
        let tsb = top - bottom
        let fan = farZ + nearZ
        let fsn = farZ - nearZ
        
        return Matrix4x4(
             two / rsl,          0,          0,          0,
                     0,  two / tsb,          0,          0,
                     0,          0, -two / fsn,          0,
            -ral / rsl, -tab / tsb, -fan / fsn,          1)
    }
    
    @inlinable static func ortho(_ viewport: Rect4<Element>, _ nearZ: Element, _ farZ: Element) -> Matrix4x4 {
        return ortho(viewport.left, viewport.right, viewport.bottom, viewport.top, nearZ, farZ)
    }
    
}


// MARK:- Compiler Workarounds

private typealias m33FloatTuple = (
    Float, Float, Float,
    Float, Float, Float,
    Float, Float, Float
)
private typealias m44FloatTuple = (
    Float, Float, Float, Float,
    Float, Float, Float, Float,
    Float, Float, Float, Float,
    Float, Float, Float, Float
)

private func makeInverseTranspose(of m: m33FloatTuple) -> m33FloatTuple {
    let d =   m.0 * (m.4 * m.8 - m.7 * m.5)
            - m.1 * (m.3 * m.8 - m.5 * m.6)
            + m.2 * (m.3 * m.7 - m.4 * m.6)
    let i = 1.0 / d
    
    return (
         (m.4 * m.8 - m.7 * m.5) * i,
        -(m.3 * m.8 - m.5 * m.6) * i,
         (m.3 * m.7 - m.6 * m.4) * i,
        
        -(m.1 * m.8 - m.2 * m.7) * i,
         (m.0 * m.8 - m.2 * m.6) * i,
        -(m.0 * m.7 - m.6 * m.1) * i,
        
         (m.1 * m.5 - m.2 * m.4) * i,
        -(m.0 * m.5 - m.3 * m.2) * i,
         (m.0 * m.4 - m.3 * m.1) * i)
    }

private func multMatrix4x4(_ lhs: m44FloatTuple, _ rhs: m44FloatTuple) -> m44FloatTuple {
    return (
        lhs.0 * rhs.0  + lhs.4 * rhs.1  + lhs.8 * rhs.2   + lhs.12 * rhs.3,
        lhs.1 * rhs.0  + lhs.5 * rhs.1  + lhs.9 * rhs.2   + lhs.13 * rhs.3,
        lhs.2 * rhs.0  + lhs.6 * rhs.1  + lhs.10 * rhs.2  + lhs.14 * rhs.3,
        lhs.3 * rhs.0  + lhs.7 * rhs.1  + lhs.11 * rhs.2  + lhs.15 * rhs.3,
        
        lhs.0 * rhs.4  + lhs.4 * rhs.5  + lhs.8 * rhs.6   + lhs.12 * rhs.7,
        lhs.1 * rhs.4  + lhs.5 * rhs.5  + lhs.9 * rhs.6   + lhs.13 * rhs.7,
        lhs.2 * rhs.4  + lhs.6 * rhs.5  + lhs.10 * rhs.6  + lhs.14 * rhs.7,
        lhs.3 * rhs.4  + lhs.7 * rhs.5  + lhs.11 * rhs.6  + lhs.15 * rhs.7,
        
        lhs.0 * rhs.8  + lhs.4 * rhs.9  + lhs.8 * rhs.10  + lhs.12 * rhs.11,
        lhs.1 * rhs.8  + lhs.5 * rhs.9  + lhs.9 * rhs.10  + lhs.13 * rhs.11,
        lhs.2 * rhs.8  + lhs.6 * rhs.9  + lhs.10 * rhs.10 + lhs.14 * rhs.11,
        lhs.3 * rhs.8  + lhs.7 * rhs.9  + lhs.11 * rhs.10 + lhs.15 * rhs.11,
        
        lhs.0 * rhs.12 + lhs.4 * rhs.13 + lhs.8 * rhs.14  + lhs.12 * rhs.15,
        lhs.1 * rhs.12 + lhs.5 * rhs.13 + lhs.9 * rhs.14  + lhs.13 * rhs.15,
        lhs.2 * rhs.12 + lhs.6 * rhs.13 + lhs.10 * rhs.14 + lhs.14 * rhs.15,
        lhs.3 * rhs.12 + lhs.7 * rhs.13 + lhs.11 * rhs.14 + lhs.15 * rhs.15
    )
}
