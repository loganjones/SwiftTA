//
//  GafView.swift
//  HPIView
//
//  Created by Logan Jones on 5/27/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import AppKit

class GafView: NSImageView {
    
    func load(_ item: GafItem, from gafURL: URL, using palette: Palette) throws {
        
        Swift.print("Loading \(item.name) from \(gafURL.lastPathComponent)")
        Swift.print("  \(item.frames.count) frames")
        Swift.print("  \(item.size.width)x\(item.size.height)")
        Swift.print("  item.unknown_1: \(item.unknown1) | \(item.unknown1.binaryString)")
        Swift.print("  item.unknown_2: \(item.unknown2) | \(item.unknown2.binaryString)")
        
        guard let gaf = try? FileHandle(forReadingFrom: gafURL)
            else { throw LoadError.failedToOpenGAF }
        
        var i = 1
        for frameEntry in item.frames {
            
            gaf.seek(toFileOffset: frameEntry.offsetToFrameData)
            let frameInfo = gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
            
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
                let subframeOffsets = gaf.readArray(ofType: UInt32.self, count: Int(frameInfo.numberOfSubFrames))
                
                var j = 1
                for offset in subframeOffsets {
                    gaf.seek(toFileOffset: offset)
                    let subframeInfo = gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
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
            let frameInfo = gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
            
            if frameInfo.numberOfSubFrames == 0,
                let frameData = try? GafItem.read(frame: frameInfo, from: gaf) {
                self.image = NSImage(imageIndices: frameData,
                                     imageWidth: Int(frameInfo.width),
                                     imageHeight: Int(frameInfo.height),
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

extension NSImage {
    
    convenience init(imageIndices: Data, imageWidth: Int, imageHeight: Int, palette: Palette) {
        
        let size = (width: imageWidth, height: imageHeight)
        let cfdata = imageIndices.withUnsafeBytes { (indices: UnsafePointer<UInt8>) -> CFData in
            
            var pixelData = Data(count: size.width * size.height * 3)
            return pixelData.withUnsafeMutableBytes({ (pixels: UnsafeMutablePointer<UInt8>) -> CFData in
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
                return CFDataCreate(kCFAllocatorDefault, pixels, pixelData.count)
            })
            
        }
        let image = CGImage(width: size.width,
                            height: size.height,
                            bitsPerComponent: 8,
                            bitsPerPixel: 24,
                            bytesPerRow: size.width * 3,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: [],
                            provider: CGDataProvider(data: cfdata)!,
                            decode: nil,
                            shouldInterpolate: false,
                            intent: .defaultIntent)
        self.init(cgImage: image!, size: NSSize(width: size.width, height: size.height))
    }
    
    enum LoadError: Error {
        case failedToOpenGAF
        case noFrames
        case unsupportedFrameCompression(UInt8)
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
    
    init(contentsOf paletteURL: URL) {
        guard let data = try? Data(contentsOf: paletteURL)
            else { fatalError("No Palette Data!") }
        entries = data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Array<Color> in
            let raw = UnsafeRawPointer(bytes)
            let p = raw.bindMemory(to: Color.self, capacity: 256)
            let buf = UnsafeBufferPointer<Color>(start: p, count: 256)
            return Array(buf)
        }
    }
    
    subscript(index: Int) -> Color {
        return entries[index]
    }
    subscript(index: UInt8) -> Color {
        return entries[Int(index)]
    }
}
