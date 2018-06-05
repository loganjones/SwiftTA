//
//  TntViewRenderer+MetalSingleQuad.swift
//  HPIView
//
//  Created by Logan Jones on 8/1/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Metal
import MetalKit
import simd


private let maxBuffersInFlight = 3

private typealias BufferIndex = MetalTntViewRenderer_BufferIndex
private typealias TextureIndex = MetalTntViewRenderer_TextureIndex
private typealias Uniforms = MetalTntViewRenderer_MapUniforms
private typealias Vertex = MetalTntViewRenderer_MapQuadVertex
private typealias VertexAttributes = MetalTntViewRenderer_MapQuadVertexAttribute


class MetalOneTextureTntDrawable: MetalTntDrawable {
    
    let device: MTLDevice
    
    private let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private var uniformBuffer: MetalRingBuffer
    private var quadBuffer: MetalRingBuffer
    private var texture: MTLTexture?
    
    required init(_ device: MTLDevice) {
        self.device = device
        
        uniformBuffer = device.makeRingBuffer(length: MemoryLayout<Uniforms>.size, count: maxBuffersInFlight, options: [.storageModeShared])!
        quadBuffer = device.makeRingBuffer(length: MemoryLayout<Vertex>.stride * 4, count: maxBuffersInFlight, options: [.storageModeShared])!
    }
    
    func load(_ map: TaMapModel, using palette: Palette) throws {
        let beginAll = Date()
        
        let mapSize = map.resolution
        let textureSize = mapSize//.map { Int(UInt32($0).nextPowerOfTwo) }
        let tntTileSize = map.tileSet.tileSize
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: textureSize.width, height: textureSize.height, mipmapped: false)
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TextureError.badTextureDescriptor
        }
        
        let beginConversion = Date()
        let tileBuffer = map.convertTiles(using: palette)
        defer { tileBuffer.deallocate() }
        let endConversion = Date()
        
        let beginTexture = Date()
        var r = MTLRegion(origin: .zero, size: MTLSize(tntTileSize, depth: 1))
        let tileStride = tntTileSize.width * 4
        map.tileIndexMap.eachIndex(inColumns: 0 ..< map.tileIndexMap.size.width, rows: 0 ..< map.tileIndexMap.size.height) {
            (index, column, row) in
            r.origin = MTLOrigin(x: column * tntTileSize.width, y: row * tntTileSize.height, z: 0)
            let tile = tileBuffer.baseAddress! + (index * tntTileSize.area * 4)
            texture.replace(region: r, mipmapLevel: 0, withBytes: tile, bytesPerRow: tileStride)
        }
        let endTexture = Date()
        
        self.texture = texture
        let endAll = Date()
        print("""
            Tnt Render load time: \(endAll.timeIntervalSince(beginAll)) seconds
              Tile Buffer: \(tileBuffer.count) bytes
              Conversion: \(endConversion.timeIntervalSince(beginConversion)) seconds
              Texture: \(textureSize) -> \(textureSize.area * 4) bytes
              Fill: \(endTexture.timeIntervalSince(beginTexture)) seconds
            """)
    }
    
    func load(_ map: TakMapModel, from filesystem: FileSystem) throws {
        //        let contentView = TakMapTileView(frame: NSRect(size: map.resolution))
        //        contentView.load(map, filesystem)
        //        contentView.drawFeatures = drawFeatures
        //        scrollView.documentView = contentView
    }
    
    enum TextureError: Swift.Error {
        case badTextureDescriptor
    }
    
}

extension MetalOneTextureTntDrawable {
    
