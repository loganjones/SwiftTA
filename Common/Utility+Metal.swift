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
    
    init(_ p: Point2D) {
        self.init(Float(p.x), Float(p.y))
    }
    
    init(_ v: Vector2) {
        self.init(Float(v.x), Float(v.y))
    }
    
    init(_ v: Vertex2) {
        self.init(Float(v.x), Float(v.y))
    }
    
    init(_ p: CGPoint) {
        self.init(Float(p.x), Float(p.y))
    }
    
    init(_ s: CGSize) {
        self.init(Float(s.width), Float(s.height))
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


// MARK:- MTLDevice Extensions

extension MTLDevice {
    
    var maximum2dTextureSize: Int {
        #if os(macOS)
        return 16384
        #elseif os(iOS)
        return 8192
        #elseif os(tvOS)
        guard self.supportsFeatureSet(.tvOS_GPUFamily2_v1) else { return 8192 }
        return 16384
        #else
        return 256
        #endif
    }
    
    func makeRenderPipelineState(named pipelineName: String = "RenderPipeline", library: MTLLibrary, view: MTKView, vertexDescriptor: MTLVertexDescriptor, vertexFunctionName: String, fragmentFunctionName: String, blendingEnabled: Bool = false) throws -> MTLRenderPipelineState {
        
        guard let vertexFunction = library.makeFunction(name: vertexFunctionName) else { throw MTLDeviceInitializationError.functionNotFound(vertexFunctionName) }
        guard let fragmentFunction = library.makeFunction(name: fragmentFunctionName) else { throw MTLDeviceInitializationError.functionNotFound(fragmentFunctionName) }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = pipelineName
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat
        
        if blendingEnabled, let renderbufferAttachment = pipelineDescriptor.colorAttachments[0] {
            renderbufferAttachment.isBlendingEnabled = true
            renderbufferAttachment.rgbBlendOperation = .add
            renderbufferAttachment.alphaBlendOperation = .add
            renderbufferAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderbufferAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderbufferAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderbufferAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        
        return try self.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
}

enum MTLDeviceInitializationError: Swift.Error {
    case noDefaultShaderLibrary
    case functionNotFound(String)
    case badDepthState
}


// MARK:- Convenience Extensions

extension MTLOrigin {
    
    init(xy: Point2D, z: Int = 0) {
        self.init(x: xy.x, y: xy.y, z: z)
    }
    
    static var zero: MTLOrigin { return MTLOrigin(x: 0, y: 0, z: 0) }
    
}

extension MTLSize {
    
    init(_ size: Size2D, depth: Int = 1) {
        self.init(width: size.width, height: size.height, depth: depth)
    }
    
}

extension MTLRenderCommandEncoder {
    
    func setVertexBuffer<Index: RawRepresentable>(_ buffer: MTLBuffer?, offset: Int, index: Index) where Index.RawValue == Int {
        self.setVertexBuffer(buffer, offset: offset, index: index.rawValue)
    }
    func setFragmentBuffer<Index: RawRepresentable>(_ buffer: MTLBuffer?, offset: Int, index: Index) where Index.RawValue == Int {
        self.setFragmentBuffer(buffer, offset: offset, index: index.rawValue)
    }
    func setFragmentTexture<Index: RawRepresentable>(_ texture: MTLTexture?, index: Index) where Index.RawValue == Int {
        self.setFragmentTexture(texture, index: index.rawValue)
    }
    
}

extension CGRect {
    
    init(origin: vector_float2, size: vector_float2) {
        self.init(x: CGFloat(origin.x), y: CGFloat(origin.y), width: CGFloat(size.x), height: CGFloat(size.y))
    }
    
}


// MARK:- Convenience Types

struct MetalHost {
    var view: MTKView
    var device: MTLDevice
    var library: MTLLibrary
}
extension MetalHost {
    func makeRenderPipelineState(named pipelineName: String = "RenderPipeline", vertexDescriptor: MTLVertexDescriptor, vertexFunctionName: String, fragmentFunctionName: String, blendingEnabled: Bool = false) throws -> MTLRenderPipelineState {
        return try device.makeRenderPipelineState(named: pipelineName, library: library, view: view, vertexDescriptor: vertexDescriptor, vertexFunctionName: vertexFunctionName, fragmentFunctionName: fragmentFunctionName, blendingEnabled: blendingEnabled)
    }
}

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

struct MetalRingBuffer {
    var buffer: MTLBuffer
    var length: Int
    var count: Int
    var offset: Int = 0
    var index: Int = 0
}

extension MetalRingBuffer {
    
    init?(length: Int, count: Int, options: MTLResourceOptions = [], device: MTLDevice) {
        let alignedLength = alignSizeForMetalBuffer(length)
        guard let buffer = device.makeBuffer(length: alignedLength * count, options: options) else { return nil }
        self.buffer = buffer
        self.length = alignedLength
        self.count = count
    }
    init?(alignedLength length: Int, count: Int, options: MTLResourceOptions = [], device: MTLDevice) {
        guard let buffer = device.makeBuffer(length: length * count, options: options) else { return nil }
        self.buffer = buffer
        self.length = length
        self.count = count
    }
    
    @discardableResult mutating func next() -> MetalRingBuffer {
        index = (index + 1) % count
        offset = length * index
        return self
    }
    
    var contents: UnsafeMutableRawPointer {
        return buffer.contents() + offset
    }
    
}
extension MTLDevice {
    func makeRingBuffer(length: Int, count: Int, options: MTLResourceOptions = []) -> MetalRingBuffer? {
        return MetalRingBuffer(length: length, count: count, options: options, device: self)
    }
    func makeRingBuffer(alignedLength length: Int, count: Int, options: MTLResourceOptions = []) -> MetalRingBuffer? {
        return MetalRingBuffer(alignedLength: length, count: count, options: options, device: self)
    }
}
extension MTLRenderCommandEncoder {
    
    func setVertexBuffer(_ buffer: MetalRingBuffer, index: Int) {
        self.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: index)
    }
    func setFragmentBuffer(_ buffer: MetalRingBuffer, index: Int) {
        self.setFragmentBuffer(buffer.buffer, offset: buffer.offset, index: index)
    }
    func setVertexBuffer<Index: RawRepresentable>(_ buffer: MetalRingBuffer, index: Index) where Index.RawValue == Int {
        self.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: index.rawValue)
    }
    func setFragmentBuffer<Index: RawRepresentable>(_ buffer: MetalRingBuffer, index: Index) where Index.RawValue == Int {
        self.setFragmentBuffer(buffer.buffer, offset: buffer.offset, index: index.rawValue)
    }
    
    func drawIndexedPrimitives(type primitiveType: MTLPrimitiveType, indexCount: Int, indexType: MTLIndexType, indexBuffer: MetalRingBuffer) {
        self.drawIndexedPrimitives(type: primitiveType, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBuffer.offset)
    }
    
}
extension MTLTexture {
    var size: Size2D { return Size2D(width, height) }
}
