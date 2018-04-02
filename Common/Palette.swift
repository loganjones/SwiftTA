//
//  Palette.swift
//  TAassets
//
//  Created by Logan Jones on 3/12/18.
//  Copyright © 2018 SwiftTA. All rights reserved.
//

import Foundation

struct Palette {
    
    private let entries: [Color]
    
    struct Color {
        var red: UInt8
        var green: UInt8
        var blue: UInt8
        var alpha: UInt8
    }
    
    subscript(index: Int) -> Color {
        return entries[index]
    }
    
    subscript(index: UInt8) -> Color {
        return entries[Int(index)]
    }
    
    subscript(index: TaPaletteIndex) -> Color {
        return entries[index.rawValue]
    }
    
}

extension Palette {
    
    init(_ colors: [Color]) {
        entries = colors
    }
    
    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self.init(data)
    }
    
    init(contentsOf file: FileSystem.FileHandle) {
        let data = file.readDataToEndOfFile()
        self.init(data)
    }
    
    init(_ data: Data) {
        var colors = data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Array<Color> in
            let raw = UnsafeRawPointer(bytes)
            let p = raw.bindMemory(to: Color.self, capacity: 256)
            let buf = UnsafeBufferPointer<Color>(start: p, count: 256)
            return Array(buf)
        }
        
        // TEMP for TA
        for i in colors.indexRange {
            switch TaPaletteIndex(rawValue: i) {
            case .clear?, .clear2?: colors[i].alpha = 0
            case .shadow?: colors[i].alpha = 100
            default: colors[i].alpha = 255
            }
        }
        
        entries = colors
    }
    
    init() { entries = Array(repeating: Color.white, count: 255) }
    
}

extension Palette.Color {
    static let white = Palette.Color(red: UInt8.max, green: UInt8.max, blue: UInt8.max, alpha: UInt8.max)
    static let black = Palette.Color(red: UInt8.min, green: UInt8.min, blue: UInt8.min, alpha: UInt8.max)
    static let shadow = Palette.Color(red: 0, green: 0, blue: 0, alpha: 100)
}

extension Palette {
    
    static let shadow: Palette = {
        var colors = Array(repeating: Color.shadow, count: 255)
        colors[TaPaletteIndex.clear.rawValue].alpha = 0
        colors[TaPaletteIndex.clear2.rawValue].alpha = 0
        return Palette(entries: colors)
    }()
    
}

extension Palette {
    
    func mapIndicesRgb(_ imageIndices: Data, size: Size2D) -> Data {
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
    
    func mapIndicesRgbFlipped(_ imageIndices: Data, size: Size2D) -> Data {
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
    
    func mapIndicesRgba(_ imageIndices: Data, size: Size2D) -> Data {
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
    
    func mapIndicesRgbaFlipped(_ imageIndices: Data, size: Size2D) -> Data {
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

enum TaPaletteIndex: Int {
    case clear      = 0
    case clear2     = 9
    case shadow     = 10
    case cyan       = 100
    case black      = 245
    case lightGrey2 = 246
    case lightGrey  = 247
    case darkGrey   = 248
    case red        = 249
    case green      = 250
    case yellow     = 251
    case blue       = 252
    case lightBlue  = 254
    case white      = 255
}
