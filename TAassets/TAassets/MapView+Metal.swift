//
//  MapView+Metal.swift
//  TAassets
//
//  Created by Logan Jones on 8/7/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa
import MetalKit


class MetalMapView: NSView, MapViewLoader, MTKViewDelegate {
    
    private(set) var viewState = MetalTntViewState()
    
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private var tntRenderer: MetalTntRenderer?
    private let featureRenderer: MetalMapFeatureRenderer
    
    private unowned let metalView: MTKView
    private unowned let scrollView: NSScrollView
    private unowned let emptyView: NSView
    
    required init?(tntViewFrame frameRect: CGRect) {
        //        self.stateProvider = stateProvider
        
        guard let metalDevice = MTLCreateSystemDefaultDevice(),
            let metalCommandQueue = metalDevice.makeCommandQueue(),
            let library = metalDevice.makeDefaultLibrary()
            else {
                print("Metal is not supported on this device")
                return nil
        }
        
        let metalView = MTKView(frame: frameRect, device: metalDevice)
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
        
        self.library = library
        self.commandQueue = metalCommandQueue
        self.metalView = metalView
        self.scrollView = scrollView
        self.emptyView = emptyView
        self.featureRenderer = MetalMapFeatureRenderer(metalDevice)
        super.init(frame: frameRect)
        
        addSubview(metalView)
        addSubview(scrollView)
        scrollView.documentView = emptyView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(contentBoundsDidChange), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        
        metalView.delegate = self
        try? featureRenderer.configure(for: MetalHost(view: metalView, device: metalDevice, library: library))
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }
    
    func load(_ mapName: String, from filesystem: FileSystem) throws {
        
        let beginMap = Date()
        
        let beginOta = Date()
        guard let otaFile = filesystem.root[filePath: "maps/" + mapName + ".ota"]
            else { throw FileSystem.Directory.ResolveError.notFound }
        let info = try MapInfo(contentsOf: otaFile, in: filesystem)
        let endOta = Date()
        
        let tileCountString: String
        let beginTnt = Date()
        let tntFile = try filesystem.openFile(at: "maps/" + mapName + ".tnt")
        let map = try MapModel(contentsOf: tntFile)
        switch map {
        case .ta(let model):
            let palette = try Palette.standardTaPalette(from: filesystem)
            load(model, using: palette)
            let tileCount = model.tileSet.count
            tileCountString = "count:\(tileCount) pixels:\(tileCount * 16 * 16)"
        case .tak(let model):
            load(model, from: filesystem)
            tileCountString = ""
        }
        let endTnt = Date()
        
        let beginFeatures = Date()
        try? featureRenderer.loadFeatures(containedIn: map, startingWith: info.properties["planet"], from: filesystem)
        let endFeatures = Date()
        
        let endMap = Date()
        
        print("""
            Map load time: \(endMap.timeIntervalSince(beginMap)) seconds
              OTA: \(endOta.timeIntervalSince(beginOta)) seconds
              TNT: \(endTnt.timeIntervalSince(beginTnt)) seconds
              Features: \(endFeatures.timeIntervalSince(beginFeatures)) seconds
            """)
//        print("Features: \(featureNames)")
        print("Map Size: tiles:\(map.mapSize) pixels:\(map.resolution)")
        print("Tiles: "+tileCountString)
    }
    
    func load(_ map: TaMapModel, using palette: Palette) {
        guard let device = metalView.device else { return }
        
        let renderer: MetalTntRenderer
        if map.resolution.max > device.maximum2dTextureSize {
            print("Using tiled tnt renderer")
            renderer = DynamicTileMetalTntViewRenderer(device)
        }
        else {
            print("Using simple tnt renderer")
            renderer = SingleTextureMetalTntViewRenderer(device)
        }
        
        try? renderer.load(map, using: palette)
        emptyView.frame = NSRect(size: map.resolution)
        
        scrollView.magnification = 1.0
        scrollView.contentView.scroll(to: .zero)
        
        DispatchQueue.main.async {
            self.scrollView.flashScrollers()
        }
        
        try? renderer.configure(for: MetalHost(view: metalView, device: device, library: library))
        self.tntRenderer = renderer
    }
    
