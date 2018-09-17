//
//  TntViewRenderer+MetalStaticGrid.swift
//  HPIView
//
//  Created by Logan Jones on 8/1/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Metal
import MetalKit
import simd


private typealias BufferIndex = MetalTntViewRenderer_BufferIndex
private typealias TextureIndex = MetalTntViewRenderer_TextureIndex
private typealias Uniforms = MetalTntViewRenderer_MapUniforms
private typealias Vertex = MetalTntViewRenderer_MapTileVertex
private typealias VertexAttributes = MetalTntViewRenderer_MapTileVertexAttribute


class StaticTextureSetMetalTntViewRenderer: MetalTntRenderer {
    
    let textureTileSize = 2048
    
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let uniformBuffer: MTLBuffer
    
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private var mapResources: MapResources?
    
    private struct MapResources {
        var tileCount: Size2D
        var texture: MTLTexture
        var vertices: MTLBuffer
        var slices: MTLBuffer
        var vertexCount: Int
    }
    
    required init(_ device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        let alignedTileUniformsSize = alignSizeForMetalBuffer(MemoryLayout<Uniforms>.size)
        uniformBuffer = device.makeBuffer(length: alignedTileUniformsSize, options:[.storageModeShared])!
    }
    
    func load(_ map: TaMapModel, using palette: Palette) throws {
        
        let mapSize = map.resolution
        let tileCount = mapSize.map { $0.partitionCount(by: textureTileSize) }
        
        let texture = try makeTexture(tiles: tileCount, for: map, using: palette)
        let (vertices, slices, vertexCount) = try makeGeometry(tiles: tileCount)
        
        mapResources = MapResources(tileCount: tileCount, texture: texture, vertices: vertices, slices: slices, vertexCount: vertexCount)
    }
    
    func load(_ map: TakMapModel, from filesystem: FileSystem) throws {
    }
    
}

extension StaticTextureSetMetalTntViewRenderer {
    
