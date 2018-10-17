//
//  Palette.swift
//  TAassets
//
//  Created by Logan Jones on 3/12/18.
//  Copyright © 2018 SwiftTA. All rights reserved.
//

import Foundation

struct Palette {
    
    private var colors: [Color]
    
    struct Color {
        var red: UInt8
        var green: UInt8
        var blue: UInt8
        var alpha: UInt8
    }
    
    init(_ colors: [Color]) {
        self.colors = colors
    }
    
    init() { colors = Array(repeating: Color.white, count: 255) }
    
    subscript(index: Int) -> Color {
        return colors[index]
    }
    
    subscript(index: UInt8) -> Color {
        return colors[Int(index)]
    }
    
}

// MARK:- PAL Support

extension Palette {
    
    init(palContentsOf url: URL, applyStandardTransparencies: Bool = true) throws {
        let data = try Data(contentsOf: url)
        self.init(palData: data)
    }
    
    init<File>(palContentsOf file: File) where File: FileReadHandle {
        let data = file.readDataToEndOfFile()
        self.init(palData: data)
    }
    
    init(palData data: Data) {
        colors = data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Array<Color> in
            let raw = UnsafeRawPointer(bytes)
            let p = raw.bindMemory(to: Color.self, capacity: 256)
            let buf = UnsafeBufferPointer<Color>(start: p, count: 256)
            return Array(buf)
        }
        
        // The TA .pal files have every color with a 0 alpha value ಠ_ಠ
        for i in colors.indices {
            colors[i].alpha = 255
        }
    }
    
}

// MARK:- Simple Color Accessors

extension Palette.Color {
    static let white = Palette.Color(red: UInt8.max, green: UInt8.max, blue: UInt8.max, alpha: UInt8.max)
    static let black = Palette.Color(red: UInt8.min, green: UInt8.min, blue: UInt8.min, alpha: UInt8.max)
    static let shadow = Palette.Color(red: 0, green: 0, blue: 0, alpha: 100)
}

extension Palette {
    
    static let shadow: Palette = {
        var colors = Array(repeating: Color.shadow, count: 255)
        colors[0].alpha = 0
        colors[9].alpha = 0
        return Palette(colors)
    }()
    
}

// MARK:- Chorma Keys (Transparency)

extension Palette {
    
    mutating func applyChromaKeys(_ indices: Set<Int>, alpha: UInt8 = 0) {
        for i in indices {
            colors[i].alpha = alpha
        }
    }
    
    func applyingChromaKeys(_ indices: Set<Int>, alpha: UInt8 = 0) -> Palette {
        var copy = colors
        for i in indices {
            copy[i].alpha = alpha
        }
        return Palette(copy)
    }
    
}

// MARK:- Unsafe Memory Access

extension Palette {
    
    func withUnsafeBufferPointer<R>(body: (_ colors: UnsafeBufferPointer<Palette.Color>) throws -> R ) rethrows -> R {
        return try colors.withUnsafeBufferPointer(body)
    }
    
}

// MARK:- Image Mapping

extension Palette {
    
    func mapIndicesRgb(_ imageIndices: Data, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 3)
        pixelData.withUnsafeMutableBytes() { (pixels: UnsafeMutablePointer<UInt8>) in
            imageIndices.withUnsafeBytes { (indices: UnsafePointer<UInt8>) in
                var pixel = pixels
                var raw = indices
                for _ in 0..<(size.width * size.height) {
                    let colorIndex = raw.pointee
                    pixel[0] = palette[colorIndex].red
                    pixel[1] = palette[colorIndex].green
                    pixel[2] = palette[colorIndex].blue
                    pixel += 3
                    raw += 1
                }
            }
        }
        return pixelData
    }
    
    func mapIndicesRgbFlipped(_ imageIndices: Data, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 3)
        pixelData.withUnsafeMutableBytes() { (pixels: UnsafeMutablePointer<UInt8>) in
            imageIndices.withUnsafeBytes { (indices: UnsafePointer<UInt8>) in
                var line = pixels + ((size.area - size.width) * 3)
                var raw = indices
                for _ in 0..<size.height {
                    var pixel = line
                    for _ in 0..<size.width {
                        let colorIndex = raw.pointee
                        pixel[0] = palette[colorIndex].red
                        pixel[1] = palette[colorIndex].green
                        pixel[2] = palette[colorIndex].blue
                        pixel += 3
                        raw += 1
                    }
                    line -= size.width * 3
                }
            }
        }
        return pixelData
    }
    
    func mapIndicesRgba(_ imageIndices: Data, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 4)
        pixelData.withUnsafeMutableBytes() { (pixels: UnsafeMutablePointer<UInt8>) in
            imageIndices.withUnsafeBytes { (indices: UnsafePointer<UInt8>) in
                var pixel = pixels
                var raw = indices
                for _ in 0..<(size.width * size.height) {
                    let colorIndex = raw.pointee
                    pixel[0] = palette[colorIndex].red
                    pixel[1] = palette[colorIndex].green
                    pixel[2] = palette[colorIndex].blue
                    pixel[3] = palette[colorIndex].alpha
                    pixel += 4
                    raw += 1
                }
            }
        }
        return pixelData
    }
    
    func mapIndicesRgbaFlipped(_ imageIndices: Data, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 4)
        pixelData.withUnsafeMutableBytes() { (pixels: UnsafeMutablePointer<UInt8>) in
            imageIndices.withUnsafeBytes { (indices: UnsafePointer<UInt8>) in
                var line = pixels + ((size.area - size.width) * 4)
                var raw = indices
                for _ in 0..<size.height {
                    var pixel = line
                    for _ in 0..<size.width {
                        let colorIndex = raw.pointee
                        pixel[0] = palette[colorIndex].red
                        pixel[1] = palette[colorIndex].green
                        pixel[2] = palette[colorIndex].blue
                        pixel[3] = palette[colorIndex].alpha
                        pixel += 4
                        raw += 1
                    }
                    line -= size.width * 4
                }
            }
        }
        return pixelData
    }
    
}
