//
//  ModelViewRenderer+Metal.swift
//  HPIView
//
//  Created by Logan Jones on 6/12/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Metal
import MetalKit
import simd


class ModelMetalBasicRenderer {
    
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let uniformBuffer: MTLBuffer
    private let modelUniformOffset: Int
    private let wireUniformOffset: Int
    private let gridUniformOffset: Int
    
    private var modelPipelineState: MTLRenderPipelineState!
    private var gridPipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private var model: MetalModel?
    private var grid: MetalGrid!
    
    private let taPerspective = matrix_float4x4(columns: (
        vector_float4(-1,   0,   0,   0),
        vector_float4( 0,   1,   0,   0),
        vector_float4( 0,-0.5,   1,   0),
        vector_float4( 0,   0,   0,   1)
        ))
    
    init(_ device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        let alignedModelUniformsSize = alignSizeForMetalBuffer(MemoryLayout<ModelMetalRenderer_ModelUniforms>.size)
        let alignedGridUniformsSize = alignSizeForMetalBuffer(MemoryLayout<ModelMetalRenderer_GridUniforms>.size)
        uniformBuffer = device.makeBuffer(length: alignedModelUniformsSize + alignedModelUniformsSize + alignedGridUniformsSize, options:[.storageModeShared])!
        modelUniformOffset = 0
        wireUniformOffset = alignedModelUniformsSize
        gridUniformOffset = alignedModelUniformsSize + alignedModelUniformsSize
    }
    
}

extension ModelMetalBasicRenderer: ModelMetalRenderer {
    
    func configure(view: MTKView) {
        
        view.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        view.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        view.sampleCount = 1
        
        do { try initializeState(in: view) }
        catch { print("Failed to initialize Metal state: \(error)") }
    }
    
    func drawFrame(in view: MTKView, _ viewState: ModelViewState) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer { commandBuffer.commit() }
        
        let modelMatrix = matrix_float4x4.identity
        let projection = matrix_float4x4.ortho(0, viewState.sceneSize.width, viewState.sceneSize.height, 0, -1024, 256)
        let sceneCentering = matrix_float4x4.translation(viewState.sceneSize.width / 2, viewState.sceneSize.height / 2, 0)
        let sceneView = matrix_float4x4.rotate(sceneCentering * taPerspective, radians: -viewState.rotateZ * (Float.pi / 180.0), axis: vector_float3(0, 0, 1))
        let gridView = matrix_float4x4.translate(sceneView, Float(-grid.size.width / 2), Float(-grid.size.height / 2), 0)
        let normal = matrix_float3x3(topLeftOf: sceneView).inverse.transpose
        
        let uniforms = UnsafeMutableRawPointer(uniformBuffer.contents() + modelUniformOffset).bindMemory(to:ModelMetalRenderer_ModelUniforms.self, capacity:1)
        uniforms.pointee.modelMatrix = modelMatrix
        uniforms.pointee.viewMatrix = sceneView
        uniforms.pointee.projectionMatrix = projection
        uniforms.pointee.normalMatrix = normal
        
        uniforms.pointee.lightPosition = vector_float3(50, 50, 100)
        uniforms.pointee.viewPosition = vector_float3(viewState.sceneSize.width / 2, viewState.sceneSize.height / 2, 0)
        uniforms.pointee.objectColor = vector_float4(0.95, 0.85, 0.80, 1)
        
        if viewState.drawMode == .wireframe || viewState.drawMode == .outlined {
            let wireUniformsR = UnsafeMutableRawPointer(uniformBuffer.contents() + wireUniformOffset)
            wireUniformsR.copyMemory(from: UnsafeRawPointer(uniformBuffer.contents() + modelUniformOffset), byteCount: MemoryLayout<ModelMetalRenderer_ModelUniforms>.stride)
            let wireUniforms = wireUniformsR.bindMemory(to:ModelMetalRenderer_ModelUniforms.self, capacity:1)
            wireUniforms.pointee.objectColor = vector_float4(0.4, 0.35, 0.3, 1)
        }
        