    func load(_ map: TakMapModel, from filesystem: FileSystem) {
        //        let contentView = TakMapTileView(frame: NSRect(size: map.resolution))
        //        contentView.load(map, filesystem)
        //        contentView.drawFeatures = drawFeatures
        //        scrollView.documentView = contentView
        
        guard let device = metalView.device else { return }
        let renderer = DynamicTileMetalTntViewRenderer(device)
        
        try? renderer.load(map, from: filesystem)
        emptyView.frame = NSRect(size: map.resolution)
        
        scrollView.magnification = 1.0
        scrollView.contentView.scroll(to: .zero)
        
        DispatchQueue.main.async {
            self.scrollView.flashScrollers()
        }
        
        try? renderer.configure(for: MetalHost(view: metalView, device: device, library: library))
        self.tntRenderer = renderer
    }
    
    func clear() {
        //        drawFeatures = nil
        //        scrollView.documentView = nil
        tntRenderer = nil
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //viewState.viewport.size = size
    }
    
    func draw(in view: MTKView) {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer { commandBuffer.commit() }
        
        tntRenderer?.setupNextFrame(viewState, commandBuffer)
        featureRenderer.setupNextFrame(viewState)
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "Map Render Encoder"
        renderEncoder.pushDebugGroup("Draw Map")
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        tntRenderer?.drawFrame(with: renderEncoder)
        featureRenderer.drawFrame(with: renderEncoder)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
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
    
    private class Dummy: NSView {
        override var isFlipped: Bool {
            return true
        }
    }
    
}

private let maxBuffersInFlight = 3

private typealias BufferIndex = MetalMapViewRenderer_BufferIndex
private typealias TextureIndex = MetalMapViewRenderer_TextureIndex
private typealias Uniforms = MetalMapViewRenderer_FeatureUniforms
private typealias Vertex = MetalMapViewRenderer_FeatureQuadVertex
private typealias VertexAttributes = MetalMapViewRenderer_FeatureQuadVertexAttribute

class MetalMapFeatureRenderer {
    
    let device: MTLDevice
    
    private let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    private var uniformBuffer: MetalRingBuffer
    private var features: [Feature] = []
    private var shadows: [Feature] = []
    
    required init(_ device: MTLDevice) {
        self.device = device
        uniformBuffer = device.makeRingBuffer(length: MemoryLayout<Uniforms>.size, count: maxBuffersInFlight, options: [.storageModeShared])!
    }
    
    func loadFeatures(containedIn map: MapModel, startingWith planet: String? = nil, from filesystem: FileSystem) throws {
        let loaded = loadMapFeatures(map, planet: planet, from: filesystem)
        self.features = loaded.features
        self.shadows = loaded.shadows
    }
    
    func setupNextFrame(_ viewState: MetalTntViewState) {
        
        let viewportSize = vector_float2(Float(viewState.viewport.size.width), Float(viewState.viewport.size.height))
        let viewportPosition = vector_float2(Float(viewState.viewport.origin.x), Float(viewState.viewport.origin.y))
        
        let modelMatrix = matrix_float4x4.identity
        let viewMatrix = matrix_float4x4.translation(-viewportPosition.x, -viewportPosition.y, 0)
        let projectionMatrix = matrix_float4x4.ortho(0, viewportSize.x, viewportSize.y, 0, -1024, 256)
        
        let uniforms = uniformBuffer.next().contents.bindMemory(to: Uniforms.self, capacity: 1)
        uniforms.pointee.mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
    }
    
