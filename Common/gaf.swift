//
//  GAF.swift
//  HPIView
//
//  Created by Logan Jones on 12/4/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation

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
