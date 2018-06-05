//
//  MetalTiledTntDrawable.swift
//  HPIView
//
//  Created by Logan Jones on 8/1/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Metal
import MetalKit
import simd


private let screenTileSize = 512
private let maximumDisplaySize = Size2D(width: 4096, height: 4096)
private let maximumGridSize = maximumDisplaySize / screenTileSize
private let maxBuffersInFlight = 3

private typealias BufferIndex = MetalTntViewRenderer_BufferIndex
private typealias TextureIndex = MetalTntViewRenderer_TextureIndex
private typealias Uniforms = MetalTntViewRenderer_MapUniforms
private typealias Vertex = MetalTntViewRenderer_MapTileVertex
private typealias VertexAttributes = MetalTntViewRenderer_MapTileVertexAttribute


class MetalTiledTntDrawable: MetalTntDrawable {
    
    let device: MTLDevice
    
    private let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private var uniformBuffer: MetalRingBuffer
    
    private let vertexCount: Int
    private let vertexBuffer: MTLBuffer
    
    private var sliceBuffer: MetalRingBuffer
    private var indexBuffer: MetalRingBuffer
    private var indexCount: Int = 0
    
    private var mapResources: MapResources?
    private var lastTileGrid: Rect2D = .zero
    private var availableScreenTiles: [Int]
    private var activeScreenTiles: [Point2D: Int]
    
    fileprivate struct MapResources {
        var resolution: Size2D
        var gridBounds: Rect2D
        var tntSources: TntSources
        var screenTiles: MTLTexture
    }
    
    fileprivate enum TntSources {
        case ta(tileSet: TaTntTileSet, layout: TaMapModel.TileIndexMap)
        case tak(terrain: TakTntTerrainSet, layout: TakMapModel.TileIndexMap)
    }
    
    fileprivate struct TaTntTileSet {
        var textures: [MTLTexture]
    }
    
    fileprivate struct TakTntTerrainSet {
        var images: [UInt32: MTLTexture]
    }
    
    required init(_ device: MTLDevice) {
        self.device = device
        
        uniformBuffer = device.makeRingBuffer(length: MemoryLayout<Uniforms>.size, count: maxBuffersInFlight, options: [.storageModeShared])!
        
        // Each quad of the grid has 6 vertices (2 triangles)
        /*let */vertexCount = maximumGridSize.area * 6
        let alignedVerticesSize = alignSizeForMetalBuffer(MemoryLayout<Vertex>.stride * vertexCount)
        vertexBuffer = device.makeBuffer(length: alignedVerticesSize, options: [.storageModeShared])!
        prefillGridVertices(vertexBuffer, vertexCount, maximumGridSize, screenTileSize)
        
        sliceBuffer = device.makeRingBuffer(length: MemoryLayout<Int32>.stride * vertexCount, count: maxBuffersInFlight, options: [.storageModeShared])!
        indexBuffer = device.makeRingBuffer(length: MemoryLayout<UInt16>.stride * vertexCount, count: maxBuffersInFlight, options: [.storageModeShared])!
        
        availableScreenTiles = [Int](0..<maximumGridSize.area)
        activeScreenTiles = [:]
    }
    
    func load(_ map: TaMapModel, using palette: Palette) throws {
        mapResources = try MapResources(for: map, using: palette, device: device)
        lastTileGrid = .zero
        availableScreenTiles = [Int](0..<maximumGridSize.area)
        activeScreenTiles = [:]
    }
    
    func load(_ map: TakMapModel, from filesystem: FileSystem) throws {
        mapResources = try MapResources(for: map, from: filesystem, device: device)
        lastTileGrid = .zero
        availableScreenTiles = [Int](0..<maximumGridSize.area)
        activeScreenTiles = [:]
    }
    
}

extension MetalTiledTntDrawable {
    
