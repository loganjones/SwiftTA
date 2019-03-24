//
//  MetalFeatureDrawable.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 9/25/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Metal
import MetalKit
import simd


private typealias BufferIndex = MetalMapViewRenderer_BufferIndex
private typealias TextureIndex = MetalMapViewRenderer_TextureIndex
private typealias Uniforms = MetalMapViewRenderer_FeatureUniforms
private typealias Vertex = MetalMapViewRenderer_FeatureQuadVertex
private typealias VertexAttributes = MetalMapViewRenderer_FeatureQuadVertexAttribute


class MetalFeatureDrawable {
    
    let device: MTLDevice
    
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private var uniformBuffer: MetalRingBuffer
    private var features: [Feature] = []
    private var shadows: [Feature] = []
    
    required init(_ device: MTLDevice, _ maxBuffersInFlight: Int) {
        self.device = device
        
        uniformBuffer = device.makeRingBuffer(length: MemoryLayout<Uniforms>.size, count: maxBuffersInFlight, options: [.storageModeShared])!
    }
    
    func configure(for metal: MetalHost) throws {
        
        let configurator = MetalVertexDescriptorConfigurator<VertexAttributes, BufferIndex>()
        configurator.setAttribute(.position, format: .float3, keyPath: \Vertex.position, bufferIndex: .vertices)
        configurator.setAttribute(.texcoord, format: .float2, keyPath: \Vertex.texCoord, bufferIndex: .vertices)
        configurator.setLayout(.vertices, stride: MemoryLayout<Vertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        pipelineState = try metal.makeRenderPipelineState(
            named: "Feature Pipeline",
            vertexDescriptor: configurator.vertexDescriptor,
            vertexFunctionName: "featureQuadVertexShader",
            fragmentFunctionName: "featureQuadFragmentShader",
            blendingEnabled: true)
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesciptor) else {
            throw MTLDeviceInitializationError.badDepthState
        }
        self.depthState = depthState
    }
    
    func load(_ features: MapFeatureInfo.FeatureInfoCollection, containedIn map: MapModel, filesystem: FileSystem) {
        let loaded = loadFeatures(features, andInstancesFrom: map, filesystem: filesystem)
        self.features = loaded.features
        self.shadows = loaded.shadows
    }
    
    func setupNextFrame(_ viewState: GameViewState, _ commandBuffer: MTLCommandBuffer) {
        
        let modelMatrix = matrix_float4x4.identity
        let viewMatrix = matrix_float4x4.translation(xy: -vector_float2(viewState.viewport.origin), z: 0)
        let projectionMatrix = matrix_float4x4.ortho(Rect4(size: viewState.viewport.size), -1024, 256)
        
        let uniforms = uniformBuffer.next().contents.bindMemory(to: Uniforms.self, capacity: 1)
        uniforms.pointee.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
    }
    
    func drawFrame(with renderEncoder: MTLRenderCommandEncoder) {
        let features = self.features
        let shadows = self.shadows
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(uniformBuffer, index: BufferIndex.uniforms)
        renderEncoder.setFragmentBuffer(uniformBuffer, index: BufferIndex.uniforms)
        
        for type in features {
            switch type {
            case .static(let feature):
                renderEncoder.setFragmentTexture(feature.texture, index: TextureIndex.color)
                renderEncoder.setVertexBuffer(feature.instances, offset: 0, index: BufferIndex.vertices)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: feature.instancesVertexCount)
            case .animated(_):
                ()
            }
        }
        
        for type in shadows {
            switch type {
            case .static(let feature):
                renderEncoder.setFragmentTexture(feature.texture, index: TextureIndex.color)
                renderEncoder.setVertexBuffer(feature.instances, offset: 0, index: BufferIndex.vertices)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: feature.instancesVertexCount)
            case .animated(_):
                ()
            }
        }
    }
    
}

private extension MetalFeatureDrawable {
    
    enum Feature {
        case `static`(StaticFeature)
        case animated(AnimatedFeature)
    }
    
    struct StaticFeature {
        var texture: MTLTexture
        var instances: MTLBuffer
        var instancesVertexCount: Int
    }
    
    struct AnimatedFeature {
        var texture: MTLTexture
        var frames: Frame
        typealias Frame = (slice: Int, offset: Point2<Int>)
    }
    
    func loadFeatures(_ featureInfo: MapFeatureInfo.FeatureInfoCollection, andInstancesFrom map: MapModel, filesystem: FileSystem) -> (features: [Feature], shadows: [Feature]) {
        
        let palettes = MapFeatureInfo.loadFeaturePalettes(featureInfo, from: filesystem)
        let occurrences = groupFeatureOccurrences(map.featureMap)
        
        var features: [Feature] = []
        var shadows: [Feature] = []
        features.reserveCapacity(featureInfo.count)
        shadows.reserveCapacity(featureInfo.count/2)
        
        let shadowPalette = Palette.shadow
        
        MapFeatureInfo.collateFeatureGafItems(featureInfo, from: filesystem) {
            (name, info, item, gafHandle, gafListing) in
            
            guard let featureIndex = map.features.firstIndex(of: name) else { return }//.firstIndex(of: name) else { return }
            guard let occurrences = occurrences[featureIndex], !occurrences.isEmpty else { return }
            guard let gafFrames = try? item.extractFrames(from: gafHandle) else { return }
            guard let palette = palettes[info.world ?? ""] else { return }
            
            if gafFrames.count == 1 {
                if let texture = try? makeTexture(for: gafFrames[0], using: palette),
                    let instances = buildInstances(of: (texture.size2D, gafFrames[0].offset, info.footprint), from: occurrences, in: map)
                {
                    features.append(.static(StaticFeature(texture: texture, instances: instances.0, instancesVertexCount: instances.1)))
                }
                
                if let shadowName = info.shadowGafItemName,
                    let shadowItem = gafListing[shadowName],
                    let shadowFrame = try? shadowItem.extractFrame(index: 0, from: gafHandle),
                    let shadowTexture = try? makeTexture(for: shadowFrame, using: shadowPalette),
                    let shadowInstances = buildInstances(of: (shadowTexture.size2D, shadowFrame.offset, info.footprint), from: occurrences, in: map)
                {
                    shadows.append(.static(StaticFeature(texture: shadowTexture, instances: shadowInstances.0, instancesVertexCount: shadowInstances.1)))
                }
            }
            else {
                // TEMP
                print("TODO: Support animated map feature \(name) (\(gafFrames.count) frames)")
                let texture = try! makeTexture(for: gafFrames[0], using: palette)
                let instances = buildInstances(of: (texture.size2D, gafFrames[0].offset, info.footprint), from: occurrences, in: map)!
                features.append(.static(StaticFeature(texture: texture, instances: instances.0, instancesVertexCount: instances.1)))
            }
        }
        
        return (features, shadows)
    }
    
