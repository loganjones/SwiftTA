//
//  Geometry+simd.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/11/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation
import simd


extension matrix_float3x3 {
    
    init(topLeftOf m44: matrix_float4x4) {
        self.init(columns:(m44.columns.0.xyz,
                           m44.columns.1.xyz,
                           m44.columns.2.xyz))
    }
    
    static var identity: matrix_float3x3 {
        return matrix_float3x3(1)
    }
    
}

extension matrix_float4x4 {
    
    init(_ matrix: Matrix4x4<Float>) {
        let m = matrix.m
        self.init(columns: (simd_float4( m.0,  m.1,  m.2,  m.3),
                            simd_float4( m.4,  m.5,  m.6,  m.7),
                            simd_float4( m.8,  m.9, m.10,  m.11),
                            simd_float4(m.12, m.13, m.14,  m.15)))
    }
    
    static var identity: matrix_float4x4 {
        return matrix_float4x4(1)
    }
    
    static var taPerspective: matrix_float4x4 {
        return matrix_float4x4(columns: (vector_float4(-1,   0,   0,   0),
                                         vector_float4( 0,   1,   0,   0),
                                         vector_float4( 0,-0.5,   1,   0),
                                         vector_float4( 0,   0,   0,   1)))
    }
    
    static func ortho(_ left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ nearZ: Float, _ farZ: Float) -> matrix_float4x4 {
        let xs = 2.0 / (right - left)
        let ys = 2.0 / (top - bottom)
        let zs = -2.0 / (farZ - nearZ)
        let tx = -( (right + left) / (right - left) )
        let ty = -( (top + bottom) / (top - bottom) )
        let tz = -( (farZ + nearZ) / (farZ - nearZ) )
        return matrix_float4x4(columns:(vector_float4(xs,  0,  0,  0),
                                        vector_float4( 0, ys,  0,  0),
                                        vector_float4( 0,  0, zs,  0),
                                        vector_float4(tx, ty, tz,  1)))
    }
    static func ortho(_ viewport: Rect4<Float>, _ nearZ: Float, _ farZ: Float) -> matrix_float4x4 {
        return ortho(viewport.left, viewport.right, viewport.bottom, viewport.top, nearZ, farZ)
    }
    
    static func translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
        return matrix_float4x4(columns:(vector_float4(1, 0, 0, 0),
                                        vector_float4(0, 1, 0, 0),
                                        vector_float4(0, 0, 1, 0),
                                        vector_float4(translationX, translationY, translationZ, 1)))
    }
    static func translation(_ v: vector_float3) -> matrix_float4x4 {
        return translation(v.x, v.y, v.z)
    }
    static func translation(xy v: vector_float2, z translationZ: Float = 0) -> matrix_float4x4 {
        return translation(v.x, v.y, translationZ)
    }
    
    static func translate(_ m: matrix_float4x4, _ v: vector_float3) -> matrix_float4x4 {
        let t = translation(v.x, v.y, v.z)
        return m * t
    }
    static func translate(_ m: matrix_float4x4, _ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
        let t = translation(translationX, translationY, translationZ)
        return m * t
    }
    
    static func rotation(radians: Float, axis: vector_float3) -> matrix_float4x4 {
        let unitAxis = normalize(axis)
        let ct = cosf(radians)
        let st = sinf(radians)
        let ci = 1 - ct
        let x = unitAxis.x
        let y = unitAxis.y
        let z = unitAxis.z
        return matrix_float4x4(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                        vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                        vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                        vector_float4(                  0,                   0,                   0, 1)))
    }
    
    static func rotate(_ m: matrix_float4x4, radians: Float, axis: vector_float3) -> matrix_float4x4 {
        let r = rotation(radians: radians, axis: axis)
        return m * r
    }
    
}

extension Matrix4x4 where Element == Float {
    
    init(_ matrix: matrix_float4x4) {
        let c = matrix.columns
        self.init(c.0.x, c.0.y, c.0.z, c.0.w,
                  c.1.x, c.1.y, c.1.z, c.1.w,
                  c.2.x, c.2.y, c.2.z, c.2.w,
                  c.3.x, c.3.y, c.3.z, c.3.w)
    }
    
}
