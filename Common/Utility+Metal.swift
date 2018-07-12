//
//  CocoaUtility.swift
//  HPIView
//
//  Created by Logan Jones on 7/12/18.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Metal
import MetalKit
import simd


// MARK:- SIMD Type Extensions

extension vector_float4 {
    
    init(_ v: vector_float3, _ w: Float = 1) {
        self.init(v.x, v.y, v.z, w)
    }
    
    var xyz: vector_float3 { return vector_float3(x,y,z) }
    
    static var zero: vector_float4 { return vector_float4(0) }
    
}

extension vector_float3 {
    
    init(_ v: Vector3) {
        self.init(Float(v.x), Float(v.y), Float(v.z))
    }
    
    init(_ v: Vertex3) {
        self.init(Float(v.x), Float(v.y), Float(v.z))
    }
    
    static var zero: vector_float3 { return vector_float3(0) }
    
}

extension vector_float2 {
    
    init(_ v: Vector2) {
        self.init(Float(v.x), Float(v.y))
    }
    
    init(_ v: Vertex2) {
        self.init(Float(v.x), Float(v.y))
    }
    
    static var zero: vector_float2 { return vector_float2(0) }
    
}

func ×(lhs: vector_float3, rhs: vector_float3) -> vector_float3 {
    return simd_cross(lhs, rhs)
}

extension matrix_float4x4 {
    
    static var identity: matrix_float4x4 {
        return matrix_float4x4(columns: (vector_float4( 1, 0, 0, 0),
                                         vector_float4( 0, 1, 0, 0),
                                         vector_float4( 0, 0, 1, 0),
                                         vector_float4( 0, 0, 0, 1)))
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
    
    static func translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
        return matrix_float4x4(columns:(vector_float4(1, 0, 0, 0),
                                        vector_float4(0, 1, 0, 0),
                                        vector_float4(0, 0, 1, 0),
                                        vector_float4(translationX, translationY, translationZ, 1)))
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

extension matrix_float3x3 {
    
    init(topLeftOf m44: matrix_float4x4) {
        self.init(columns:(m44.columns.0.xyz,
                           m44.columns.1.xyz,
                           m44.columns.2.xyz))
    }
    
    static var identity: matrix_float3x3 {
        return matrix_float3x3(columns:(vector_float3( 1, 0, 0),
                                        vector_float3( 0, 1, 0),
                                        vector_float3( 0, 0, 1)))
    }
    
}


// MARK:- Convenience Functions

func alignSizeForMetalBuffer(_ size: Int) -> Int {
    return (size & ~0xFF) + 0x100
}


// MARK:- Convenience Types

struct MetalVertexDescriptorConfigurator<VertexAttribute, BufferIndex>
    where VertexAttribute: RawRepresentable, BufferIndex: RawRepresentable, VertexAttribute.RawValue == Int, BufferIndex.RawValue == Int
{
    let vertexDescriptor = MTLVertexDescriptor()
    
    func setAttribute(_ va: VertexAttribute, with configure: (MTLVertexAttributeDescriptor) -> ()) {
        guard let attr = vertexDescriptor.attributes[va.rawValue] else { return }
        configure(attr)
    }
    
    func setAttribute(_ va: VertexAttribute, format: MTLVertexFormat, offset: Int = 0, bufferIndex: BufferIndex) {
        guard let attr = vertexDescriptor.attributes[va.rawValue] else { return }
        attr.format = format
        attr.offset = offset
        attr.bufferIndex = bufferIndex.rawValue
    }
    
    func setLayout(_ bi: BufferIndex, with configure: (MTLVertexBufferLayoutDescriptor) -> ()) {
        guard let layout = vertexDescriptor.layouts[bi.rawValue] else { return }
        configure(layout)
    }
    
    func setLayout(_ bi: BufferIndex, stride: Int, stepRate: Int = 1, stepFunction: MTLVertexStepFunction = .perVertex) {
        guard let layout = vertexDescriptor.layouts[bi.rawValue] else { return }
        layout.stride = stride
        layout.stepRate = stepRate
        layout.stepFunction = stepFunction
    }
    
}
