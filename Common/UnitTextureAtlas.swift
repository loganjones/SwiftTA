//
//  UnitTextureAtlas.swift
//  TAassets
//
//  Created by Logan Jones on 5/28/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

class UnitTextureAtlas {
    
    let size: Size2D
    let textures: [Texture]
    
    struct Texture {
        var location: _Rect
        var content: Content
    }
    
    enum Content {
        case color(Int)
        case gafItem(GafContent)
        case notFound(String)
    }
    
    struct GafContent {
        var file: FileSystem.File
        var item: GafItem
        var size: Size2D
    }
    
    init(for modelTextures: [UnitModel.Texture], from texPack: ModelTexturePack) {
        let content = UnitTextureAtlas.content(for: modelTextures, from: texPack)
        (size, textures) = UnitTextureAtlas.pack(content)
    }
    
    func build(from filesystem: FileSystem, using palette: Palette) -> Data {
        
        let bytesPerPixel = 4
        let byteCount = size.area * bytesPerPixel
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
        
        textures.forEach {
            UnitTextureAtlas.copy(texture: $0, to: bytes, of: size, filesystem: filesystem, palette: palette)
        }
        
        return Data(bytesNoCopy: bytes, count: byteCount, deallocator: .custom({ (p, i) in p.deallocate() }))
    }
    
    func textureCoordinates(for index: Int) -> (Vertex2, Vertex2, Vertex2, Vertex2) {
        
        let texture = textures[index]
        
        let left = Double(texture.location.left) / Double(size.width)
        let top = Double(texture.location.top) / Double(size.height)
        let right = Double(texture.location.right) / Double(size.width)
        let bottom = Double(texture.location.bottom) / Double(size.height)
        
        return (Vertex2(x: left, y: top),
                Vertex2(x: right, y: top),
                Vertex2(x: right, y: bottom),
                Vertex2(x: left, y: bottom)
        )
    }
    
}

private extension UnitTextureAtlas {
    
    class func copy(texture: Texture,
                    to bytes: UnsafeMutablePointer<UInt8>,
                    of size: Size2D,
                    filesystem: FileSystem,
                    palette: Palette) {
        
        let bytesPerPixel = 4
        let pitch = size.width * bytesPerPixel
        
        switch texture.content {
        case .color(let paletteIndex):
            let color = palette[paletteIndex]
            for row in texture.location.top ..< texture.location.bottom {
                for col in texture.location.left ..< texture.location.right {
                    let i = (row * pitch) + (col * bytesPerPixel)
                    bytes[i+0] = color.red
                    bytes[i+1] = color.green
                    bytes[i+2] = color.blue
                    bytes[i+3] = color.alpha
                }
            }
        case .gafItem(let gaf):
            let file = try! filesystem.openFile(gaf.file)
            let offsetToFrameData = gaf.item.frameOffsets[0]
            if let frame = try? GafItem.extractFrame(from: file, at: offsetToFrameData) {
                frame.data.withUnsafeBytes { (indices: UnsafePointer<UInt8>) in
                    var raw = indices
                    for row in texture.location.top ..< texture.location.bottom {
                        for col in texture.location.left ..< texture.location.right {
                            let paletteIndex = raw.pointee
                            let color = palette[paletteIndex]
                            let i = (row * pitch) + (col * bytesPerPixel)
                            bytes[i+0] = color.red
                            bytes[i+1] = color.green
                            bytes[i+2] = color.blue
                            bytes[i+3] = color.alpha
                            raw += 1
                        }
                    }
                }
            }
        case .notFound:
            ()
        }
    }
    
}

private extension UnitTextureAtlas.Texture {
    static var zero: UnitTextureAtlas.Texture {
        return UnitTextureAtlas.Texture(location: _Rect.zero, content: .notFound(""))
    }
}

private extension UnitTextureAtlas {
    
    class func content(for modelTextures: [UnitModel.Texture], from texPack: ModelTexturePack) -> [Content] {
        
