//
//  GafView.swift
//  HPIView
//
//  Created by Logan Jones on 5/27/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import AppKit

class GafView: NSImageView {
    
    func load<File>(_ item: GafItem, from gaf: File, using palette: Palette) throws
        where File: FileReadHandle
    {
        
        Swift.print("Loading \(item.name) from \(gaf.fileName)")
        Swift.print("  \(item.frames.count) frames")
        Swift.print("  \(item.size.width)x\(item.size.height)")
        Swift.print("  item.unknown_1: \(item.unknown1) | \(item.unknown1.binaryString)")
        Swift.print("  item.unknown_2: \(item.unknown2) | \(item.unknown2.binaryString)")
        
        var i = 1
        for frameEntry in item.frames {
            
            gaf.seek(toFileOffset: frameEntry.offsetToFrameData)
            let frameInfo = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
            
            let compression = GafFrameCompressionMethod(rawValue: frameInfo.compressionMethod) ?? .uncompressed
            
            Swift.print("  frame \(i):")
            Swift.print("    \(frameInfo.width)x\(frameInfo.height)")
            Swift.print("    compression: \(compression)")
            Swift.print("    sub-frames: \(frameInfo.numberOfSubFrames)")
            Swift.print("    entry.unknown_1: \(frameEntry.unknown_1) | \(frameEntry.unknown_1.binaryString)")
            Swift.print("    info.unknown_1: \(frameInfo.unknown_1) | \(frameInfo.unknown_1.binaryString)")
            Swift.print("    info.unknown_2: \(frameInfo.unknown_2)")
            Swift.print("    info.unknown_3: \(frameInfo.unknown_3) | \(frameInfo.unknown_3.binaryString)")
            
            if frameInfo.numberOfSubFrames > 0 {
                gaf.seek(toFileOffset: frameInfo.offsetToFrameData)
                let subframeOffsets = try gaf.readArray(ofType: UInt32.self, count: Int(frameInfo.numberOfSubFrames))
                
                var j = 1
                for offset in subframeOffsets {
                    gaf.seek(toFileOffset: offset)
                    let subframeInfo = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
                    Swift.print("    subframe \(j):")
                    Swift.print("      \(subframeInfo.width)x\(subframeInfo.height)")
                    Swift.print("      compression: \(compression)")
                    Swift.print("      sub-frames: \(subframeInfo.numberOfSubFrames)")
                    Swift.print("      info.unknown_1: \(subframeInfo.unknown_1) | \(subframeInfo.unknown_1.binaryString)")
                    Swift.print("      info.unknown_2: \(subframeInfo.unknown_2)")
                    Swift.print("      info.unknown_3: \(subframeInfo.unknown_3) | \(subframeInfo.unknown_3.binaryString)")
                    j += 1
                }
            }
            
            i += 1
        }
        
        self.image = nil
        if let frameEntry = item.frames.first {
            
            gaf.seek(toFileOffset: frameEntry.offsetToFrameData)
            let frameInfo = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
            
            if frameInfo.numberOfSubFrames == 0,
                let frameData = try? GafItem.read(frame: frameInfo, from: gaf) {
                self.image = NSImage(imageIndices: frameData,
                                     size: frameInfo.size,
                                     palette: palette)
            }
        }
    }
    
    enum LoadError: Error {
        case failedToOpenGAF
        case noFrames
        case unsupportedFrameCompression(UInt8)
    }
    
}

extension TA_GAF_FRAME_DATA {
    var size: Size2D {
        return Size2D(width: Int(width), height: Int(height))
    }
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

extension CGImage {
    
    static func createWith(imageIndices: Data, size: Size2D, palette: Palette, isFlipped: Bool = false) -> CGImage {
        let data = isFlipped ? palette.mapIndicesFlipped(imageIndices, size: size) : palette.mapIndices(imageIndices, size: size)
        return CGImage(
            width: size.width,
            height: size.height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: size.width * 3,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: [],
            provider: CGDataProvider(data: data as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent)!
    }
    
}

extension NSImage {
    
    convenience init(imageIndices: Data, size: Size2D, palette: Palette) {
        let image = CGImage.createWith(imageIndices: imageIndices, size: size, palette: palette)
        self.init(cgImage: image, size: NSSize(width: size.width, height: size.height))
    }
    
}

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
