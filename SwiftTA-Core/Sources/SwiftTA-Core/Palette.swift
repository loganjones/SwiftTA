//
//  Palette.swift
//  TAassets
//
//  Created by Logan Jones on 3/12/18.
//  Copyright © 2018 SwiftTA. All rights reserved.
//

import Foundation

public struct Palette {
    
    private var colors: [Color]
    
    public struct Color {
        public var red: UInt8
        public var green: UInt8
        public var blue: UInt8
        public var alpha: UInt8
    }
    
    public init(_ colors: [Color]) {
        self.colors = colors
    }
    
    public init() { colors = Array(repeating: Color.white, count: 255) }
    
    public subscript(index: Int) -> Color {
        return colors[index]
    }
    
    public subscript(index: UInt8) -> Color {
        return colors[Int(index)]
    }
    
}

// MARK:- PAL Support

public extension Palette {
    
    init(palContentsOf url: URL, applyStandardTransparencies: Bool = true) throws {
        let data = try Data(contentsOf: url)
        self.init(palData: data)
    }
    
    init<File>(palContentsOf file: File) where File: FileReadHandle {
        let data = file.readDataToEndOfFile()
        self.init(palData: data)
    }
    
    init(palData data: Data) {
        colors = data.withUnsafeBytes { Array($0.bindMemory(to: Color.self)) }
        
        // The TA .pal files have every color with a 0 alpha value ಠ_ಠ
        for i in colors.indices {
            colors[i].alpha = 255
        }
    }
    
}

// MARK:- Simple Color Accessors

public extension Palette.Color {
    static let white = Palette.Color(red: UInt8.max, green: UInt8.max, blue: UInt8.max, alpha: UInt8.max)
    static let black = Palette.Color(red: UInt8.min, green: UInt8.min, blue: UInt8.min, alpha: UInt8.max)
    static let shadow = Palette.Color(red: 0, green: 0, blue: 0, alpha: 100)
}

public extension Palette {
    
    static let shadow: Palette = {
        var colors = Array(repeating: Color.shadow, count: 255)
        colors[0].alpha = 0
        colors[9].alpha = 0
        return Palette(colors)
    }()
    
}

// MARK:- Chorma Keys (Transparency)

public extension Palette {
    
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

public extension Palette {
    
    func mapIndicesRgb(_ imageIndices: Data, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 3)
        pixelData.withUnsafeMutableBytes() { (destination: UnsafeMutableRawBufferPointer) in
            imageIndices.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                var destinationIndex = destination.startIndex
                var sourceIndex = source.startIndex
                for _ in 0..<(size.width * size.height) {
                    let colorIndex = source[sourceIndex]
                    destination[destinationIndex+0] = palette[colorIndex].red
                    destination[destinationIndex+1] = palette[colorIndex].green
                    destination[destinationIndex+2] = palette[colorIndex].blue
                    destinationIndex += 3
                    sourceIndex += 1
                }
            }
        }
        return pixelData
    }
    
    func mapIndicesRgbFlipped(_ imageIndices: Data, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 3)
        pixelData.withUnsafeMutableBytes() { (destination: UnsafeMutableRawBufferPointer) in
            imageIndices.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                var destinationIndex = destination.endIndex - (size.width * 3)
                var sourceIndex = source.startIndex
                for _ in 0..<size.height {
                    for _ in 0..<size.width {
                        let colorIndex = source[sourceIndex]
                        destination[destinationIndex+0] = palette[colorIndex].red
                        destination[destinationIndex+1] = palette[colorIndex].green
                        destination[destinationIndex+2] = palette[colorIndex].blue
                        destinationIndex += 3
                        sourceIndex += 1
                    }
                    destinationIndex -= (size.width * 3) * 2
                }
            }
        }
        return pixelData
    }
    
    func mapIndicesRgba(_ imageIndices: Data, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 4)
        pixelData.withUnsafeMutableBytes() { (destination: UnsafeMutableRawBufferPointer) in
            imageIndices.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                var destinationIndex = destination.startIndex
                var sourceIndex = source.startIndex
                for _ in 0..<(size.width * size.height) {
                    let colorIndex = source[sourceIndex]
                    destination[destinationIndex+0] = palette[colorIndex].red
                    destination[destinationIndex+1] = palette[colorIndex].green
                    destination[destinationIndex+2] = palette[colorIndex].blue
                    destination[destinationIndex+3] = palette[colorIndex].alpha
                    destinationIndex += 4
                    sourceIndex += 1
                }
            }
        }
        return pixelData
    }
    
    func mapIndicesRgbaFlipped(_ imageIndices: Data, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 4)
        pixelData.withUnsafeMutableBytes() { (destination: UnsafeMutableRawBufferPointer) in
            imageIndices.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                var destinationIndex = destination.endIndex - (size.width * 4)
                var sourceIndex = source.startIndex
                for _ in 0..<size.height {
                    for _ in 0..<size.width {
                        let colorIndex = source[sourceIndex]
                        destination[destinationIndex+0] = palette[colorIndex].red
                        destination[destinationIndex+1] = palette[colorIndex].green
                        destination[destinationIndex+2] = palette[colorIndex].blue
                        destination[destinationIndex+3] = palette[colorIndex].alpha
                        destinationIndex += 4
                        sourceIndex += 1
                    }
                    destinationIndex -= (size.width * 4) * 2
                }
            }
        }
        return pixelData
    }
    
    func makeRgba(withColorAtIndex colorIndex: UInt8, size: Size2<Int>) -> Data {
        let palette = self
        var pixelData = Data(count: size.area * 4)
        pixelData.withUnsafeMutableBytes() { (destination: UnsafeMutableRawBufferPointer) in
            var destinationIndex = destination.startIndex
            for _ in 0..<(size.width * size.height) {
                destination[destinationIndex+0] = palette[colorIndex].red
                destination[destinationIndex+1] = palette[colorIndex].green
                destination[destinationIndex+2] = palette[colorIndex].blue
                destination[destinationIndex+3] = palette[colorIndex].alpha
                destinationIndex += 4
            }
        }
        return pixelData
    }
    
}
