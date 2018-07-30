//
//  TntView+Metal.swift
//  HPIView
//
//  Created by Logan Jones on 7/18/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa
import MetalKit


class MetalTntView: NSView, TntViewLoader, MTKViewDelegate {
    
    private(set) var viewState = MetalTntViewState()
//    private let renderer: StaticTextureSetMetalTntViewRenderer
    private let renderer: SingleTextureMetalTntViewRenderer
    
    private unowned let metalView: MTKView
    private unowned let scrollView: NSScrollView
    private unowned let emptyView: NSView
    
    required init?(tntViewFrame frameRect: CGRect) {
//        self.stateProvider = stateProvider
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        
        let metalView = MTKView(frame: frameRect, device: defaultDevice)
        metalView.autoresizingMask = [.width, .height]
        
        let scrollView = NSScrollView(frame: frameRect)
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        //scrollView.wantsLayer = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        
        let emptyView = Dummy(frame: frameRect)
        emptyView.alphaValue = 0
        
//        renderer = StaticTextureSetMetalTntViewRenderer(defaultDevice)
        renderer = SingleTextureMetalTntViewRenderer(defaultDevice)
        
        self.metalView = metalView
        self.scrollView = scrollView
        self.emptyView = emptyView
        super.init(frame: frameRect)
        
        addSubview(metalView)
        addSubview(scrollView)
        scrollView.documentView = emptyView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(contentBoundsDidChange), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        
        metalView.delegate = self
        renderer.configure(view: metalView)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }
    
    func load(_ map: TaMapModel, using palette: Palette) {
        try? renderer.load(map, using: palette)
        emptyView.frame = NSRect(size: map.resolution)
        
        scrollView.magnification = 1.0
        scrollView.contentView.scroll(to: .zero)
        
        DispatchQueue.main.async {
            self.scrollView.flashScrollers()
        }
    }
    
    func load(_ map: TakMapModel, from filesystem: FileSystem) {
//        let contentView = TakMapTileView(frame: NSRect(size: map.resolution))
//        contentView.load(map, filesystem)
//        contentView.drawFeatures = drawFeatures
//        scrollView.documentView = contentView
    }
    
    func clear() {
//        drawFeatures = nil
//        scrollView.documentView = nil
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //viewState.viewport.size = size
    }
    
    func draw(in view: MTKView) {
        renderer.drawFrame(in: view, viewState)
    }
    
    @objc func contentBoundsDidChange(_ notification: NSNotification) {
        viewState.viewport = scrollView.contentView.bounds
    }
    
    override var frame: NSRect {
        didSet {
            super.frame = frame
            viewState.viewport = scrollView.contentView.bounds
        }
    }
    /*
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        guard let character = event.charactersIgnoringModifiers?.unicodeScalars.first?.value else { return }
        switch Int(character) {
        case NSUpArrowFunctionKey:
            viewState.viewport.origin.y -= 1
        case NSDownArrowFunctionKey:
            viewState.viewport.origin.y += 1
        case NSLeftArrowFunctionKey:
            viewState.viewport.origin.x -= 1
        case NSRightArrowFunctionKey:
            viewState.viewport.origin.x += 1
        default:
            ()
        }
        setNeedsDisplay(bounds)
    }
    
    override func scrollWheel(with event: NSEvent) {
        viewState.viewport.origin.x -= event.scrollingDeltaX * viewState.scale
        viewState.viewport.origin.y -= event.scrollingDeltaY * viewState.scale
    }
    
    override func magnify(with event: NSEvent) {
        
        let scale = viewState.scale
        let center = CGPoint(x: viewState.viewport.origin.x + viewState.viewport.size.width * scale/2,
                             y: viewState.viewport.origin.y + viewState.viewport.size.height * scale/2)
        
        viewState.scale = scale - event.magnification
        
        let halfSize = CGSize(width: viewState.viewport.size.width * viewState.scale/2,
                              height: viewState.viewport.size.height * viewState.scale/2)
        
        viewState.viewport.origin.x = center.x - halfSize.width
        viewState.viewport.origin.y = center.y - halfSize.height
    }
    */
    private class Dummy: NSView {
        override var isFlipped: Bool {
            return true
        }
    }
    
}

struct MetalTntViewState {
    var viewport = CGRect()
}

//-----------------------------------

import Metal
import MetalKit
import simd

