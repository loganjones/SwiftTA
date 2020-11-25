//
//  MetalGuiDrawable.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 4/3/20.
//  Copyright © 2020 Logan Jones. All rights reserved.
//

import Metal
import MetalKit
import simd
import SwiftTA_Core


private typealias BufferIndex = MetalGui_BufferIndex
private typealias TextureIndex = MetalGui_TextureIndex
private typealias Uniforms = MetalGui_Uniforms
private typealias Vertex = MetalGui_QuadVertex
private typealias VertexAttributes = MetalGui_QuadVertexAttribute


class MetalGuiDrawable {
    
    let device: MTLDevice
    
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private var uniformBuffer: MetalRingBuffer
    private var quadBuffer: MetalRingBuffer
    private var indexBuffer: MetalRingBuffer
    
    private var cursorsTexture: MTLTexture?
    
    private var cursors: [Cursor: [PackedCursorFrame]] = [:]
    private var currentCursor: (type: Cursor, frameIndex: Int) = (.normal, 0)
    private var cursorAnimateCount = 0
    private let cursorAnimateTrigger = 4
    private let cursorIndexRange = 0..<6
    
    private var selectionTexture: MTLTexture?
    private var selectionIndexRange = 0..<1
    
    private var vertexMax = 1024 * 4
    private var indexMax = 1024 * 6
    
    required init(_ device: MTLDevice, _ maxBuffersInFlight: Int) {
        self.device = device
        
        uniformBuffer = device.makeRingBuffer(length: MemoryLayout<Uniforms>.size, count: maxBuffersInFlight, options: [.storageModeShared])!
        quadBuffer = device.makeRingBuffer(length: MemoryLayout<Vertex>.stride * vertexMax, count: maxBuffersInFlight, options: [.storageModeShared])!
        indexBuffer = device.makeRingBuffer(length: MemoryLayout<UInt16>.stride * indexMax, count: maxBuffersInFlight, options: [.storageModeShared])!
    }
    
    func loadCursors(from filesystem: FileSystem, with palette: Palette) throws {
        let gaf = try filesystem.openFile(at: Cursor.gafFilePath)
        let listing = try GafListing(withContentsOf: gaf)
        
        // A collection of every frame for every cursor.
        // We'll use this to pack the frames into a texture atlas.
        var allFrames: [LoadedCursorFrame] = []
        
        // Once every frame is packed, a cursor will be mapped in this collection with its corresponding frame metadata.
        var cursors: [Cursor: [PackedCursorFrame]] = [:]
        
        for cursor in Cursor.allCases {
            guard let item = listing[cursor.gafItemName] else {
                //throw RuntimeError("\(cursor.gafItemName) not found in GAF listing for \(cursor)")
                continue
            }
            
            guard let rawFrames = try? item.extractFrames(from: gaf) else {
                continue
            }
            
            cursors[cursor] = rawFrames.map { PackedCursorFrame($0) }
            allFrames.append(contentsOf: rawFrames.enumerated().map { LoadedCursorFrame(cursor: cursor, frame: $0) })
        }
        
        let atlas = TextureAtlasPacker.pack(allFrames)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: atlas.atlasSize.width, height: atlas.atlasSize.height, mipmapped: false)
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TextureError.badTextureDescriptor
        }
        
        for (i, location) in atlas.locations.enumerated() {
            let frame = allFrames[i]
            let frameData = palette.mapIndicesRgba(frame.data, size: frame.size)
            frameData.withUnsafeBytes() { frameBuffer in
                let r = MTLRegion(origin: MTLOrigin(x: location.left, y: location.top, z: 0), size: MTLSize(frame.size, depth: 1))
                texture.replace(region: r, mipmapLevel: 0, withBytes: frameBuffer.baseAddress!, bytesPerRow: frame.size.width * 4)
            }
            cursors[frame.cursor]?[frame.index].applyAtlasLocation(location, for: atlas.atlasSize)
        }
        
        self.cursors = cursors
        self.cursorsTexture = texture
        
        
        let descriptor3 = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: 256, height: 256, mipmapped: false)
        guard let texture3 = device.makeTexture(descriptor: descriptor3) else {
            throw TextureError.badTextureDescriptor
        }
        let colorSize = Size2<Int>(256, 256)
        let colorData = palette.makeRgba(withColorAtIndex: 251, size: colorSize)
        colorData.withUnsafeBytes() { buffer in
            let r = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(colorSize, depth: 1))
            texture3.replace(region: r, mipmapLevel: 0, withBytes: buffer.baseAddress!, bytesPerRow: colorSize.width * 4)
        }
        self.selectionTexture = texture3
    }
    
    enum TextureError: Swift.Error {
        case badTextureDescriptor
    }

}

