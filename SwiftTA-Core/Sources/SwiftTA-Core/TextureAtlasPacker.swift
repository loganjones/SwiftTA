//
//  TextureAtlasPacker.swift
//  
//
//  Created by Logan Jones on 4/5/20.
//

import Foundation

/// A representation of a texture that can be packed within an atlas.
/// We only care about the `size` here; so the requirements are minimal.
protocol PackableTexture {
    /// The size of this texture in pixels.
    var size: Size2<Int> { get }
}

/// A namespace enum for the texture packing function, `pack()`.
/// The texture atlas is a container for several individual textures.
/// `TextureAtlasPacker.pack()` computes the location for each given texture within the atlas.
public enum TextureAtlasPacker {
    
    public struct LocationRect {
        var left: Int
        var top: Int
        var right: Int
        var bottom: Int
    }
    
    /// Computes the location for each given texture within a containing texture atlas.
    /// Returns the computed locations within the atlas (in the same orders as the given `textures`),
    /// and the total size of the final atlas.
    static func pack<Textures>(_ textures: Textures) -> (atlasSize: Size2<Int>, locations: [LocationRect])
        where Textures: Collection, Textures.Element: PackableTexture {
        
        // Compute the total area of every texture to use as an approximate for how big an atlas we'll need.
        let totalArea = textures.reduce(0) { $0 + $1.size.area }
        
        // Step down the atlas size until we find an area that snuggly "fits" the totalArea.
        var findSize = Size2<Int>(width: 1024,height: 1024)
        while findSize.area > totalArea { findSize /= 2 }
        let textureSize = findSize * 2
        
        let filler = RectFiller(size: textureSize)
            
        // Sort the input textures from largest to smallest.
        // It's easier to fit the larger ones in first and then fill the smaller ones in around the edges.
        let sorted = textures.enumerated().sorted(by: largestTexture)
            
        let locations = Array<LocationRect>(unsafeUninitializedCapacity: sorted.count) { buffer, count in
            sorted.forEach { (e: IndexedTexture) in
                if let rect = filler.findSuitableRect(ofSize: e.texture.size) {
                    buffer[e.index] = rect
                }
                else {
                    buffer[e.index] = .zero
                }
            }
            count = sorted.count
        }
        
        return (textureSize, locations)
    }
    
}

// MARK:- Utility

private typealias IndexedTexture<Tex: PackableTexture> = (index: Int, texture: Tex)

private func largestTexture<Tex: PackableTexture>(_ a: IndexedTexture<Tex>, _ b: IndexedTexture<Tex>) -> Bool {
    return a.texture.size.area > b.texture.size.area
}

public extension TextureAtlasPacker.LocationRect {
    static var zero: TextureAtlasPacker.LocationRect { return TextureAtlasPacker.LocationRect(left: 0, top: 0, right: 0, bottom: 0) }
    var width: Int { return right - left }
    var height: Int { return bottom - top }
}
extension TextureAtlasPacker.LocationRect: CustomStringConvertible {
    public var description: String { return "[left:\(left),top:\(top), right:\(right),bottom:\(bottom)]" }
}
public extension TextureAtlasPacker.LocationRect {
    init(_ size: Size2<Int>) {
        left = 0
        top = 0
        right = size.width
        bottom = size.height
    }
}

// MARK:- RectFiller

// This is an old packing algorithm I worte over a decade ago for nTA.
// It is not optimal at all; but it produces decent results in decent time.
// An optimal packer is NP-hard. But there are better algorithms out there.
// Feel free to substitute a better one here.

private class RectFiller {
    
    typealias _Rect = TextureAtlasPacker.LocationRect
    
    init(size: Size2<Int>) {
        rects = [_Rect(size)]
        rects.reserveCapacity(32)
    }
    
    private var rects: [_Rect]
    
    func findSuitableRect(ofSize size: Size2<Int>) -> _Rect? {
        
        // Find the first rect where `size` would fit inside
        guard let index = rects.firstIndex(where: { size.width <= $0.width && size.height <= $0.height })
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
