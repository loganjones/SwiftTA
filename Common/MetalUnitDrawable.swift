//
//  MetalUnitDrawable.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/2/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Metal
import MetalKit
import simd


private typealias BufferIndex = UnitMetalRenderer_BufferIndex
private typealias TextureIndex = UnitMetalRenderer_TextureIndex
private typealias Uniforms = UnitMetalRenderer_ModelUniforms
private typealias Vertex = UnitMetalRenderer_ModelVertex
private typealias VertexAttributes = UnitMetalRenderer_ModelVertexAttribute


class MetalUnitDrawable {
    
    let device: MTLDevice
    
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private let maxBuffersInFlight: Int
    private var modelsTEMP: [UnitTypeId: UnitModel] = [:]
    private var models: [UnitTypeId: Model] = [:]
    
    struct FrameState {
        fileprivate let instances: [UnitTypeId: [Uniforms]]
        fileprivate init(_ instances: [UnitTypeId: [Uniforms]]) {
            self.instances = instances
        }
    }
    
    required init(_ device: MTLDevice, _ maxBuffersInFlight: Int) {
        self.device = device
        self.maxBuffersInFlight = maxBuffersInFlight
    }
    
    func configure(for metal: MetalHost) throws {
        
        let configurator = MetalVertexDescriptorConfigurator<VertexAttributes, BufferIndex>()
        configurator.setAttribute(.position, format: .float3, keyPath: \Vertex.position, bufferIndex: .modelVertices)
        configurator.setAttribute(.normal, format: .float3, keyPath: \Vertex.normal, bufferIndex: .modelVertices)
        configurator.setAttribute(.texcoord, format: .float2, keyPath: \Vertex.texCoord, bufferIndex: .modelVertices)
        configurator.setAttribute(.pieceIndex, format: .int, keyPath: \Vertex.pieceIndex, bufferIndex: .modelVertices)
        configurator.setLayout(.modelVertices, stride: MemoryLayout<Vertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        pipelineState = try metal.makeRenderPipelineState(
            named: "Model Pipeline",
            vertexDescriptor: configurator.vertexDescriptor,
            vertexFunctionName: "unitVertexShader",
            fragmentFunctionName: "unitFragmentShader")
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesciptor) else {
            throw MTLDeviceInitializationError.badDepthState
        }
        self.depthState = depthState
    }
    
    func load(_ units: [UnitTypeId: UnitData], sides: [SideInfo], filesystem: FileSystem) {
        let textures = ModelTexturePack(loadFrom: filesystem)
        models = units.mapValues { try! Model($0, device, textures, sides, filesystem) }
        modelsTEMP = units.mapValues { $0.model }
    }
    
    func setupNextFrame(_ viewState: GameViewState, _ commandBuffer: MTLCommandBuffer) -> FrameState {
        
        let projectionMatrix = matrix_float4x4.ortho(Rect4(size: viewState.viewport.size), -1024, 256)
        
        var instances: [UnitTypeId: [Uniforms]] = [:]
        let uniforms = UnsafeMutablePointer<Uniforms>.allocate(capacity: 1)
        defer { uniforms.deallocate() }
        let offset = MemoryLayout<Uniforms>.offset(of: \Uniforms.pieces) ?? 0
        let contents = UnsafeMutableRawPointer(uniforms)
        var transformations = UnsafeMutableBufferPointer(start: (contents + offset).bindMemory(to: matrix_float4x4.self, capacity: 40), count: 40)
        
        for case let .unit(unit) in viewState.objects {
            guard let model = modelsTEMP[unit.type] else { continue }
            
            let viewMatrix = matrix_float4x4.translation(xy: vector_float2(unit.position.xy - viewState.viewport.origin), z: 0) * matrix_float4x4.taPerspective
            
            uniforms.pointee.vpMatrix = projectionMatrix * viewMatrix
            uniforms.pointee.normalMatrix = matrix_float3x3(topLeftOf: viewMatrix).inverse.transpose
            MetalUnitDrawable.Instance.applyPieceTransformations(model: model, instance: unit.pose, transformations: &transformations)
            
            instances[unit.type, default: []].append(uniforms.move())
        }
        
        return FrameState(instances)
    }
    
    func drawFrame(_ frameState: FrameState, with renderEncoder: MTLRenderCommandEncoder) {
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        for (unitType, instances) in frameState.instances {
            guard let model = models[unitType] else { continue }
            renderEncoder.setFragmentTexture(model.texture, index: TextureIndex.color)
            renderEncoder.setVertexBuffer(model.buffer, offset: 0, index: BufferIndex.modelVertices)
            for uniforms in instances {
                var shadow = uniforms
                renderEncoder.setVertexBytes(&shadow, length: MemoryLayout<Uniforms>.size, index: BufferIndex.uniforms)
                renderEncoder.setFragmentBytes(&shadow, length: MemoryLayout<Uniforms>.size, index: BufferIndex.uniforms)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: model.vertexCount)
            }
        }
        
    }

}

// MARK:- Model

private extension MetalUnitDrawable {
    struct Model {
        var buffer: MTLBuffer
        var vertexCount: Int
        var texture: MTLTexture
    }
}