extension MetalGuiDrawable {
    
    func configure(for metal: MetalHost) throws {
        
        let vertexDescriptor = Self.buildVertexDescriptor()
        
        pipelineState = try metal.makeRenderPipelineState(
            named: "GUI Pipeline",
            vertexDescriptor: vertexDescriptor,
            vertexFunctionName: "guiQuadVertexShader",
            fragmentFunctionName: "guiQuadFragmentShader")
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesciptor) else {
            throw MTLDeviceInitializationError.badDepthState
        }
        self.depthState = depthState
    }
    
    func setupNextFrame(_ viewState: GameViewState, _ commandBuffer: MTLCommandBuffer) {
        
        let frame = nextCursorFrame(for: viewState)
        
        let modelMatrix = matrix_float4x4.identity
        let viewMatrix = matrix_float4x4.identity
        let projectionMatrix = matrix_float4x4.ortho(Rect4(size: viewState.screenSize), -1024, 256)
        
        let uniforms = uniformBuffer.next().contents.bindMemory(to: Uniforms.self, capacity: 1)
        uniforms.pointee.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        var vertexCount = 0
        let p1 = frame.position1 + viewState.cursorLocation
        let p2 = frame.position2 + viewState.cursorLocation
        var vz = GameFloat(256)
        let t1 = frame.texcoord1
        let t2 = frame.texcoord2
        let p = quadBuffer.next().contents.bindMemory(to: Vertex.self, capacity: vertexMax)
        let indices = indexBuffer.next().contents.bindMemory(to: UInt16.self, capacity: indexMax)
        p[0] = Vertex(position: Vector3f(p1.x, p1.y, vz), texCoord: Vector2f(t1.x, t1.y))
        p[1] = Vertex(position: Vector3f(p1.x, p2.y, vz), texCoord: Vector2f(t1.x, t2.y))
        p[2] = Vertex(position: Vector3f(p2.x, p2.y, vz), texCoord: Vector2f(t2.x, t2.y))
        p[3] = Vertex(position: Vector3f(p2.x, p1.y, vz), texCoord: Vector2f(t2.x, t1.y))
        vertexCount += 4
        indices.addTriangle(at: 0, indices: [0,1,2])
        indices.addTriangle(at: 3, indices: [3,0,2])
        
        vz = 0
        
        let selectionIndexStart = 6
        var selectionIndexCount = 0
        for case let .unit(unit) in viewState.objects {
            guard unit.selected else { continue }
            guard vertexCount < vertexMax else { break }
            guard (selectionIndexStart + selectionIndexCount) < indexMax else { break }
            let bounds = viewState.worldToScreen(unit)
            let points = bounds.points
            let vz = unit.position.z
            let i = vertexCount
            p[i+0] = Vertex(position: Vector3f(points.a.x, points.a.y, vz), texCoord: Vector2f(0, 0))
            p[i+1] = Vertex(position: Vector3f(points.b.x, points.b.y, vz), texCoord: Vector2f(0, 1))
            p[i+2] = Vertex(position: Vector3f(points.c.x, points.c.y, vz), texCoord: Vector2f(1, 1))
            p[i+3] = Vertex(position: Vector3f(points.d.x, points.d.y, vz), texCoord: Vector2f(1, 0))
            let ii = selectionIndexStart + selectionIndexCount
            indices.addTriangle(at: ii+0, indices: [i+0,i+1,i+2])
            indices.addTriangle(at: ii+3, indices: [i+3,i+0,i+2])
            vertexCount += 4
            selectionIndexCount += 6
        }
        selectionIndexRange = Range(start: selectionIndexStart, count: selectionIndexCount)
    }
    
    func drawFrame(with renderEncoder: MTLRenderCommandEncoder) {
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(uniformBuffer, index: BufferIndex.uniforms)
        renderEncoder.setFragmentBuffer(uniformBuffer, index: BufferIndex.uniforms)
        renderEncoder.setVertexBuffer(quadBuffer, index: BufferIndex.vertices)
        
        renderEncoder.setFragmentTexture(cursorsTexture, index: TextureIndex.color)
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexRange: cursorIndexRange, indexType: .uint16, indexBuffer: indexBuffer)
            
        if !selectionIndexRange.isEmpty {
            renderEncoder.setFragmentTexture(selectionTexture, index: TextureIndex.color)
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexRange: selectionIndexRange, indexType: .uint16, indexBuffer: indexBuffer)
        }
    }
    
    class func buildVertexDescriptor() -> MTLVertexDescriptor {
        let configurator = MetalVertexDescriptorConfigurator<VertexAttributes, BufferIndex>()
        
        configurator.setAttribute(.position, format: .float3, keyPath: \Vertex.position, bufferIndex: .vertices)
        configurator.setAttribute(.texcoord, format: .float2, keyPath: \Vertex.texCoord, bufferIndex: .vertices)
        configurator.setLayout(.vertices, stride: MemoryLayout<Vertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
}

// MARK:- Cursors

private struct PackedCursorFrame {
    var position1: Point2f
    var position2: Point2f
    var texcoord1: Point2f
    var texcoord2: Point2f
}

private extension PackedCursorFrame {
    init(_ rawFrame: GafItem.Frame) {
        position1 = -Point2f(rawFrame.offset)
        position2 = position1 + Point2f(rawFrame.size)
        texcoord1 = .zero
        texcoord2 = .zero
    }
    mutating func applyAtlasLocation(_ location: TextureAtlasPacker.LocationRect, for textureSize: Size2<Int>) {
        let left = GameFloat(location.left) / GameFloat(textureSize.width)
        let top = GameFloat(location.top) / GameFloat(textureSize.height)
        let right = GameFloat(location.right) / GameFloat(textureSize.width)
        let bottom = GameFloat(location.bottom) / GameFloat(textureSize.height)
        texcoord1 = Vertex2f(left, top)
        texcoord2 = Vertex2f(right, bottom)
    }
}

private struct LoadedCursorFrame: PackableTexture {
    var cursor: Cursor
    var index: Int
    var size: Size2<Int>
    var center: Point2<Int>
    var data: Data
}

private extension LoadedCursorFrame {
    init(cursor: Cursor, metadata: (Int, GafItem.FrameMetadata)) {
        self.cursor = cursor
        self.index = metadata.0
        self.size = metadata.1.size
        self.center = metadata.1.offset
        self.data = Data()
    }
    init(cursor: Cursor, frame: (Int, GafItem.Frame)) {
        self.cursor = cursor
        self.index = frame.0
        self.size = frame.1.size
        self.center = frame.1.offset
        self.data = frame.1.data
    }
}

private extension MetalGuiDrawable {
    
    func nextCursorFrame(for viewState: GameViewState) -> PackedCursorFrame {
        
        // If the currently rendering cursor does not match the view state,
        // then reset the currently rendering cursor to the initial frame of the view state's cursor.
        if viewState.cursorType != currentCursor.type {
            currentCursor = (viewState.cursorType, 0)
        }
        
        // The frames for this cursor. This shouldn't fail; return zero values just in case it does.
        guard let frames = cursors[currentCursor.type] else {
            return PackedCursorFrame(position1: .zero, position2: .zero, texcoord1: .zero, texcoord2: .zero)
        }
        
        // The current frme to be rendered.
        // frameIndex should be 0 or some other value that was already bounds checked.
        let frame = frames[currentCursor.frameIndex]
        
        // If this is not an animated cursor (frame count is 1) then there is no need to continue.
        guard frames.count > 1 else { return frame }
        
        // The rendering cursor will animate every `cursorAnimateTrigger` frames.
        if cursorAnimateCount < cursorAnimateTrigger {
            // Not time to animate yet.
            cursorAnimateCount += 1
        }
        else {
            // Go to the next frame for this cursor (wrap around to the first frame if at the end).
            let nextIndex = currentCursor.frameIndex + 1
            currentCursor = (currentCursor.type, nextIndex < frames.count ? nextIndex : 0)
            cursorAnimateCount = 0
        }
        
        return frame
    }
    
}

private extension UnsafeMutablePointer where Pointee == UInt16 {
    
    func addTriangle(at index: Int, indices: [Int]) {
        self[index+0] = UInt16(indices[0])
        self[index+1] = UInt16(indices[1])
        self[index+2] = UInt16(indices[2])
    }
    
}