        let gridUniforms = (UnsafeMutableRawPointer(uniformBuffer.contents()) + gridUniformOffset).bindMemory(to:ModelMetalRenderer_GridUniforms.self, capacity:1)
        gridUniforms.pointee.gridMvpMatrix = projection * gridView * modelMatrix
        gridUniforms.pointee.gridColor = vector_float4(0.9, 0.9, 0.9, 1)
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "Model Render Encoder"
        renderEncoder.pushDebugGroup("Draw Model")
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(gridPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: gridUniformOffset, index: ModelMetalRenderer_BufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: gridUniformOffset, index: ModelMetalRenderer_BufferIndex.uniforms.rawValue)
        renderEncoder.setVertexBuffer(grid.buffer, offset: 0, index: ModelMetalRenderer_BufferIndex.gridVertices.rawValue)
        renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: grid.vertexCount)
        
        if let model = model {
            renderEncoder.setRenderPipelineState(modelPipelineState)
            renderEncoder.setDepthStencilState(depthState)
            renderEncoder.setVertexBuffer(model.buffer, offset: 0, index: ModelMetalRenderer_BufferIndex.modelVertices.rawValue)
            if viewState.drawMode == .solid || viewState.drawMode == .outlined {
                if viewState.drawMode == .outlined { renderEncoder.setDepthBias(-10, slopeScale: 1, clamp: -10) }
                renderEncoder.setVertexBuffer(uniformBuffer, offset: modelUniformOffset, index: ModelMetalRenderer_BufferIndex.uniforms.rawValue)
                renderEncoder.setFragmentBuffer(uniformBuffer, offset: modelUniformOffset, index: ModelMetalRenderer_BufferIndex.uniforms.rawValue)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: model.vertexIndex, vertexCount: model.vertexCount)
            }
            if viewState.drawMode == .wireframe || viewState.drawMode == .outlined {
                renderEncoder.setVertexBuffer(uniformBuffer, offset: wireUniformOffset, index: ModelMetalRenderer_BufferIndex.uniforms.rawValue)
                renderEncoder.setFragmentBuffer(uniformBuffer, offset: wireUniformOffset, index: ModelMetalRenderer_BufferIndex.uniforms.rawValue)
                renderEncoder.drawPrimitives(type: .line, vertexStart: model.outlineIndex, vertexCount: model.outlineCount)
            }
        }
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
    }
    
    func switchTo(_ model: UnitModel) throws {
        self.model = try MetalModel(model, device)
    }
    
}

private extension ModelMetalBasicRenderer {
    