    func configure(for metal: MetalHost) throws {
        
        metal.view.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metal.view.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metal.view.sampleCount = 1
        
        let vertexDescriptor = MetalOneTextureTntDrawable.buildVertexDescriptor()
        
        pipelineState = try metal.makeRenderPipelineState(
            named: "Map Pipeline",
            vertexDescriptor: vertexDescriptor,
            vertexFunctionName: "mapQuadVertexShader",
            fragmentFunctionName: "mapQuadFragmentShader")
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesciptor) else {
            throw MTLDeviceInitializationError.badDepthState
        }
        self.depthState = depthState
    }
    
    func setupNextFrame(_ viewState: GameViewState, _ commandBuffer: MTLCommandBuffer) {
        guard let texture = texture else { return }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler { _ in semaphore.signal() }
        
        let texteureSize = vector_float2(texture.size2D)
        let viewportSize = vector_float2(viewState.viewport.size)
        let (viewportPosition, quadOffset) = clamp(viewport: viewState.viewport, to: CGSize(texture.size2D))
        
        let modelMatrix = matrix_float4x4.identity
        let viewMatrix = matrix_float4x4.translation(xy: quadOffset)
        let projectionMatrix = matrix_float4x4.ortho(0, viewportSize.x, viewportSize.y, 0, -1024, 256)
        
        let uniforms = uniformBuffer.next().contents.bindMemory(to: Uniforms.self, capacity: 1)
        uniforms.pointee.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        let vx = viewportSize.x
        let vy = viewportSize.y
        let tx = viewportPosition.x / texteureSize.x
        let ty = viewportPosition.y / texteureSize.y
        let tw = viewportSize.x / texteureSize.x
        let th = viewportSize.y / texteureSize.y
        let p = quadBuffer.next().contents.bindMemory(to: Vertex.self, capacity: 4)
        p[0].position = vector_float3( 0,  0, 0); p[0].texCoord = vector_float2(tx, ty)
        p[1].position = vector_float3( 0, vy, 0); p[1].texCoord = vector_float2(tx, ty+th)
        p[2].position = vector_float3(vx,  0, 0); p[2].texCoord = vector_float2(tx+tw, ty)
        p[3].position = vector_float3(vx, vy, 0); p[3].texCoord = vector_float2(tx+tw, ty+th)
    }
    
    func drawFrame(with renderEncoder: MTLRenderCommandEncoder) {
        guard let texture = texture else { return }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(uniformBuffer, index: BufferIndex.uniforms)
        renderEncoder.setFragmentBuffer(uniformBuffer, index: BufferIndex.uniforms)
        renderEncoder.setVertexBuffer(quadBuffer, index: BufferIndex.vertices)
        renderEncoder.setFragmentTexture(texture, index: TextureIndex.color)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    class func buildVertexDescriptor() -> MTLVertexDescriptor {
        let configurator = MetalVertexDescriptorConfigurator<VertexAttributes, BufferIndex>()
        
        configurator.setAttribute(.position, format: .float3, keyPath: \Vertex.position, bufferIndex: .vertices)
        configurator.setAttribute(.texcoord, format: .float2, keyPath: \Vertex.texCoord, bufferIndex: .vertices)
        configurator.setLayout(.vertices, stride: MemoryLayout<Vertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
}

private func clamp(viewport: CGRect, to size: CGSize) -> (position: vector_float2, offset: vector_float2) {
    let positionX: Float
    let positionY: Float
    let offsetX: Float
    let offsetY: Float
    
    if viewport.minX < 0 { offsetX = Float(-viewport.minX); positionX = 0 }
    else if viewport.maxX > size.width { offsetX = Float(size.width - viewport.maxX); positionX = Float(size.width - viewport.size.width) }
    else { offsetX = 0; positionX = Float(viewport.minX) }
    
    if viewport.minY < 0 { offsetY = Float(-viewport.minY); positionY = 0 }
    else if viewport.maxY > size.height { offsetY = Float(size.height - viewport.maxY); positionY = Float(size.height - viewport.size.height) }
    else { offsetY = 0; positionY = Float(viewport.minY) }
    
    return (vector_float2(positionX, positionY), vector_float2(offsetX, offsetY))
}

private extension TaMapModel {
    
    func convertTiles(using palette: Palette) -> UnsafeBufferPointer<UInt8> {
        
        let tntTileSize = tileSet.tileSize
        let tileBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: tileSet.count * tntTileSize.area * 4)
        
        tileSet.tiles.withUnsafeBytes() {
            (sourceTiles: UnsafePointer<UInt8>) in
            let sourceCount = tntTileSize.area * tileSet.count
            for sourceIndex in 0..<sourceCount {
                let destinationIndex = sourceIndex * 4
                let colorIndex = Int(sourceTiles[sourceIndex])
                tileBuffer[destinationIndex+0] = palette[colorIndex].blue
                tileBuffer[destinationIndex+1] = palette[colorIndex].green
                tileBuffer[destinationIndex+2] = palette[colorIndex].red
                tileBuffer[destinationIndex+3] = 255
            }
        }
        
        return UnsafeBufferPointer(tileBuffer)
    }
    
}