        return modelTextures.map { tex -> UnitTextureAtlas.Content in
            switch tex {
            case .image(let name):
                guard let item = texPack[name] else { return .notFound(name) }
                return .gafItem(item)
            case .color(let i):
                return .color(i)
            }
        }
        
    }
    
    class func pack(_ content: [Content]) -> (Size2D, [Texture]) {
        
        let sorted = content.enumerated().sorted(by: largestContent)
        
        let totalArea = sorted.reduce(0) { (total: Int, e: IndexedContent) in total + e.c.size.area }
        
        var findSize = Size2D(width: 1024,height: 1024)
        while findSize.area > totalArea { findSize /= 2 }
        let textureSize = findSize * 2
        
        let filler = RectFiller(size: textureSize)
        
        var textures = Array<Texture>(repeating: Texture.zero, count: content.count)
        
        sorted.forEach { (e: IndexedContent) in
            if let rect = filler.findSuitableRect(ofSize: e.c.size) {
                textures[e.i] = Texture(location: rect, content: e.c)
            }
            else {
                textures[e.i] = Texture(location: _Rect.zero, content: e.c)
            }
        }
        
        return (textureSize, textures)
    }
    
}

extension UnitTextureAtlas.Content {
    var size: Size2D {
        switch self {
        case .color: return Size2D(width: 8, height: 8)
        case .gafItem(let gaf): return gaf.size
        case .notFound: return Size2D.zero
        }
    }
}

private typealias IndexedContent = (i: Int, c: UnitTextureAtlas.Content)

private func largestContent(_ a: IndexedContent, _ b: IndexedContent) -> Bool {
    return a.c.size.area > b.c.size.area
}

struct _Rect {
    var left: Int
    var top: Int
    var right: Int
    var bottom: Int
}
extension _Rect {
    static var zero: _Rect { return _Rect(left: 0, top: 0, right: 0, bottom: 0) }
    var width: Int { return right - left }
    var height: Int { return bottom - top }
}
extension _Rect: CustomStringConvertible {
    var description: String { return "[left:\(left),top:\(top), right:\(right),bottom:\(bottom)]" }
}
extension _Rect {
    init(_ size: Size2D) {
        left = 0
        top = 0
        right = size.width
        bottom = size.height
    }
}

private class RectFiller {
    
    init(size: Size2D) {
        rects = [_Rect(size)]
        rects.reserveCapacity(32)
    }
    
    private var rects: [_Rect]
    
    func findSuitableRect(ofSize size: Size2D) -> _Rect? {
        
        // Find the first rect where `size` would fit inside
        guard let index = rects.index(where: { size.width <= $0.width && size.height <= $0.height })
            else { return nil }
        
        // This rect can fit a rect of `size`
        let found = rects[index]
        
        // We are done finding space for the new rect...
        let result = _Rect(left: found.left,
                           top: found.top,
                           right: found.left + size.width,
                           bottom: found.top + size.height)
        
        // but now we need to adjust the `rects` to remove the newly taken space.
        
        // If `result` exactly matches `found` then we can simply just remove `found` from `rects`.
        if size.width == found.width && size.height == found.height {
            rects.remove(at: index)
        }
        // If only the width dimension matches then we can adjust `found` in `rects` to subtract the taken space.
        else if size.width == found.width {
            var r = found
            r.top += size.height
            rects[index] = r
        }
        // If only the height dimension matches then we can adjust `found` in `rects` to subtract the taken space.
        else if size.height == found.height {
            var r = found
            r.left += size.width
            rects[index] = r
        }
        else {
            // `result` is a smaller subrect within `found`.
            // We'll need to split `founs into to rects:
            // one the the left of `result`,
            // and one under `result`.
            
            let split = _Rect(left: found.left + size.width,
                              top: found.top,
                              right: found.right,
                              bottom: found.top + size.height)
            
            var r = found
            r.top += size.height
            rects[index] = r
            
            rects.insert(split, at: index)
        }
        
        return result
    }
    
}