    func initializeState(in view: MTKView) throws {
        
        let modelVertexDescriptor = ModelMetalBasicRenderer.buildModelVertexDescriptor()
        let gridVertexDescriptor = ModelMetalBasicRenderer.buildGridVertexDescriptor()
        
        guard let library = device.makeDefaultLibrary() else {
            throw InitializationError.noDefaultShaderLibrary
        }
        
        modelPipelineState = try ModelMetalBasicRenderer.buildRenderPipeline(
            named: "Model Pipeline",
            library: library, device: device, view: view,
            vertexDescriptor: modelVertexDescriptor)
        gridPipelineState = try ModelMetalBasicRenderer.buildRenderPipeline(
            named: "Grid Pipeline",
            library: library, device: device, view: view,
            vertexDescriptor: gridVertexDescriptor,
            vertexFunctionName: "gridVertexShader",
            fragmentFunctionName: "gridFragmentShader")
        
        grid = try MetalGrid(size: Size2D(width: 16, height: 16), device: device)
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesciptor) else {
            throw InitializationError.badDepthState
        }
        self.depthState = depthState
    }
    
    class func buildModelVertexDescriptor() -> MTLVertexDescriptor {
        let configurator = MetalVertexDescriptorConfigurator<ModelMetalRenderer_ModelVertexAttribute, ModelMetalRenderer_BufferIndex>()
        var offset = 0

        configurator.setAttribute(.position, format: .float3, offset: offset, bufferIndex: .modelVertices)
        offset += MemoryLayout<vector_float3>.stride
        configurator.setAttribute(.normal, format: .float3, offset: offset, bufferIndex: .modelVertices)
        offset += MemoryLayout<vector_float3>.stride
        configurator.setAttribute(.texcoord, format: .float2, offset: offset, bufferIndex: .modelVertices)
        offset += MemoryLayout<vector_float2>.stride

        configurator.setLayout(.modelVertices, stride: MemoryLayout<ModelMetalRenderer_ModelVertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
    class func buildGridVertexDescriptor() -> MTLVertexDescriptor {
        let configurator = MetalVertexDescriptorConfigurator<ModelMetalRenderer_GridVertexAttribute, ModelMetalRenderer_BufferIndex>()
        
        configurator.setAttribute(.position, format: .float3, offset: 0, bufferIndex: .gridVertices)
        configurator.setLayout(.gridVertices, stride: MemoryLayout<ModelMetalRenderer_GridVertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
    class func buildRenderPipeline(named pipelineName: String = "RenderPipeline", library: MTLLibrary, device: MTLDevice, view: MTKView, vertexDescriptor: MTLVertexDescriptor, vertexFunctionName: String = "vertexShader", fragmentFunctionName: String = "fragmentShader") throws -> MTLRenderPipelineState {
        
        guard let vertexFunction = library.makeFunction(name: vertexFunctionName) else { throw InitializationError.functionNotFound(vertexFunctionName) }
        guard let fragmentFunction = library.makeFunction(name: fragmentFunctionName) else { throw InitializationError.functionNotFound(fragmentFunctionName) }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = pipelineName
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    enum InitializationError: Swift.Error {
        case noDefaultShaderLibrary
        case functionNotFound(String)
        case badDepthState
    }
    
}

// MARK:- Model

private class MetalModel {
    
    let buffer: MTLBuffer
    let vertexCount: Int
    let vertexIndex: Int
    let outlineCount: Int
    let outlineIndex: Int
    
    init(_ model: UnitModel, _ device: MTLDevice) throws {
        
        let vertexCount = MetalModel.countVertices(in: model)
        let outlineCount = MetalModel.countOutlineVertices(in: model)
        let vertexSize = vertexCount * MemoryLayout<ModelMetalRenderer_ModelVertex>.stride
        let outlineSize = outlineCount * MemoryLayout<ModelMetalRenderer_ModelVertex>.stride
        
        guard let buffer = device.makeBuffer(length: vertexSize + outlineSize, options: [.storageModeShared]) else {
            throw Error.makeBufferFailure
        }
        
        buffer.label = "UnitModel"
        
        var p = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to: ModelMetalRenderer_ModelVertex.self, capacity: vertexCount)
        MetalModel.collectVertexAttributes(pieceIndex: model.root, model: model, vertexBuffer: &p)
        p = (UnsafeMutableRawPointer(buffer.contents()) + vertexSize).bindMemory(to: ModelMetalRenderer_ModelVertex.self, capacity: outlineCount)
        MetalModel.collectOutlineVertexAttributes(pieceIndex: model.root, model: model, vertexBuffer: &p)
        
        self.buffer = buffer
        self.vertexCount = vertexCount
        self.vertexIndex = 0
        self.outlineCount = outlineCount
        self.outlineIndex = vertexCount
    }
    
    enum Error: Swift.Error {
        case makeBufferFailure
    }
    
}

private extension MetalModel {
    
    static func countVertices(in model: UnitModel) -> Int {
        return model.primitives.reduce(0) {
            (count, primitive) in
            let num = primitive.indices.count
            return count + (num >= 3 ? (num - 2) * 3 : 0)
        }
    }
    
    static func countOutlineVertices(in model: UnitModel) -> Int {
        return model.primitives.reduce(0) {
            (count, primitive) in
            let num = primitive.indices.count
            switch num {
            case 2: return count + num
            case 3...: return count + (num * 2)
            default: return count
            }
        }
    }
    
    static func collectVertexAttributes(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, parentOffset: vector_float3 = .zero, vertexBuffer: inout UnsafeMutablePointer<ModelMetalRenderer_ModelVertex>) {
        
        let piece = model.pieces[pieceIndex]
        let offset = vector_float3(piece.offset) + parentOffset
        
        for primitiveIndex in piece.primitives {
            guard primitiveIndex != model.groundPlate else { continue }
            collectVertexAttributes(primitive: model.primitives[primitiveIndex], pieceIndex: pieceIndex, model: model, offset: offset, vertexBuffer: &vertexBuffer)
        }
        
        for child in piece.children {
            collectVertexAttributes(pieceIndex: child, model: model, parentOffset: offset, vertexBuffer: &vertexBuffer)
        }
    }
    
    static func collectVertexAttributes(primitive: UnitModel.Primitive, pieceIndex: UnitModel.Pieces.Index, model: UnitModel, offset: vector_float3, vertexBuffer: inout UnsafeMutablePointer<ModelMetalRenderer_ModelVertex>) {
        
        let vertices = primitive.indices.map({ vector_float3(model.vertices[$0]) + offset })
        let texCoords = /*textures?.textureCoordinates(for: primitive.texture) ??*/ (vector_float2.zero, vector_float2.zero, vector_float2.zero, vector_float2.zero)
        
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
    
    static func collectOutlineVertexAttributes(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, parentOffset: vector_float3 = .zero, vertexBuffer: inout UnsafeMutablePointer<ModelMetalRenderer_ModelVertex>) {
        
        let piece = model.pieces[pieceIndex]
        let offset = vector_float3(piece.offset) + parentOffset
        
        for primitiveIndex in piece.primitives {
            guard primitiveIndex != model.groundPlate else { continue }
            collectOutlineVertexAttributes(primitive: model.primitives[primitiveIndex], pieceIndex: pieceIndex, model: model, offset: offset, vertexBuffer: &vertexBuffer)
        }
        
        for child in piece.children {
            collectOutlineVertexAttributes(pieceIndex: child, model: model, parentOffset: offset, vertexBuffer: &vertexBuffer)
        }
    }
    
    static func collectOutlineVertexAttributes(primitive: UnitModel.Primitive, pieceIndex: UnitModel.Pieces.Index, model: UnitModel, offset: vector_float3, vertexBuffer: inout UnsafeMutablePointer<ModelMetalRenderer_ModelVertex>) {
        
        guard primitive.indices.count >= 2 else { return }
        let vertices = primitive.indices.map({ vector_float3(model.vertices[$0]) + offset })
        
        
        let normal = vertices.count > 2 ? makeNormal(0,2,1, in: vertices) : (vertices[1] - vertices[0])
        
        for n in 1 ..< vertices.count {
            appendLine(&vertexBuffer, vertices[n-1], vertices[n], normal, pieceIndex)
        }
        let n = vertices.count - 1
        appendLine(&vertexBuffer, vertices[n], vertices[0], normal, pieceIndex)
        
    }
    
    private static func makeNormal(_ a: Int, _ b: Int, _ c: Int, in vertices: [vector_float3]) -> vector_float3 {
        let v1 = vertices[a]
        let v2 = vertices[b]
        let v3 = vertices[c]
        let u = v2 - v1
        let v = v3 - v1
        return u × v
    }
    
    static func append(_ vertexBuffer: inout UnsafeMutablePointer<ModelMetalRenderer_ModelVertex>,
                       _ texCoord1: vector_float2, _ vertex1: vector_float3,
                       _ texCoord2: vector_float2, _ vertex2: vector_float3,
                       _ texCoord3: vector_float2, _ vertex3: vector_float3,
                       _ normal: vector_float3,
                       _ pieceIndex: Int) {
        vertexBuffer[0].position = vertex1
        vertexBuffer[0].texCoord = texCoord1
        vertexBuffer[0].normal = normal
        vertexBuffer[1].position = vertex2
        vertexBuffer[1].texCoord = texCoord2
        vertexBuffer[1].normal = normal
        vertexBuffer[2].position = vertex3
        vertexBuffer[2].texCoord = texCoord3
        vertexBuffer[2].normal = normal
        vertexBuffer += 3
    }
    
    static func appendLine(_ vertexBuffer: inout UnsafeMutablePointer<ModelMetalRenderer_ModelVertex>,
                           _ vertex1: vector_float3,
                           _ vertex2: vector_float3,
                           _ normal: vector_float3,
                           _ pieceIndex: Int) {
        vertexBuffer[0].position = vertex1
//        vertexBuffer[0].texCoord = texCoord1
        vertexBuffer[0].normal = normal
        vertexBuffer[1].position = vertex2
//        vertexBuffer[1].texCoord = texCoord2
        vertexBuffer[1].normal = normal
        vertexBuffer += 2
    }
    
}

// MARK:- Grid

private class MetalGrid {
    
    let size: CGSize
    let spacing: Double
    
    let buffer: MTLBuffer
    let vertexCount: Int
    
    init(size: Size2D, gridSpacing: Int = ModelViewState.gridSize, device: MTLDevice) throws {
        
        let vertexCount = (size.width * 2) + (size.height * 2) + (size.area * 4)
        let bufferLength = vertexCount * MemoryLayout<ModelMetalRenderer_GridVertex>.size
        
        guard let buffer = device.makeBuffer(length: bufferLength, options: [.storageModeShared]) else {
            throw Error.makeBufferFailure
        }
        
        buffer.label = "Grid"
        
        let vertices = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to: ModelMetalRenderer_GridVertex.self, capacity: vertexCount)
        do {
            var n = 0
            let addLine: (vector_float3, vector_float3) -> () = { (a, b) in vertices[n].position = a; vertices[n+1].position = b; n += 2 }
            let makeVert: (Int, Int) -> vector_float3 = { (w, h) in vector_float3(x: Float(w * gridSpacing), y: Float(h * gridSpacing), z: 0) }
            
            for h in 0..<size.height {
                for w in 0..<size.width {
                    if h == 0 { addLine(makeVert(w,h), makeVert(w+1,h)) }
                    addLine(makeVert(w+1,h), makeVert(w+1,h+1))
                    addLine(makeVert(w+1,h+1), makeVert(w,h+1))
                    if w == 0 { addLine(makeVert(w,h+1), makeVert(w,h)) }
                }
            }
            
            //elementCount = n
        }
        
        /* 3x3
         +--+--+--+       2 + 2 + 2
         |  |  |  |   2 + 4 + 4 + 4
         +--+--+--+
         |  |  |  |   2 + 4 + 4 + 4
         +--+--+--+
         |  |  |  |   2 + 4 + 4 + 4
         +--+--+--+
         */
        
        self.buffer = buffer
        self.vertexCount = vertexCount
        self.size = CGSize(size * gridSpacing)
        self.spacing = Double(gridSpacing)
    }
    
    enum Error: Swift.Error {
        case makeBufferFailure
    }
    
}

// MARK:- Utility

extension vector_float4 {
    init(_ v: vector_float3, _ w: Float = 1) {
        self.init(v.x, v.y, v.z, w)
    }
    var xyz: vector_float3 { return vector_float3(x,y,z) }
}

extension vector_float3 {
    init(_ v: Vector3) {
        self.init(Float(v.x), Float(v.y), Float(v.z))
    }
    init(_ v: Vertex3) {
        self.init(Float(v.x), Float(v.y), Float(v.z))
    }
    static var zero: vector_float3 { return vector_float3(x: 0, y: 0, z: 0) }
}
extension vector_float2 {
    static var zero: vector_float2 { return vector_float2(x: 0, y: 0) }
}
func ×(lhs: vector_float3, rhs: vector_float3) -> vector_float3 {
    return simd_cross(lhs, rhs)
}

extension matrix_float4x4 {
    
    static var identity: matrix_float4x4 {
        return matrix_float4x4(columns:(vector_float4( 1, 0, 0, 0),
                                        vector_float4( 0, 1, 0, 0),
                                        vector_float4( 0, 0, 1, 0),
                                        vector_float4( 0, 0, 0, 1)))
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

func alignSizeForMetalBuffer(_ size: Int) -> Int {
    return (size & ~0xFF) + 0x100
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