private extension MetalUnitDrawable.Model {
    
    init(_ unit: UnitData, _ device: MTLDevice, _ textures: ModelTexturePack, _ sides: [SideInfo], _ filesystem: FileSystem) throws {
        
        let palette = try Palette.texturePalette(for: unit.info, in: sides, from: filesystem)
        let atlas = UnitTextureAtlas(for: unit.model.textures, from: textures)
        let texture = try makeTexture(device, atlas, palette, filesystem)
        
        let vertexCount = countVertices(in: unit.model)
        let vertexSize = vertexCount * MemoryLayout<Vertex>.stride
        
        guard let buffer = device.makeBuffer(length: vertexSize, options: [.storageModeShared]) else {
            throw RuntimeError("MTLDevice makeBuffer failed")
        }
        buffer.label = "UnitModel"
        
        var p = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to: Vertex.self, capacity: vertexCount)
        collectVertexAttributes(pieceIndex: unit.model.root, model: unit.model, textures: atlas, vertexBuffer: &p)
        
        self.buffer = buffer
        self.vertexCount = vertexCount
        self.texture = texture
    }
    
}

private func countVertices(in model: UnitModel) -> Int {
    return model.primitives.reduce(0) {
        (count, primitive) in
        let num = primitive.indices.count
        return count + (num >= 3 ? (num - 2) * 3 : 0)
    }
}

private func collectVertexAttributes(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, textures: UnitTextureAtlas, vertexBuffer: inout UnsafeMutablePointer<Vertex>) {
    
    let piece = model.pieces[pieceIndex]
    
    for primitiveIndex in piece.primitives {
        guard primitiveIndex != model.groundPlate else { continue }
        collectVertexAttributes(primitive: model.primitives[primitiveIndex], pieceIndex: pieceIndex, model: model, textures: textures, vertexBuffer: &vertexBuffer)
    }
    
    for child in piece.children {
        collectVertexAttributes(pieceIndex: child, model: model, textures: textures, vertexBuffer: &vertexBuffer)
    }
}

private func collectVertexAttributes(primitive: UnitModel.Primitive, pieceIndex: UnitModel.Pieces.Index, model: UnitModel, textures: UnitTextureAtlas, vertexBuffer: inout UnsafeMutablePointer<Vertex>) {
    
    let vertices = primitive.indices.map({ vector_float3(model.vertices[$0]) })
    let texCoordsA = textures.textureCoordinates(for: primitive.texture)
    let texCoords = (vector_float2(texCoordsA.0), vector_float2(texCoordsA.1), vector_float2(texCoordsA.2), vector_float2(texCoordsA.3))
    
    switch vertices.count {
        
    case Int.min..<0: () // What?
    case 0: () // No Vertices
    case 1: () // A point?
    case 2: () // A line. Often used as a vector for sfx emitters
        
    case 3: // Single Triangle
        // Triangle 0,2,1
        let normal = makeNormal(0,2,1, in: vertices)
        append(&vertexBuffer,
               texCoords.0, vertices[0],
               texCoords.2, vertices[2],
               texCoords.1, vertices[1],
               normal, pieceIndex
        )
        
    case 4: // Single Quad, split into two triangles
        // Triangle 0,2,1
        let normal = makeNormal(0,2,1, in: vertices)
        append(&vertexBuffer,
               texCoords.0, vertices[0],
               texCoords.2, vertices[2],
               texCoords.1, vertices[1],
               normal, pieceIndex
        )
        // Triangle 0,3,2
        append(&vertexBuffer,
               texCoords.0, vertices[0],
               texCoords.3, vertices[3],
               texCoords.2, vertices[2],
               normal, pieceIndex
        )
        
    default: // Polygon with more than 4 sides
        let normal = makeNormal(0,2,1, in: vertices)
        for n in 2 ..< vertices.count {
            append(&vertexBuffer,
                   texCoords.0, vertices[0],
                   texCoords.2, vertices[n],
                   texCoords.1, vertices[n-1],
                   normal, pieceIndex
            )
        }
    }
}

private func makeNormal(_ a: Int, _ b: Int, _ c: Int, in vertices: [vector_float3]) -> vector_float3 {
    let v1 = vertices[a]
    let v2 = vertices[b]
    let v3 = vertices[c]
    let u = v2 - v1
    let v = v3 - v1
    return u × v
}

private func append(_ vertexBuffer: inout UnsafeMutablePointer<Vertex>,
                   _ texCoord1: vector_float2, _ vertex1: vector_float3,
                   _ texCoord2: vector_float2, _ vertex2: vector_float3,
                   _ texCoord3: vector_float2, _ vertex3: vector_float3,
                   _ normal: vector_float3,
                   _ pieceIndex: Int) {
    vertexBuffer[0].position = vertex1
    vertexBuffer[0].texCoord = texCoord1
    vertexBuffer[0].normal = normal
    vertexBuffer[0].pieceIndex = Int32(pieceIndex)
    vertexBuffer[1].position = vertex2
    vertexBuffer[1].texCoord = texCoord2
    vertexBuffer[1].normal = normal
    vertexBuffer[1].pieceIndex = Int32(pieceIndex)
    vertexBuffer[2].position = vertex3
    vertexBuffer[2].texCoord = texCoord3
    vertexBuffer[2].normal = normal
    vertexBuffer[2].pieceIndex = Int32(pieceIndex)
    vertexBuffer += 3
}