    func makeTexture(for gafFrame: GafItem.Frame, using palette: Palette) throws -> MTLTexture {
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: gafFrame.size.width, height: gafFrame.size.height, mipmapped: false)
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TextureError.badTextureDescriptor
        }
        
        let image = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: gafFrame.size.area * 4)
        defer { image.deallocate() }
        gafFrame.data.withUnsafeBytes() {
            (source: UnsafePointer<UInt8>) in
            for sourceIndex in 0..<gafFrame.size.area {
                let destinationIndex = sourceIndex * 4
                let colorIndex = Int(source[sourceIndex])
                image[destinationIndex+0] = palette[colorIndex].red
                image[destinationIndex+1] = palette[colorIndex].green
                image[destinationIndex+2] = palette[colorIndex].blue
                image[destinationIndex+3] = palette[colorIndex].alpha
            }
        }
        
        let r = MTLRegion(origin: .zero, size: MTLSize(gafFrame.size, depth: 1))
        texture.replace(region: r, mipmapLevel: 0, withBytes: image.baseAddress!, bytesPerRow: gafFrame.size.width * 4)
        return texture
    }
    
    enum TextureError: Swift.Error {
        case badTextureDescriptor
    }
    
    func groupFeatureOccurrences(_ featureMap: [Int?]) -> [Int: [Int]] {
        var featureOccurrences: [Int: [Int]] = [:]
        
        for i in featureMap.indices {
            guard let featureIndex = featureMap[i] else { continue }
            featureOccurrences[featureIndex, default: []].append(i)
        }
        
        return featureOccurrences
    }
    
    func buildInstances(of feature: (size: Size2<Int>, offset: Point2<Int>, footprint: Size2<Int>), from occurrenceIndices: [Int], in map: MapModel) -> (MTLBuffer, Int)? {
        
        let vertexCount = occurrenceIndices.count * 6
        guard let vertexBuffer = device.makeBuffer(length: MemoryLayout<Vertex>.stride * vertexCount, options: [.storageModeShared]) else { return nil }
        var vertices = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: vertexCount)
        
        for i in occurrenceIndices {
            
            let boundingBox = map.worldPosition(ofMapIndex: i)
                .center(inFootprint: feature.footprint)
                .offset(by: feature.offset)
                .adjust(forHeight: map.heightMap.height(atMapIndex: i))
                .makeRect(size: Size2f(feature.size))
            
            createRect(boundingBox, in: vertices)
            vertices += 6
        }
        
        return (vertexBuffer, vertexCount)
    }
    
}

private extension MetalFeatureDrawable.Feature {
    
    var texture: MTLTexture {
        switch self {
        case .static(let f): return f.texture
        case .animated(let f): return f.texture
        }
    }
    
    var size: Size2<Int> {
        switch self {
        case .static(let f):
            return f.texture.size2D
        case .animated(let f):
            return f.texture.size2D
        }
    }
    
}

private extension MapModel {
    func worldPosition(ofMapIndex index: Int) -> Point2<Int> {
        return Point2<Int>(index: index, stride: self.mapSize.width) * 16
    }
}
private extension Point2 where Element == Int {
    
    func center(inFootprint footprint: Size2<Int>) -> Point2<Int> {
        return self + Point2(footprint * 8)
    }
    
    func offset(by offset: Point2<Int>) -> Point2<Int> {
        return Point2(self - offset)
    }
    
    func adjust(forHeight height: Int) -> Point2f {
        var p = Point2f(self)
        p.y -= GameFloat(height) / 2.0
        return p
    }
    
}

private func createRect(_ rect: Rect4f, in vertices: UnsafeMutablePointer<Vertex>) {
    
    let x = Float(rect.origin.x)
    let y = Float(rect.origin.y)
    let z = Float(rect.maxY) / (32000.0 / 256.0)//Float(10)
    let w = Float(rect.size.width)
    let h = Float(rect.size.height)
    
    vertices[0].position = vector_float3(x+0, y+0, z)
    vertices[0].texCoord = vector_float2(0, 0)
    vertices[1].position = vector_float3(x+0, y+h, z)
    vertices[1].texCoord = vector_float2(0, 1)
    vertices[2].position = vector_float3(x+w, y+h, z)
    vertices[2].texCoord = vector_float2(1, 1)
    
    vertices[3].position = vector_float3(x+0, y+0, z)
    vertices[3].texCoord = vector_float2(0, 0)
    vertices[4].position = vector_float3(x+w, y+h, z)
    vertices[4].texCoord = vector_float2(1, 1)
    vertices[5].position = vector_float3(x+w, y+0, z)
    vertices[5].texCoord = vector_float2(1, 0)
}
