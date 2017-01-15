//
//  GAF.swift
//  HPIView
//
//  Created by Logan Jones on 12/4/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import AppKit

enum GafFrameCompressionMethod: UInt8 {
    /// This flag inndicates that the frame is uncompressed. OffsetToFrameData points
    /// to an array of Width x Height bytes.
    case uncompressed					= 0
    
    /// This flag inndicates that the frame is compressed using the compression
    /// scheme used for TA and Kingdoms
    case ta						= 1
    
    /// This flag inndicates that the frame is compressed using the compression
    /// scheme used for Kingdoms TAF files ending in "*_4444.TAF"
    case tak1					= 4
    
    /// This flag inndicates that the frame is compressed using the compression
    /// scheme used for Kingdoms TAF files ending in "*_1555.TAF"
    case tak2					= 5
}

class GafView: NSImageView {
    
    func load(image: GafImage, from gafURL: URL) throws {
        
        Swift.print("Loading \(image.name) from \(gafURL.lastPathComponent)")
        
        guard let gaf = try? FileHandle(forReadingFrom: gafURL)
            else { throw LoadError.failedToOpenGAF }
        
        var i = 1
        for frameEntry in image.frames {
            
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
        if let frameEntry = image.frames.first {
            
            gaf.seek(toFileOffset: frameEntry.offsetToFrameData)
            let frameInfo = gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
            
            if frameInfo.numberOfSubFrames == 0,
                let frameData = try? GafImage.read(frame: frameInfo, from: gaf) {
                self.image = NSImage(imageIndices: frameData,
                                     imageWidth: Int(frameInfo.width),
                                     imageHeight: Int(frameInfo.height))
            }
        }
    }
    
    enum LoadError: Error {
        case failedToOpenGAF
        case noFrames
        case unsupportedFrameCompression(UInt8)
    }
    
}

struct GafListing {
    
    // TEMP
    var name: String
    
    var items: [GafItem]
    
    /// Parse & load a GAF archive into a list of GafItems.
    init(withContentsOf gafURL: URL) throws {
        name = gafURL.lastPathComponent
        
        guard let gaf = try? FileHandle(forReadingFrom: gafURL)
            else { throw LoadError.failedToOpenGAF }
        
        let fileHeader = gaf.readValue(ofType: TA_GAF_HEADER.self)
        guard fileHeader.version == TA_GAF_VERSION_STANDARD else { throw LoadError.badGafVersion(fileHeader.version) }
        
        let entryOffsets = gaf.readArray(ofType: UInt32.self, count: Int(fileHeader.numberOfEntries))
        items = entryOffsets.map { entryOffset -> GafItem in
            gaf.seek(toFileOffset: entryOffset)
            let entryHeader = gaf.readValue(ofType: TA_GAF_ENTRY.self)
            let frameEntries = gaf.readArray(ofType: TA_GAF_FRAME_ENTRY.self, count: Int(entryHeader.numberOfFrames))
            return .image(GafImage(name: entryHeader.name, frames: frameEntries))
        }
    }
    
    enum LoadError: Error {
        case failedToOpenGAF
        case badGafVersion(UInt32)
    }
}

enum GafItem {
    case image(GafImage)
}

struct GafImage {
    var name: String
    var frames: [TA_GAF_FRAME_ENTRY]
}

extension GafImage {
    
    private typealias ImageSize = (width: Int, height: Int)
    
    static func read(frame: TA_GAF_FRAME_DATA, from gaf: FileHandle) throws -> Data {
        
        guard let compression = GafFrameCompressionMethod(rawValue: frame.compressionMethod)
            else { throw GafLoadError.unknownFrameCompression(frame.compressionMethod) }
        let size = ImageSize(width: Int(frame.width), height: Int(frame.height))
        
        gaf.seek(toFileOffset: frame.offsetToFrameData)
        switch compression {
        case .uncompressed:
            return gaf.readData(ofLength: size.width * size.height)
        case .ta:
            let compressed = gaf.readData(ofLength: size.width * size.height)
            return decompressTaImageBits(compressed, decompressedSize: size)
        default:
            throw GafLoadError.unsupportedFrameCompression(compression)
        }
    }
    
    private static func decompressTaImageBits(_ data: Data, decompressedSize size: ImageSize) -> Data {
    
        var imageData = Data(count: size.width * size.height)
        imageData.withUnsafeMutableBytes { (output: UnsafeMutablePointer<UInt8>) -> Void in
            data.withUnsafeBytes { (input: UnsafePointer<UInt8>) in
                
                var pDest = output
                var pFileBuffer = input
                
                // Decompress into pImageBits one line at a time
                for _ in 0..<size.height {
                    
                    // Get the length of the compressed line
                    let lineLength = Int(pFileBuffer.withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee })
                    let lineBits = pFileBuffer + MemoryLayout<UInt16>.size
                    
                    // A new line has started
                    var texindex = 0
                    
                    var pos = 0
                    while pos < lineLength {
                        
                        // The first byte is the mask
                        let byteMask = lineBits[pos]
                        pos += 1
                        
                        // Check for transparent pixels
                        if (byteMask & 0x01) == 0x01 {
                            let count = Int(byteMask >> 1)
                            texindex += count
                        }
                        // Check for a color run
                        else if (byteMask & 0x02) == 0x02 {
                            let colorIndex = lineBits[pos]
                            pos += 1
                            let count = Int(byteMask >> 2) + 1
                            for i in 0..<count { pDest[texindex + i] = colorIndex }
                            texindex += count
                        }
                        // Just take the next count pixels
                        else {
                            let count = Int(byteMask >> 2) + 1
                            for i in 0..<count { pDest[texindex + i] = lineBits[pos + i] }
                            pos += count
                            texindex += count
                        }
                        
                    }  // End for( line length )
                    
                    // Move the destination image to the next line
                    pDest += size.width
                    
                    // Move to the next line
                    pFileBuffer += (MemoryLayout<UInt16>.size + lineLength)
                }
            }
        }
        
        return imageData
    }
    
    enum GafLoadError: Error {
        case unknownFrameCompression(UInt8)
        case unsupportedFrameCompression(GafFrameCompressionMethod)
    }
}

extension GafItem {
    
    /// Every GafItem has a name.
    /// This name uniquely identifies the item in its containing GAF.
    var name: String {
        switch self {
        case .image(let image): return image.name
        }
    }
    
}

extension TA_GAF_ENTRY {
    var name: String {
        let p = UnsafeRawPointer([nameBuffer]).assumingMemoryBound(to: CChar.self)
        return String(cString: p)
    }
}

extension NSImage {
    
    convenience init(imageIndices: Data, imageWidth: Int, imageHeight: Int, palette: Palette = MainPalette) {
        
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
    
    init() {
        guard let url = Bundle.main.url(forResource: "PALETTE", withExtension: "PAL")
            else { fatalError("No Palette!") }
        guard let data = try? Data(contentsOf: url)
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

let MainPalette = Palette()