private func makeTexture(_ device: MTLDevice, _ textureAtlas: UnitTextureAtlas, _ palette: Palette, _ filesystem: FileSystem) throws -> MTLTexture {
    
    let data = textureAtlas.build(from: filesystem, using: palette)
    
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: textureAtlas.size.width, height: textureAtlas.size.height, mipmapped: false)
    guard let texture = device.makeTexture(descriptor: descriptor) else {
        throw RuntimeError("MTLDevice makeTexture failed")
    }
    
    data.withUnsafeBytes { (p: UnsafePointer<UInt8>) -> () in
        let r = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: textureAtlas.size.width, height: textureAtlas.size.height, depth: 1))
        texture.replace(region: r, mipmapLevel: 0, withBytes: p, bytesPerRow: textureAtlas.size.width * 4)
    }
    
    return texture
}

// MARK:- Instance

private extension MetalUnitDrawable {
    struct Instance {
        var uniformBuffer: MetalRingBuffer
    }
}

private extension MetalUnitDrawable.Instance {
    
    init(_ device: MTLDevice, _ maxBuffersInFlight: Int) {
        uniformBuffer = device.makeRingBuffer(length: MemoryLayout<Uniforms>.size, count: maxBuffersInFlight, options: [.storageModeShared])!
    }
    
    mutating func set(vpMatrix: matrix_float4x4, normalMatrix: matrix_float3x3, transformations modelInstance: UnitModel.Instance, for model: UnitModel) {
        
        let contents = uniformBuffer.next().contents
        let uniforms = contents.bindMemory(to: Uniforms.self, capacity: 1)
        uniforms.pointee.vpMatrix = vpMatrix
        uniforms.pointee.normalMatrix = normalMatrix
        
        let offset = MemoryLayout<Uniforms>.offset(of: \Uniforms.pieces) ?? 0
        var transformations = UnsafeMutableBufferPointer(start: (contents + offset).bindMemory(to: matrix_float4x4.self, capacity: modelInstance.pieces.count),
                                                         count: modelInstance.pieces.count)
        MetalUnitDrawable.Instance.applyPieceTransformations(model: model, instance: modelInstance, transformations: &transformations)
    }
    
    static func applyPieceTransformations<S>(model: UnitModel, instance: UnitModel.Instance, transformations: inout S)
        where S: MutableCollection, S.Element == matrix_float4x4, S.Index == Int
    {
        applyPieceTransformations(pieceIndex: model.root, p: matrix_float4x4.identity, model: model, instance: instance, transformations: &transformations)
    }
    
    static func applyPieceTransformations<S>(pieceIndex: UnitModel.Pieces.Index, p: matrix_float4x4, model: UnitModel, instance: UnitModel.Instance, transformations: inout S)
        where S: MutableCollection, S.Element == matrix_float4x4, S.Index == Int
    {
        let piece = model.pieces[pieceIndex]
        let anims = instance.pieces[pieceIndex]
        
        guard !anims.hidden else {
            applyPieceDiscard(pieceIndex: pieceIndex, model: model, transformations: &transformations)
            return
        }
        
        let offset = vector_float3(piece.offset)
        let move = vector_float3(anims.move)
        
        let deg2rad = GameFloat.pi / 180
        let sin = vector_float3( anims.turn.map { ($0 * deg2rad).sine } )
        let cos = vector_float3( anims.turn.map { ($0 * deg2rad).cosine } )
        
        let t = matrix_float4x4(columns: (
            vector_float4(
                cos.y * cos.z,
                (sin.y * cos.x) + (sin.x * cos.y * sin.z),
                (sin.x * sin.y) - (cos.x * cos.y * sin.z),
                0),
            
            vector_float4(
                -sin.y * cos.z,
                (cos.x * cos.y) - (sin.x * sin.y * sin.z),
                (sin.x * cos.y) + (cos.x * sin.y * sin.z),
                0),
            
            vector_float4(
                sin.z,
                -sin.x * cos.z,
                cos.x * cos.z,
                0),
            
            vector_float4(
                offset.x - move.x,
                offset.y - move.z,
                offset.z + move.y,
                1)
        ))
        
        let pt = p * t
        transformations[pieceIndex] = pt
        
        for child in piece.children {
            applyPieceTransformations(pieceIndex: child, p: pt, model: model, instance: instance, transformations: &transformations)
        }
    }
    
    static func applyPieceDiscard<S>(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, transformations: inout S)
        where S: MutableCollection, S.Element == matrix_float4x4, S.Index == Int
    {
        
        transformations[pieceIndex] = matrix_float4x4.translation(0, 0, -1000)
        
        let piece = model.pieces[pieceIndex]
        for child in piece.children {
            applyPieceDiscard(pieceIndex: child, model: model, transformations: &transformations)
        }
    }
    
}
