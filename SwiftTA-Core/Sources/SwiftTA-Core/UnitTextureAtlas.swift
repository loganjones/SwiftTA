//
//  UnitTextureAtlas.swift
//  TAassets
//
//  Created by Logan Jones on 5/28/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

public class UnitTextureAtlas {
    
    public let size: Size2<Int>
    public let textures: [Texture]
    
    public struct Texture {
        var location: TextureAtlasPacker.LocationRect
        var content: Content
    }
    
    public enum Content {
        case color(Int)
        case gafItem(GafContent)
        case notFound(String)
    }
    
    public struct GafContent {
        var file: FileSystem.File
        var item: GafItem
        var size: Size2<Int>
    }
    
    public init(for modelTextures: [UnitModel.Texture], from texPack: ModelTexturePack) {
        let content = UnitTextureAtlas.content(for: modelTextures, from: texPack)
        (size, textures) = UnitTextureAtlas.pack(content)
    }
    
    public func build(from filesystem: FileSystem, using palette: Palette) -> Data {
        
        let bytesPerPixel = 4
        let byteCount = size.area * bytesPerPixel
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
        
        textures.forEach {
            UnitTextureAtlas.copy(texture: $0, to: bytes, of: size, filesystem: filesystem, palette: palette)
        }
        
        return Data(bytesNoCopy: bytes, count: byteCount, deallocator: .custom({ (p, i) in p.deallocate() }))
    }
    
    public func textureCoordinates(for index: Int) -> (Vertex2f, Vertex2f, Vertex2f, Vertex2f) {
        
        let texture = textures[index]
        
        let left = GameFloat(texture.location.left) / GameFloat(size.width)
        let top = GameFloat(texture.location.top) / GameFloat(size.height)
        let right = GameFloat(texture.location.right) / GameFloat(size.width)
        let bottom = GameFloat(texture.location.bottom) / GameFloat(size.height)
        
        return (Vertex2f(left, top),
                Vertex2f(right, top),
                Vertex2f(right, bottom),
                Vertex2f(left, bottom)
        )
    }
    
}

private extension UnitTextureAtlas {
    
    class func copy(texture: Texture,
                    to bytes: UnsafeMutablePointer<UInt8>,
                    of size: Size2<Int>,
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
                frame.data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                    var sourceIndex = source.startIndex
                    for row in texture.location.top ..< texture.location.bottom {
                        for col in texture.location.left ..< texture.location.right {
                            let paletteIndex = source[sourceIndex]
                            let color = palette[paletteIndex]
                            let i = (row * pitch) + (col * bytesPerPixel)
                            bytes[i+0] = color.red
                            bytes[i+1] = color.green
                            bytes[i+2] = color.blue
                            bytes[i+3] = color.alpha
                            sourceIndex += 1
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
        return UnitTextureAtlas.Texture(location: .zero, content: .notFound(""))
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
    
    class func pack(_ content: [Content]) -> (Size2<Int>, [Texture]) {
        
        let (atlasSize, locations) = TextureAtlasPacker.pack(content)
        
        let textures = zip(content, locations).map {
            Texture(location: $1, content: $0)
        }
        
        return (atlasSize, textures)
    }
    
}

extension UnitTextureAtlas.Content: PackableTexture {
    public var size: Size2<Int> {
        switch self {
        case .color: return Size2<Int>(width: 8, height: 8)
        case .gafItem(let gaf): return gaf.size
        case .notFound: return Size2<Int>.zero
        }
    }
}