    func drawFrame(with renderEncoder: MTLRenderCommandEncoder) {
        let features = self.features
        
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
    
    func configure(for metal: MetalHost) throws {
        
        metal.view.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metal.view.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metal.view.sampleCount = 1
        
        let vertexDescriptor = MetalMapFeatureRenderer.buildVertexDescriptor()
        
        pipelineState = try metal.makeRenderPipelineState(
            named: "Feature Pipeline",
            vertexDescriptor: vertexDescriptor,
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
    
    class func buildVertexDescriptor() -> MTLVertexDescriptor {
        let configurator = MetalVertexDescriptorConfigurator<VertexAttributes, BufferIndex>()
        
        configurator.setAttribute(.position, format: .float3, offset: 0, bufferIndex: .vertices)
        configurator.setAttribute(.texcoord, format: .float2, offset: MemoryLayout<vector_float3>.stride, bufferIndex: .vertices)
        configurator.setLayout(.vertices, stride: MemoryLayout<Vertex>.stride, stepRate: 1, stepFunction: .perVertex)
        
        return configurator.vertexDescriptor
    }
    
}

extension MetalMapFeatureRenderer {
    
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
        typealias Frame = (slice: Int, offset: Point2D)
    }
    
    func loadMapFeatures(_ map: MapModel, planet: String?, from filesystem: FileSystem) -> (features: [Feature], shadows: [Feature]) {
        
        let featureInfo = MapFeatureInfo.collectFeatures(named: Set(map.features), strartingWith: planet, from: filesystem)
        let palettes = MapFeatureInfo.loadFeaturePalettes(featureInfo, from: filesystem)
        let occurrences = groupFeatureOccurrences(map)
        
        var features: [Feature] = []
        var shadows: [Feature] = []
        features.reserveCapacity(featureInfo.count)
        shadows.reserveCapacity(featureInfo.count/2)
        
        let shadowPalette = Palette.shadow
        
        MapFeatureInfo.collateFeatureGafItems(featureInfo, from: filesystem) {
            (name, info, item, gafHandle, gafListing) in
            
            guard let featureIndex = map.features.index(of: name) else { return }//.firstIndex(of: name) else { return }
            guard let occurrences = occurrences[featureIndex], !occurrences.isEmpty else { return }
            guard let gafFrames = try? item.extractFrames(from: gafHandle) else { return }
            guard let palette = palettes[info.world ?? ""] else { return }
            
            if gafFrames.count == 1 {
                if let texture = try? makeTexture(for: gafFrames[0], using: palette),
                    let instances = buildInstances(of: (texture.size, gafFrames[0].offset, info.footprint), from: occurrences, in: map)
                {
                    features.append(.static(StaticFeature(texture: texture, instances: instances.0, instancesVertexCount: instances.1)))
                }
                
                if let shadowName = info.shadowGafItemName,
                    let shadowItem = gafListing[shadowName],
                    let shadowFrame = try? shadowItem.extractFrame(index: 0, from: gafHandle),
                    let shadowTexture = try? makeTexture(for: shadowFrame, using: shadowPalette),
                    let shadowInstances = buildInstances(of: (shadowTexture.size, shadowFrame.offset, info.footprint), from: occurrences, in: map)
                {
                    shadows.append(.static(StaticFeature(texture: shadowTexture, instances: shadowInstances.0, instancesVertexCount: shadowInstances.1)))
                }
            }
            else {
                // TEMP
                print("TODO: Support animated map feature \(name) (\(gafFrames.count) frames)")
                let texture = try! makeTexture(for: gafFrames[0], using: palette)
                let instances = buildInstances(of: (texture.size, gafFrames[0].offset, info.footprint), from: occurrences, in: map)!
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
    
    func groupFeatureOccurrences(_ map: MapModel) -> [Int: [Int]] {
        var featureOccurrences: [Int: [Int]] = [:]
        
        for i in map.featureMap.indices {
            guard let featureIndex = map.featureMap[i] else { continue }
            featureOccurrences[featureIndex, default: []].append(i)
        }
        
        return featureOccurrences
    }
    
    func buildInstances(of feature: (size: Size2D, offset: Point2D, footprint: Size2D), from occurrenceIndices: [Int], in map: MapModel) -> (MTLBuffer, Int)? {
        
        let vertexCount = occurrenceIndices.count * 6
        guard let vertexBuffer = device.makeBuffer(length: MemoryLayout<Vertex>.stride * vertexCount, options: [.storageModeShared]) else { return nil }
        var vertices = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: vertexCount)
        
        for i in occurrenceIndices {
            
            let boundingBox = map.worldPosition(ofMapIndex: i)
                .center(inFootprint: feature.footprint)
                .offset(by: feature.offset)
                .adjust(forHeight: map.heightMap[i])
                .makeRect(size: feature.size)
            
            createRect(boundingBox, in: vertices)
            vertices += 6
        }
        
        return (vertexBuffer, vertexCount)
    }
    
}

extension MetalMapFeatureRenderer.Feature {
    
    var texture: MTLTexture {
        switch self {
        case .static(let f): return f.texture
        case .animated(let f): return f.texture
        }
    }
    
    var size: Size2D {
        switch self {
        case .static(let f):
            return f.texture.size
        case .animated(let f):
            return f.texture.size
        }
    }
    
}

private extension MapModel {
    func worldPosition(ofMapIndex index: Int) -> Point2D {
        return Point2D(index: index, stride: self.mapSize.width) * 16
    }
}
private extension Point2D {
    
    func center(inFootprint footprint: Size2D) -> Point2D {
        return self + (footprint * 8)
    }
    
    func offset(by offset: Point2D) -> Point2D {
        return self - offset
    }
    
    func adjust(forHeight height: Int) -> CGPoint {
        let h = CGFloat(height) / 2.0
        return CGPoint(x: CGFloat(self.x), y: CGFloat(self.y) - h)
    }
    
}

private func createRect(_ rect: CGRect, in vertices: UnsafeMutablePointer<Vertex>) {

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