// MARK:- Single Texture Renderer

class SingleTextureMetalTntViewRenderer: NSObject {
    
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let uniformBuffer: MTLBuffer
    
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private let quadBuffer: MTLBuffer
    private var texture: MTLTexture?
    
    init(_ device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        let alignedTileUniformsSize = alignSizeForMetalBuffer(MemoryLayout<MetalTntViewRenderer_MapUniforms>.size)
        uniformBuffer = device.makeBuffer(length: alignedTileUniformsSize, options:[.storageModeShared])!
        let alignedVerticesSize = alignSizeForMetalBuffer(MemoryLayout<MetalTntViewRenderer_MapQuadVertex>.stride * 4)
        quadBuffer = device.makeBuffer(length: alignedVerticesSize, options:[.storageModeShared])!
        
        let p = UnsafeMutableRawPointer(quadBuffer.contents()).bindMemory(to: MetalTntViewRenderer_MapQuadVertex.self, capacity: 4)
        p[0].position = vector_float3(  0,   0, 0); p[0].texCoord = vector_float2(0, 0)
        p[1].position = vector_float3(  0, 256, 0); p[1].texCoord = vector_float2(0, 1)
        p[2].position = vector_float3(256,   0, 0); p[2].texCoord = vector_float2(1, 0)
        p[3].position = vector_float3(256, 256, 0); p[3].texCoord = vector_float2(1, 1)
    }
    
    func load(_ map: TaMapModel, using palette: Palette) throws {
        let beginAll = Date()
        
        let mapSize = map.resolution
        let textureSize = mapSize//.map { Int(UInt32($0).nextPowerOfTwo) }
        let tntTileSize = map.tileSet.tileSize
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: textureSize.width, height: textureSize.height, mipmapped: false)
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TextureError.badTextureDescriptor
        }
        
        let beginConversion = Date()
        let tileBuffer = map.convertTiles(using: palette)
        defer { tileBuffer.deallocate() }
        let endConversion = Date()
        
        let beginTexture = Date()
        var r = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: tntTileSize.width, height: tntTileSize.height, depth: 1))
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

extension SingleTextureMetalTntViewRenderer {
    
    func configure(view: MTKView) {
        
        view.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        view.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        view.sampleCount = 1
        
        do { try initializeState(in: view) }
        catch { print("Failed to initialize Metal state: \(error)") }
    }
    