    func configure(for metal: MetalHost) throws {
        
        metal.view.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metal.view.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metal.view.sampleCount = 1
        
        let vertexDescriptor = MetalTiledTntDrawable.buildVertexDescriptor()
        
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
        configurator.setLayout(.vertices, stride: MemoryLayout<Vertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
    func setupNextFrame(_ viewState: GameViewState, _ commandBuffer: MTLCommandBuffer) {
        guard let map = mapResources else { return }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler { _ in semaphore.signal() }
        
        let visibleTileGrid = computeTileGrid(for: viewState.viewport, boundedBy: map.gridBounds)
        
        let viewportSize = vector_float2(viewState.viewport.size)
        let viewportPosition = vector_float2(viewState.viewport.origin)
        let tileGridOffset = vector_float2(visibleTileGrid.origin * screenTileSize)
        
        let modelMatrix = matrix_float4x4.translation(xy: tileGridOffset)
        let viewMatrix = matrix_float4x4.translation(xy: -viewportPosition)
        let projectionMatrix = matrix_float4x4.ortho(0, viewportSize.x, viewportSize.y, 0, -1024, 256)
        
        let uniforms = uniformBuffer.next().contents.bindMemory(to: Uniforms.self, capacity: 1)
        uniforms.pointee.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        if visibleTileGrid != lastTileGrid {
            let last = lastTileGrid
            lastTileGrid = visibleTileGrid
            
            let offscreen = last.allPoints.subtracting(visibleTileGrid.allPoints)
            for tilePosition in offscreen {
                guard let slice = activeScreenTiles.removeValue(forKey: tilePosition) else { continue }
                availableScreenTiles.append(slice)
            }
            
            rebuildGrid(visibleTileGrid, for: map, using: commandBuffer)
        }
    }
    
    func drawFrame(with renderEncoder: MTLRenderCommandEncoder) {
        guard let map = mapResources else { return }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(uniformBuffer, index: BufferIndex.uniforms)
        renderEncoder.setFragmentBuffer(uniformBuffer, index: BufferIndex.uniforms)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: BufferIndex.vertices)
        renderEncoder.setVertexBuffer(sliceBuffer, index: BufferIndex.vertexTextureSlice)
        renderEncoder.setFragmentTexture(map.screenTiles, index: TextureIndex.color)
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint16, indexBuffer: indexBuffer)
    }
    
    enum TextureError: Swift.Error {
        case badTextureDescriptor
    }
    
    private func rebuildGrid(_ visibleTileGrid: Rect2D, for map: MapResources, using commandBuffer: MTLCommandBuffer) {
        
        let totalVertexCount = visibleTileGrid.size.area * 6
        let slices = sliceBuffer.next().contents.bindMemory(to: Int32.self, capacity: totalVertexCount)
        let indices = indexBuffer.next().contents.bindMemory(to: UInt16.self, capacity: totalVertexCount)
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        blitEncoder.label = "Map Blit Encoder"
        blitEncoder.pushDebugGroup("Blit Map")
        
        var rowVertexIndex = 0
        var indexIndex = 0
        
        for y in visibleTileGrid.heightRange {
            var vertexIndex = rowVertexIndex
            for x in visibleTileGrid.widthRange {
                let tilePosition = Point2D(x: x, y: y)
                let tileSliceIndex: Int
                
                if let slice = activeScreenTiles[tilePosition] {
                    tileSliceIndex = slice
                }
                else if let slice = availableScreenTiles.popLast() {
                    tileSliceIndex = slice
                    activeScreenTiles[tilePosition] = slice
                    switch map.tntSources {
                    case let .ta(tileSet, layout):
                        fillScreenTile(tilePosition, into: map.screenTiles, slice: tileSliceIndex, tileSet: tileSet, layout: layout, using: blitEncoder)
                    case let .tak(terrain, layout):
                        fillScreenTile(tilePosition, into: map.screenTiles, slice: tileSliceIndex, terrain: terrain, layout: layout, using: blitEncoder)
                    }
                }
                else {
                    tileSliceIndex = 0
                }
                
                let vslice = Int32(tileSliceIndex)
                for i in 0..<6 {
                    let vi = vertexIndex+i
                    let ii = indexIndex+i
                    slices[vi] = vslice
                    indices[ii] = UInt16(vi)
                }
                    
                vertexIndex += 6
                indexIndex += 6
            }
            rowVertexIndex += maximumGridSize.width * 6
        }
        
        blitEncoder.popDebugGroup()
        blitEncoder.endEncoding()
        
        indexCount = indexIndex
    }
    
    private func fillScreenTile(_ tilePosition: Point2D, into screenTexture: MTLTexture, slice screenSlice: Int, tileSet: TaTntTileSet, layout: TaMapModel.TileIndexMap, using blitEncoder: MTLBlitCommandEncoder) {
        
        let tileSize = layout.tileSize
        let tntRect = Rect2D(origin: (tilePosition * screenTileSize) / tileSize,
                             size: Size2D(width: screenTileSize/tileSize.width, height: screenTileSize/tileSize.height))
        
        layout.eachIndex(in: tntRect) {
            (index, column, row) in
            
            let patch = Point2D(x: (column - tntRect.origin.x) * tileSize.width,
                                y: (row - tntRect.origin.y) * tileSize.height)
            let t = tileSet.lookup(tileIndex: index)
            
            blitEncoder.copy(from: t.texture, sourceSlice: t.slice, sourceLevel: 0, sourceOrigin: .zero, sourceSize: MTLSize(tileSize),
                             to: screenTexture, destinationSlice: screenSlice, destinationLevel: 0, destinationOrigin: MTLOrigin(xy: patch))
        }
        
    }
    
