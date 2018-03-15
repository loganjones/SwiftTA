//
//  Palette.swift
//  TAassets
//
//  Created by Logan Jones on 3/12/18.
//  Copyright © 2018 SwiftTA. All rights reserved.
//

import Foundation

struct Palette {
    
    struct Color {
        var red: UInt8
        var green: UInt8
        var blue: UInt8
        var alpha: UInt8
    }
    
    private let entries: [Color]
    
    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self.init(data)
    }
    
    init(contentsOf file: FileSystem.FileHandle) {
        let data = file.readDataToEndOfFile()
        self.init(data)
    }
    
    init(_ data: Data) {
        entries = data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Array<Color> in
            let raw = UnsafeRawPointer(bytes)
            let p = raw.bindMemory(to: Color.self, capacity: 256)
            let buf = UnsafeBufferPointer<Color>(start: p, count: 256)
            return Array(buf)
        }
    }
    
    init() { entries = Array(repeating: Color.white, count: 255) }
    
    subscript(index: Int) -> Color {
        return entries[index]
    }
    
    subscript(index: UInt8) -> Color {
        return entries[Int(index)]
    }
    
}

extension Palette.Color {
    static let white = Palette.Color(red: UInt8.max, green: UInt8.max, blue: UInt8.max, alpha: UInt8.max)
    static let black = Palette.Color(red: UInt8.min, green: UInt8.min, blue: UInt8.min, alpha: UInt8.max)
}

extension Palette {
    
    func mapIndices(_ imageIndices: Data, size: Size2D) -> Data {
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
    
    func mapIndicesFlipped(_ imageIndices: Data, size: Size2D) -> Data {
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
    
}