    func initializeState(in view: MTKView) throws {
        
        let vertexDescriptor = SingleTextureMetalTntViewRenderer.buildVertexDescriptor()
        
        guard let library = device.makeDefaultLibrary() else {
            throw InitializationError.noDefaultShaderLibrary
        }
        
        pipelineState = try SingleTextureMetalTntViewRenderer.buildRenderPipeline(
            named: "Map Pipeline",
            library: library, device: device, view: view,
            vertexDescriptor: vertexDescriptor,
            vertexFunctionName: "mapQuadVertexShader",
            fragmentFunctionName: "mapQuadFragmentShader")
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesciptor) else {
            throw InitializationError.badDepthState
        }
        self.depthState = depthState
    }
    
    func drawFrame(in view: MTKView, _ viewState: MetalTntViewState) {
        guard let texture = texture else { return }
        let texteureSize = vector_float2(Float(texture.width), Float(texture.height))
        let viewportSize = vector_float2(Float(viewState.viewport.size.width), Float(viewState.viewport.size.height))
        let viewportPosition = vector_float2(Float(viewState.viewport.origin.x), Float(viewState.viewport.origin.y))
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer { commandBuffer.commit() }
        
        let modelMatrix = matrix_float4x4.identity
        let viewMatrix = matrix_float4x4.identity
        let projectionMatrix = matrix_float4x4.ortho(0, viewportSize.x, viewportSize.y, 0, -1024, 256)
        
        let uniforms = UnsafeMutableRawPointer(uniformBuffer.contents()).bindMemory(to:MetalTntViewRenderer_MapUniforms.self, capacity:1)
        uniforms.pointee.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        let vx = viewportSize.x
        let vy = viewportSize.y
        let tx = viewportPosition.x / texteureSize.x
        let ty = viewportPosition.y / texteureSize.y
        let tw = viewportSize.x / texteureSize.x
        let th = viewportSize.y / texteureSize.y
        let p = UnsafeMutableRawPointer(quadBuffer.contents()).bindMemory(to: MetalTntViewRenderer_MapQuadVertex.self, capacity: 4)
        p[0].position = vector_float3( 0,  0, 0); p[0].texCoord = vector_float2(tx, ty)
        p[1].position = vector_float3( 0, vy, 0); p[1].texCoord = vector_float2(tx, ty+th)
        p[2].position = vector_float3(vx,  0, 0); p[2].texCoord = vector_float2(tx+tw, ty)
        p[3].position = vector_float3(vx, vy, 0); p[3].texCoord = vector_float2(tx+tw, ty+th)
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "Map Render Encoder"
        renderEncoder.pushDebugGroup("Draw Map")
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: MetalTntViewRenderer_BufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: MetalTntViewRenderer_BufferIndex.uniforms.rawValue)
        renderEncoder.setVertexBuffer(quadBuffer, offset: 0, index: MetalTntViewRenderer_BufferIndex.vertices.rawValue)
        renderEncoder.setFragmentTexture(texture, index: MetalTntViewRenderer_TextureIndex.color.rawValue)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
    }
    
    class func buildVertexDescriptor() -> MTLVertexDescriptor {
        let configurator = MetalVertexDescriptorConfigurator<MetalTntViewRenderer_MapQuadVertexAttribute, MetalTntViewRenderer_BufferIndex>()
        
        configurator.setAttribute(.position, format: .float3, offset: 0, bufferIndex: .vertices)
        configurator.setAttribute(.texcoord, format: .float2, offset: MemoryLayout<vector_float3>.stride, bufferIndex: .vertices)
        configurator.setLayout(.vertices, stride: MemoryLayout<MetalTntViewRenderer_MapQuadVertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
    class func buildRenderPipeline(named pipelineName: String = "RenderPipeline", library: MTLLibrary, device: MTLDevice, view: MTKView, vertexDescriptor: MTLVertexDescriptor, vertexFunctionName: String, fragmentFunctionName: String) throws -> MTLRenderPipelineState {
        
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

extension TaMapModel {
    
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

// MARK:- Static Texture Array Renderer

class StaticTextureSetMetalTntViewRenderer: NSObject {
    
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
        var vertexCount: Int
    }
    
    init(_ device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        let alignedTileUniformsSize = alignSizeForMetalBuffer(MemoryLayout<MetalTntViewRenderer_MapUniforms>.size)
        uniformBuffer = device.makeBuffer(length: alignedTileUniformsSize, options:[.storageModeShared])!
    }
    
    func load(_ map: TaMapModel, using palette: Palette) throws {
        
        let mapSize = map.resolution
        let tileCount = mapSize.map { $0.partition(by: textureTileSize) }
        
        let texture = try makeTexture(tiles: tileCount, for: map, using: palette)
        let (vertices, vertexCount) = try makeGeometry(tiles: tileCount)
        
        mapResources = MapResources(tileCount: tileCount, texture: texture, vertices: vertices, vertexCount: vertexCount)
    }
    
    func load(_ map: TakMapModel, from filesystem: FileSystem) throws {
    }
    
}

extension StaticTextureSetMetalTntViewRenderer {
    
    func configure(view: MTKView) {
        
        view.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        view.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        view.sampleCount = 1
        
        do { try initializeState(in: view) }
        catch { print("Failed to initialize Metal state: \(error)") }
    }
    
    func initializeState(in view: MTKView) throws {
        
        let vertexDescriptor = StaticTextureSetMetalTntViewRenderer.buildVertexDescriptor()

        guard let library = device.makeDefaultLibrary() else {
            throw InitializationError.noDefaultShaderLibrary
        }

        pipelineState = try StaticTextureSetMetalTntViewRenderer.buildRenderPipeline(
            named: "Map Pipeline",
            library: library, device: device, view: view,
            vertexDescriptor: vertexDescriptor,
            vertexFunctionName: "mapTileVertexShader",
            fragmentFunctionName: "mapTileFragmentShader")

        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesciptor) else {
            throw InitializationError.badDepthState
        }
        self.depthState = depthState
    }
    
    class func buildVertexDescriptor() -> MTLVertexDescriptor {
        let configurator = MetalVertexDescriptorConfigurator<MetalTntViewRenderer_MapTileVertexAttribute, MetalTntViewRenderer_BufferIndex>()
        
        configurator.setAttribute(.position, format: .float3, offset: 0, bufferIndex: .vertices)
        configurator.setAttribute(.texcoord, format: .float2, offset: MemoryLayout<vector_float3>.stride, bufferIndex: .vertices)
        configurator.setAttribute(.slice, format: .int, offset: MemoryLayout<vector_float3>.stride + MemoryLayout<vector_float2>.stride, bufferIndex: .vertices)
        configurator.setLayout(.vertices, stride: MemoryLayout<MetalTntViewRenderer_MapTileVertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
    class func buildRenderPipeline(named pipelineName: String = "RenderPipeline", library: MTLLibrary, device: MTLDevice, view: MTKView, vertexDescriptor: MTLVertexDescriptor, vertexFunctionName: String, fragmentFunctionName: String) throws -> MTLRenderPipelineState {
        
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
    
    func drawFrame(in view: MTKView, _ viewState: MetalTntViewState) {
        guard let map = mapResources else { return }
        
        let viewportSize = vector_float2(Float(viewState.viewport.size.width), Float(viewState.viewport.size.height))
        let viewportPosition = vector_float2(Float(viewState.viewport.origin.x), Float(viewState.viewport.origin.y))
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer { commandBuffer.commit() }
        
        let modelMatrix = matrix_float4x4.identity
        let viewMatrix = matrix_float4x4.translation(-viewportPosition.x, -viewportPosition.y, 0)
        let projectionMatrix = matrix_float4x4.ortho(0, viewportSize.x, viewportSize.y, 0, -1024, 256)
        
        let uniforms = UnsafeMutableRawPointer(uniformBuffer.contents()).bindMemory(to:MetalTntViewRenderer_MapUniforms.self, capacity:1)
        uniforms.pointee.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "Map Render Encoder"
        renderEncoder.pushDebugGroup("Draw Map")
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: MetalTntViewRenderer_BufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: MetalTntViewRenderer_BufferIndex.uniforms.rawValue)
        renderEncoder.setVertexBuffer(map.vertices, offset: 0, index: MetalTntViewRenderer_BufferIndex.vertices.rawValue)
        renderEncoder.setFragmentTexture(map.texture, index: MetalTntViewRenderer_TextureIndex.color.rawValue)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: map.vertexCount)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
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
        var r = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: tntTileSize.width, height: tntTileSize.height, depth: 1))
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
    
    func makeGeometry(tiles tileCount: Size2D) throws -> (MTLBuffer, Int) {
        
        let vertexCount = tileCount.area * 6
        let alignedVerticesSize = alignSizeForMetalBuffer(MemoryLayout<MetalTntViewRenderer_MapTileVertex>.stride * vertexCount)
        guard let vertexBuffer = device.makeBuffer(length: alignedVerticesSize, options:[.storageModeShared]) else {
            throw GeometryError.badBufferAttributes
        }
        
        let v = vertexBuffer.contents().bindMemory(to: MetalTntViewRenderer_MapTileVertex.self, capacity: vertexCount)
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
                v[i+0].slice = s
                v[i+1].position = vector_float3(x+0, y+h, z)
                v[i+1].texCoord = vector_float2(0, 1)
                v[i+1].slice = s
                v[i+2].position = vector_float3(x+w, y+h, z)
                v[i+2].texCoord = vector_float2(1, 1)
                v[i+2].slice = s
                
                v[i+3].position = vector_float3(x+0, y+0, z)
                v[i+3].texCoord = vector_float2(0, 0)
                v[i+3].slice = s
                v[i+4].position = vector_float3(x+w, y+h, z)
                v[i+4].texCoord = vector_float2(1, 1)
                v[i+4].slice = s
                v[i+5].position = vector_float3(x+w, y+0, z)
                v[i+5].texCoord = vector_float2(1, 0)
                v[i+5].slice = s
                
                i += 6
                s += 1
                x += w
            }
            y += h
        }
        
        return (vertexBuffer, vertexCount)
    }
    
    enum GeometryError: Swift.Error {
        case badBufferAttributes
    }
    
}

extension Int {
    
    func partition(by divisor: Int) -> Int {
        return (self + divisor - 1) / divisor
    }
    
}

extension MTLOrigin {
    
    init(xy: Point2D, z: Int = 0) {
        self.init(x: xy.x, y: xy.y, z: z)
    }
    
}