    private func fillScreenTile(_ tilePosition: Point2D, into screenTexture: MTLTexture, slice screenSlice: Int, terrain: TakTntTerrainSet, layout: TakMapModel.TileIndexMap, using blitEncoder: MTLBlitCommandEncoder) {
        
        let tileSize = layout.tileSize
        let tntRect = Rect2D(origin: (tilePosition * screenTileSize) / tileSize,
                             size: Size2D(width: screenTileSize/tileSize.width, height: screenTileSize/tileSize.height))
        
        layout.eachTile(in: tntRect) {
            (imageName, imageColumn, imageRow, mapColumn, mapRow) in
            
            guard let texture = terrain[imageName] else { return }
            
            let terrainTilePosition = Point2D(x: imageColumn * tileSize.width,
                                              y: imageRow * tileSize.height)
            let screenTilePosition = Point2D(x: (mapColumn - tntRect.origin.x) * tileSize.width,
                                             y: (mapRow - tntRect.origin.y) * tileSize.height)
            
            blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(xy: terrainTilePosition), sourceSize: MTLSize(tileSize),
                             to: screenTexture, destinationSlice: screenSlice, destinationLevel: 0, destinationOrigin: MTLOrigin(xy: screenTilePosition))
        }
        
    }
    
}

private extension MetalTiledTntDrawable.MapResources {
    
    init(for map: TaMapModel, using palette: Palette, device: MTLDevice) throws {
        
        resolution = map.resolution
        gridBounds = Rect2D(size: map.resolution.map { $0.partitionCount(by: screenTileSize) })
    
        tntSources = .ta(tileSet: try MetalTiledTntDrawable.TaTntTileSet(device: device, tileSet: map.tileSet, palette: palette),
                         layout: map.tileIndexMap)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: screenTileSize, height: screenTileSize, mipmapped: false)
        descriptor.textureType = .type2DArray
        descriptor.arrayLength = maximumGridSize.area
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw LoadError.failedToMakeTexture
        }
        screenTiles = texture
    }
    
    init(for map: TakMapModel, from filesystem: FileSystem, device: MTLDevice) throws {
        
        resolution = map.resolution
        gridBounds = Rect2D(size: map.resolution.map { $0.partitionCount(by: screenTileSize) })
        
        tntSources = .tak(terrain: try MetalTiledTntDrawable.TakTntTerrainSet(device: device, terrain: map.tileIndexMap.uniqueNames, filesystem: filesystem),
                          layout: map.tileIndexMap)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: screenTileSize, height: screenTileSize, mipmapped: false)
        descriptor.textureType = .type2DArray
        descriptor.arrayLength = maximumGridSize.area
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw LoadError.failedToMakeTexture
        }
        screenTiles = texture
    }
    
    enum LoadError: Error {
        case failedToMakeTexture
    }
    
}

private extension MetalTiledTntDrawable.TaTntTileSet {
    
    static let tilesPerTexture = 2048
    private typealias `Self` = MetalTiledTntDrawable.TaTntTileSet
    
    init(device: MTLDevice, tileSet: TaMapModel.TileSet, palette: Palette) throws {
        
        textures = try Self.allocateTextures(device: device, tileCount: tileSet.count, tntTileSize: tileSet.tileSize)
        
        let tilePixelCount = tileSet.tileSize.area
        let tileBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: tilePixelCount * 4)
        defer { tileBuffer.deallocate() }
        
