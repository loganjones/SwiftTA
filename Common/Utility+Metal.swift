//
//  CocoaUtility.swift
//  HPIView
//
//  Created by Logan Jones on 7/12/18.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Metal
import MetalKit


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
    
    init(xy: Vector2<Int>, z: Int = 0) {
        self.init(x: xy.x, y: xy.y, z: z)
    }
    
    static var zero: MTLOrigin { return MTLOrigin(x: 0, y: 0, z: 0) }
    
}

extension MTLSize {
    
    init(_ size: Size2<Int>, depth: Int = 1) {
        self.init(width: size.width, height: size.height, depth: depth)
    }
    
}

extension MTLRenderCommandEncoder {
    
    func setVertexBuffer<Index: RawRepresentable>(_ buffer: MTLBuffer?, offset: Int, index: Index) where Index.RawValue == Int {
        self.setVertexBuffer(buffer, offset: offset, index: index.rawValue)
    }
    func setVertexBytes<Index: RawRepresentable>(_ bytes: UnsafeRawPointer, length: Int, index: Index) where Index.RawValue == Int {
        self.setVertexBytes(bytes, length: length, index: index.rawValue)
    }
    func setFragmentBuffer<Index: RawRepresentable>(_ buffer: MTLBuffer?, offset: Int, index: Index) where Index.RawValue == Int {
        self.setFragmentBuffer(buffer, offset: offset, index: index.rawValue)
    }
    func setFragmentBytes<Index: RawRepresentable>(_ bytes: UnsafeRawPointer, length: Int, index: Index) where Index.RawValue == Int {
        self.setFragmentBytes(bytes, length: length, index: index.rawValue)
    }
    func setFragmentTexture<Index: RawRepresentable>(_ texture: MTLTexture?, index: Index) where Index.RawValue == Int {
        self.setFragmentTexture(texture, index: index.rawValue)
    }
    
}

extension MTLTexture {
    var size2D: Size2<Int> { return Size2<Int>(width, height) }
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
    
    func setAttribute<V>(_ va: VertexAttribute, format: MTLVertexFormat, keyPath: PartialKeyPath<V>, bufferIndex: BufferIndex) {
        guard let attr = vertexDescriptor.attributes[va.rawValue] else { return }
        attr.format = format
        attr.offset = MemoryLayout<V>.offset(of: keyPath) ?? 0
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
