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
    
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private var renderer: MetalTntRenderer?
    
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
        super.init(frame: frameRect)
        
        addSubview(metalView)
        addSubview(scrollView)
        scrollView.documentView = emptyView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(contentBoundsDidChange), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        
        metalView.delegate = self
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
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
        self.renderer = renderer
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
        renderer = nil
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //viewState.viewport.size = size
    }
    
    func draw(in view: MTKView) {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        defer { commandBuffer.commit() }
        
        renderer?.setupNextFrame(viewState, commandBuffer)
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "Map Render Encoder"
        renderEncoder.pushDebugGroup("Draw Map")
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderer?.drawFrame(with: renderEncoder)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
    }
    
    @objc func contentBoundsDidChange(_ notification: NSNotification) {
        viewState.viewport = Rect4f(scrollView.contentView.bounds)
    }
    
    override var frame: NSRect {
        didSet {
            super.frame = frame
            viewState.viewport = Rect4f(scrollView.contentView.bounds)
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
    var viewport = Rect4f()
}

protocol MetalTntRenderer {
    
    var device: MTLDevice { get }
    
    init(_ device: MTLDevice)
    
    func load(_ map: TaMapModel, using palette: Palette) throws
    
    func configure(for metal: MetalHost) throws
    
    func setupNextFrame(_ viewState: MetalTntViewState, _ commandBuffer: MTLCommandBuffer)
    func drawFrame(with renderEncoder: MTLRenderCommandEncoder)
    
}

extension TaMapModel {
    
    func convertTiles(using palette: Palette) -> UnsafeBufferPointer<UInt8> {
        
        let tntTileSize = tileSet.tileSize
        let tileBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: tileSet.count * tntTileSize.area * 4)
        
        tileSet.tiles.withUnsafeBytes() {
            (sourceTiles: UnsafeRawBufferPointer) in
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