        tileSet.tiles.withUnsafeBytes() {
            (sourceTiles: UnsafePointer<UInt8>) in
            
            var textureIndex = 0
            var runningTileCount = 0
            var sourceIndex = 0
            
            let r = MTLRegion(origin: .zero, size: MTLSize(tileSet.tileSize, depth: 1))
            let tileStride = tileSet.tileSize.width * 4
            
            for _ in 0..<tileSet.count {
                
                var destinationIndex = 0
                
                for _ in 0..<tilePixelCount {
                    let colorIndex = Int(sourceTiles[sourceIndex])
                    tileBuffer[destinationIndex+0] = palette[colorIndex].blue
                    tileBuffer[destinationIndex+1] = palette[colorIndex].green
                    tileBuffer[destinationIndex+2] = palette[colorIndex].red
                    tileBuffer[destinationIndex+3] = 255
                    sourceIndex += 1
                    destinationIndex += 4
                }
                
                textures[textureIndex].replace(region: r, mipmapLevel: 0, slice: runningTileCount, withBytes: tileBuffer.baseAddress!, bytesPerRow: tileStride, bytesPerImage: 0)
                
                runningTileCount += 1
                if runningTileCount >= Self.tilesPerTexture {
                    runningTileCount = 0
                    textureIndex += 1
                }
            }
        }
    }
    
    func lookup(tileIndex: Int) -> (texture: MTLTexture, slice: Int) {
        let textureIndex = tileIndex / Self.tilesPerTexture
        let slice = tileIndex - (textureIndex * Self.tilesPerTexture)
        return (textures[textureIndex], slice)
    }
    
    private static func allocateTextures(device: MTLDevice, tileCount: Int, tntTileSize: Size2D) throws -> [MTLTexture] {
        return try tileCount
            .partitions(by: tilesPerTexture)
            .map { try allocateTexture(device: device, tileCount: $0, tntTileSize: tntTileSize) }
    }
    
    private static func allocateTexture(device: MTLDevice, tileCount: Int, tntTileSize: Size2D) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: tntTileSize.width, height: tntTileSize.height, mipmapped: false)
        descriptor.textureType = .type2DArray
        descriptor.arrayLength = tileCount
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw InitializationError.failedToMakeTexture
        }
        return texture
    }
    
    enum InitializationError: Error {
        case failedToMakeTexture
    }
    
}

private extension MetalTiledTntDrawable.TakTntTerrainSet {
    
    init(device: MTLDevice, terrain: Set<UInt32>, filesystem: FileSystem) throws {
        
        guard let terrrainDirectory = filesystem.root[directory: "terrain"]
            else { throw InitializationError.cantFindTerrainDirectory }
        
        images = [UInt32: MTLTexture]()
        images.reserveCapacity(terrain.count)
        
        let loader = MTKTextureLoader(device: device)
        
        for imageNumber in terrain {
            
            let filename = String(imageNumber, radix: 16).padLeft(with: "0", toLength: 8)
            guard let f = terrrainDirectory[file: "\(filename).jpg"], let file = try? filesystem.openFile(f)
                else { throw InitializationError.cantFindTerrainImage(imageNumber) }
            
            images[imageNumber] = try loader.newTexture(data: file.readDataToEndOfFile(), options: nil)
        }
        
    }
    
    subscript(index: UInt32) -> MTLTexture? {
        return images[index]
    }
    
    enum InitializationError: Error {
        case cantFindTerrainDirectory
        case cantFindTerrainImage(UInt32)
        case failedToMakeTexture
    }
    
}

private func prefillGridVertices(_ vertexBuffer: MTLBuffer, _ vertexCount: Int, _ tileCount: Size2D, _ tileSize: Int) {
    
    let v = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: vertexCount)
    var i = 0
    
    let w = Float(tileSize)
    let h = Float(tileSize)
    let z = Float(0)
    var y: Float = 0
    
    for _ in 0..<tileCount.height {
        var x: Float = 0
        for _ in 0..<tileCount.width {
            
            v[i+0].position = vector_float3(x+0, y+0, z)
            v[i+0].texCoord = vector_float2(0, 0)
            v[i+1].position = vector_float3(x+0, y+h, z)
            v[i+1].texCoord = vector_float2(0, 1)
            v[i+2].position = vector_float3(x+w, y+h, z)
            v[i+2].texCoord = vector_float2(1, 1)
            
            v[i+3].position = vector_float3(x+0, y+0, z)
            v[i+3].texCoord = vector_float2(0, 0)
            v[i+4].position = vector_float3(x+w, y+h, z)
            v[i+4].texCoord = vector_float2(1, 1)
            v[i+5].position = vector_float3(x+w, y+0, z)
            v[i+5].texCoord = vector_float2(1, 0)
            
            i += 6
            x += w
        }
        y += h
    }
}

private func computeTileGrid(for rect: CGRect, boundedBy bounds: Rect2D) -> Rect2D {
    return rect.computeGrid(division: CGFloat(screenTileSize)).clamp(within: bounds)
}

private extension CGRect {
    func computeGrid(division d: CGFloat) -> Rect2D {
        
        let minX = Int(floor(self.minX / d))
        let minY = Int(floor(self.minY / d))
        let maxX = Int(ceil(self.maxX / d))
        let maxY = Int(ceil(self.maxY / d))
        
        return Rect2D(origin: Point2D(x: minX, y: minY),
                      size: Size2D(width: maxX - minX, height: maxY - minY))
    }
}

private extension Rect2D {
    var allPoints: Set<Point2D> {
        let p = UnsafeMutableBufferPointer<Point2D>.allocate(capacity: size.area)
        defer { p.deallocate() }
        var i = 0
        for y in heightRange {
            for x in widthRange {
                p[i] = Point2D(x: x, y: y)
                i += 1
            }
        }
        return Set(p)
    }
}