    func configure(for metal: MetalHost) throws {
        
        metal.view.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metal.view.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metal.view.sampleCount = 1
        
        let vertexDescriptor = StaticTextureSetMetalTntViewRenderer.buildVertexDescriptor()
        
        pipelineState = try metal.makeRenderPipelineState(
            named: "Map Pipeline",
            vertexDescriptor: vertexDescriptor,
            vertexFunctionName: "mapTileVertexShader",
            fragmentFunctionName: "mapTileFragmentShader")
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesciptor) else {
            throw MTLDeviceInitializationError.badDepthState
        }
        self.depthState = depthState
    }
    
    class func buildVertexDescriptor() -> MTLVertexDescriptor {
        let configurator = MetalVertexDescriptorConfigurator<VertexAttributes, BufferIndex>()
        
        configurator.setAttribute(.position, format: .float3, keyPath: \Vertex.position, bufferIndex: .vertices)
        configurator.setAttribute(.texcoord, format: .float2, keyPath: \Vertex.texCoord, bufferIndex: .vertices)
//        configurator.setAttribute(.slice, format: .int, keyPath: \Vertex.slice, bufferIndex: .vertices)
        configurator.setLayout(.vertices, stride: MemoryLayout<Vertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
    func setupNextFrame(_ viewState: MetalTntViewState, _ commandBuffer: MTLCommandBuffer) {
        
        let viewportSize = vector_float2(Float(viewState.viewport.size.width), Float(viewState.viewport.size.height))
        let viewportPosition = vector_float2(Float(viewState.viewport.origin.x), Float(viewState.viewport.origin.y))
        
        let modelMatrix = matrix_float4x4.identity
        let viewMatrix = matrix_float4x4.translation(-viewportPosition.x, -viewportPosition.y, 0)
        let projectionMatrix = matrix_float4x4.ortho(0, viewportSize.x, viewportSize.y, 0, -1024, 256)
        
        let uniforms = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniforms.pointee.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
    }
    
    func drawFrame(with renderEncoder: MTLRenderCommandEncoder) {
        guard let map = mapResources else { return }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: BufferIndex.uniforms)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: BufferIndex.uniforms)
        renderEncoder.setVertexBuffer(map.vertices, offset: 0, index: BufferIndex.vertices)
        renderEncoder.setFragmentTexture(map.texture, index: TextureIndex.color)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: map.vertexCount)
    }
    
    func makeTexture(tiles tileCount: Size2D, for map: TaMapModel, using palette: Palette) throws -> MTLTexture {
        let beginAll = Date()
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: textureTileSize, height: textureTileSize, mipmapped: false)
        descriptor.textureType = .type2DArray
        descriptor.arrayLength = tileCount.area
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TextureError.badTextureDescriptor
        }
        
        let beginConversion = Date()
        let tileBuffer = map.convertTiles(using: palette)
        defer { tileBuffer.deallocate() }
        let endConversion = Date()
        
        let beginTexture = Date()
        let tntTileSize = map.tileSet.tileSize
        var r = MTLRegion(origin: .zero, size: MTLSize(tntTileSize, depth: 1))
        let tileStride = tntTileSize.width * 4
        map.tileIndexMap.eachIndex(inColumns: 0 ..< map.tileIndexMap.size.width, rows: 0 ..< map.tileIndexMap.size.height) {
            (index, column, row) in
            let mapPosition = Point2D(x: column, y: row) * tntTileSize
            let tileXY = mapPosition / textureTileSize
            let tileIndex = tileXY.index(rowStride: tileCount.width)
            let tilePosition = tileXY * textureTileSize
            r.origin = MTLOrigin(xy: mapPosition - tilePosition)
            let tile = tileBuffer.baseAddress! + (index * tntTileSize.area * 4)
            texture.replace(region: r, mipmapLevel: 0, slice: tileIndex, withBytes: tile, bytesPerRow: tileStride, bytesPerImage: 0)
        }
        let endTexture = Date()
        
        let endAll = Date()
        let textureAllocatedSize: Int
        if #available(OSX 10.13, *) {
            textureAllocatedSize = texture.allocatedSize
        } else {
            textureAllocatedSize = tileCount.area * textureTileSize * textureTileSize * 4
        }
        print("""
            Tnt Render load time: \(endAll.timeIntervalSince(beginAll)) seconds
            Tile Buffer: \(tileBuffer.count) bytes
            Conversion: \(endConversion.timeIntervalSince(beginConversion)) seconds
            Texture: \(Size2D(width: texture.width, height: texture.height)) -> \(textureAllocatedSize) bytes
            Fill: \(endTexture.timeIntervalSince(beginTexture)) seconds
            """)
        print("map:\(map.resolution) -> tiles:\(tileCount)")
        
        return texture
    }
    
    enum TextureError: Swift.Error {
        case badTextureDescriptor
    }
    
    func makeGeometry(tiles tileCount: Size2D) throws -> (MTLBuffer, MTLBuffer, Int) {
        
        let vertexCount = tileCount.area * 6
        let alignedVerticesSize = alignSizeForMetalBuffer(MemoryLayout<Vertex>.stride * vertexCount)
        guard let vertexBuffer = device.makeBuffer(length: alignedVerticesSize, options:[.storageModeShared]) else {
            throw GeometryError.badBufferAttributes
        }
        let alignedSliceSize = alignSizeForMetalBuffer(MemoryLayout<Int32>.stride * vertexCount)
        guard let sliceBuffer = device.makeBuffer(length: alignedSliceSize, options:[.storageModeShared]) else {
            throw GeometryError.badBufferAttributes
        }
        
        let v = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: vertexCount)
        let vs = sliceBuffer.contents().bindMemory(to: Int32.self, capacity: vertexCount)
        var i = 0
        var s: Int32 = 0
        
        let w = Float(textureTileSize)
        let h = Float(textureTileSize)
        let z = Float(0)
        var y: Float = 0
        for _ in 0..<tileCount.height {
            var x: Float = 0
            for _ in 0..<tileCount.width {
                
                v[i+0].position = vector_float3(x+0, y+0, z)
                v[i+0].texCoord = vector_float2(0, 0)
                vs[i+0] = s
//                v[i+0].slice = s
                v[i+1].position = vector_float3(x+0, y+h, z)
                v[i+1].texCoord = vector_float2(0, 1)
                vs[i+1] = s
//                v[i+1].slice = s
                v[i+2].position = vector_float3(x+w, y+h, z)
                v[i+2].texCoord = vector_float2(1, 1)
                vs[i+2] = s
//                v[i+2].slice = s
                
                v[i+3].position = vector_float3(x+0, y+0, z)
                v[i+3].texCoord = vector_float2(0, 0)
                vs[i+3] = s
//                v[i+3].slice = s
                v[i+4].position = vector_float3(x+w, y+h, z)
                v[i+4].texCoord = vector_float2(1, 1)
                vs[i+4] = s
//                v[i+4].slice = s
                v[i+5].position = vector_float3(x+w, y+0, z)
                v[i+5].texCoord = vector_float2(1, 0)
                vs[i+5] = s
//                v[i+5].slice = s
                
                i += 6
                s += 1
                x += w
            }
            y += h
        }
        
        return (vertexBuffer, sliceBuffer, vertexCount)
    }
    
    enum GeometryError: Swift.Error {
        case badBufferAttributes
    }
    
}
