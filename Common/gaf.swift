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
    
    var items: [GafItem]
    
    /// Parse & load a GAF archive into a list of GafItems.
    init<File>(withContentsOf gaf: File) throws
        where File: FileReadHandle
    {
        let fileHeader = try gaf.readValue(ofType: TA_GAF_HEADER.self)
        guard fileHeader.version == TA_GAF_VERSION_STANDARD else { throw LoadError.badGafVersion(fileHeader.version) }
        
        let entryOffsets = try gaf.readArray(ofType: UInt32.self, count: Int(fileHeader.numberOfEntries))
        items = try entryOffsets.map { entryOffset -> GafItem in
            
            gaf.seek(toFileOffset: entryOffset)
            let entryHeader = try gaf.readValue(ofType: TA_GAF_ENTRY.self)
            let frameEntries = try gaf.readArray(ofType: TA_GAF_FRAME_ENTRY.self, count: Int(entryHeader.numberOfFrames))
            
            return GafItem(name: entryHeader.name, frameOffsets: frameEntries.map { Int($0.offsetToFrameData) })
        }
        
        //try debugPrint(fileHeader, entryOffsets, gaf)
    }
    
    enum LoadError: Error {
        case failedToOpenGAF
        case badGafVersion(UInt32)
        case badGafEntry(UInt32)
    }
}

extension GafListing {
    
    subscript(name: String) -> GafItem? {
        get { return items.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) }
        set(new) {
            if let index = items.index(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                if let new = new {
                    items[index] = new
                }
                else {
                    items.remove(at: index)
                }
            }
            else {
                if let new = new {
                    items.append(new)
                }
            }
        }
    }
    
}

struct GafItem {
    var name: String
    var frameOffsets: [Int]
}

extension GafItem {
    var numberOfFrames: Int { return frameOffsets.count }
}

extension GafItem {
    
    func frameInfo<File>(ofFrameAtIndex index: Int, from gaf: File) throws -> TA_GAF_FRAME_DATA
        where File: FileReadHandle
    {
        gaf.seek(toFileOffset: frameOffsets[index])
        let frame = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
        return frame
    }
    
    func extractFrame<File>(index: Int, from gaf: File) throws -> Frame
        where File: FileReadHandle
    {
        guard frameOffsets.indexRange.contains(index) else { throw GafLoadError.outOfBoundsFrameIndex }
        return try GafItem.extractFrame(from: gaf, at: frameOffsets[index])
    }
    
    func extractFrames<File>(from gaf: File, useCache: Bool = true) throws -> [Frame]
        where File: FileReadHandle
    {
        return try GafItem.extractFrames(from: gaf, at: frameOffsets, useCache: useCache)
    }
    
}

extension GafItem {
    
    typealias Frame = (data: Data, size: Size2D, offset: Point2D)
    
    static func extractFrame<File>(from gaf: File, at offset: Int) throws -> Frame
        where File: FileReadHandle
    {
        gaf.seek(toFileOffset: offset)
        let frame = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
        
        if frame.numberOfSubFrames == 0 {
            let frameData = try decodeFrameData(frame, from: gaf)
            return (frameData, frame.size, frame.offset)
        }
        else {
            var out: Frame = (Data(count: frame.size.area), frame.size, frame.offset)
            
            gaf.seek(toFileOffset: frame.offsetToFrameData)
            let subframeOffsets = try gaf.readArray(ofType: UInt32.self, count: Int(frame.numberOfSubFrames))

            for offset in subframeOffsets {
                gaf.seek(toFileOffset: offset)
                let subframeHeader = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
                let subframeData = try decodeFrameData(subframeHeader, from: gaf)
                let subframe: Frame = (subframeData, subframeHeader.size, subframeHeader.offset)
                overlay(subframe, into: &out)
            }
            
            return out
        }
    }
    
    static func extractFrames<File>(from gaf: File, at offsets: [Int], useCache: Bool = true) throws -> [Frame]
        where File: FileReadHandle
    {
        var resultFrames: [Frame] = []
        var frameDataCache: [UInt32: Data] = [:]
        
        for offset in offsets {
            
            gaf.seek(toFileOffset: offset)
            let frame = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
        
            if frame.numberOfSubFrames == 0 {
                
                if useCache, let cached = frameDataCache[frame.offsetToFrameData] {
                    resultFrames.append( (cached, frame.size, frame.offset) )
                }
                else {
                    let frameData = try decodeFrameData(frame, from: gaf)
                    frameDataCache[frame.offsetToFrameData] = frameData
                    resultFrames.append( (frameData, frame.size, frame.offset) )
                }
                
            }
            else {
                var out: Frame = (Data(count: frame.size.area), frame.size, frame.offset)
                
                gaf.seek(toFileOffset: frame.offsetToFrameData)
                let subframeOffsets = try gaf.readArray(ofType: UInt32.self, count: Int(frame.numberOfSubFrames))
                
                for offset in subframeOffsets {
                    
                    gaf.seek(toFileOffset: offset)
                    let subframeHeader = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
                    
                    let subframeData: Data
                    if useCache, let cached = frameDataCache[subframeHeader.offsetToFrameData] {
                        subframeData = cached
                    }
                    else {
                        subframeData = try decodeFrameData(subframeHeader, from: gaf)
                        frameDataCache[subframeHeader.offsetToFrameData] = subframeData
                    }
                    
                    let subframe: Frame = (subframeData, subframeHeader.size, subframeHeader.offset)
                    overlay(subframe, into: &out)
                }
                
                resultFrames.append(out)
            }
            
        }
        
        return resultFrames
    }
    
    private static func decodeFrameData<File>(_ frame: TA_GAF_FRAME_DATA, from gaf: File) throws -> Data
        where File: FileReadHandle
    {
        guard frame.numberOfSubFrames == 0 else { throw GafLoadError.unexpectedSubframes }
        
        guard let compression = GafFrameCompressionMethod(rawValue: frame.compressionMethod)
            else { throw GafLoadError.unknownFrameCompression(frame.compressionMethod) }
        
        gaf.seek(toFileOffset: frame.offsetToFrameData)
        let frameData: Data
        
        switch compression {
        case .uncompressed:
            frameData = try gaf.readData(verifyingLength: frame.size.area)
        case .ta:
            let compressed = gaf.readData(ofLength: frame.size.area)
            frameData = decompressTaImageBits(compressed, decompressedSize: frame.size)
        default:
            throw GafLoadError.unsupportedFrameCompression(compression)
        }
        
        return frameData
    }
    
    private static func decompressTaImageBits(_ data: Data, decompressedSize size: Size2D) -> Data {
        
        let outputEnd = size.area
        var imageData = Data(count: outputEnd)
        imageData.withUnsafeMutableBytes { (output: UnsafeMutablePointer<UInt8>) -> Void in
            data.withUnsafeBytes { (input: UnsafePointer<UInt8>) in
                
                var inputLine = input
                var outputIndex = 0
                
                // Decompress one line at a time
                for _ in 0..<size.height {
                    
                    // Get the length of the compressed line
                    let lineLength = Int(inputLine.withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee })
                    
                    guard lineLength <= size.width*2 else {
                        print("!!! Warning, bad line length detected while decompressing GAF frame. [lineLength: \(lineLength)]")
                        break
                    }
                    
                    let lineBits = inputLine + MemoryLayout<UInt16>.size
                    
                    var inputLineIndex = 0
                    while inputLineIndex < lineLength {
                        
                        // The first byte tells us how to
                        // handle the next few pixels.
                        let controlByte = lineBits[inputLineIndex]
                        inputLineIndex += 1
                        
                        if (controlByte & 1) == 1 {
                            // A controlByte of 1 denotes a run of transparent pixels.
                            // The rest of the byte is the length of the run (ie. how many successive pixels are transparent).
                            let count = Int(controlByte >> 1)
                            outputIndex += count
                            guard outputIndex < outputEnd else { break }
                        }
                        else if (controlByte & 2) == 2 {
                            // A controlByte of 2 denotes a run of a specific color.
                            // The rest of the control byte is the length of the run (ie. how many successive pixels are the color),
                            // and the next input byte is the color to use for the run.
                            let colorIndex = lineBits[inputLineIndex]
                            inputLineIndex += 1
                            let count = min(Int(controlByte >> 2) + 1, outputEnd - outputIndex)
                            for i in 0..<count { output[outputIndex + i] = colorIndex }
                            outputIndex += count
                        }
                        else {
                            // A controlByte of aything else is a direct copy of some number of pixels.
                            // The rest of the control byte is the length of the copy (ie. how many successive pixels are copied).
                            let count = min(Int(controlByte >> 2) + 1, outputEnd - outputIndex)
                            for i in 0..<count { output[outputIndex + i] = lineBits[inputLineIndex + i] }
                            inputLineIndex += count
                            outputIndex += count
                        }
                        
                    }
                    
                    // Move to the next input line
                    inputLine += (MemoryLayout<UInt16>.size + lineLength)
                }
                
           }
        }
        
        return imageData
    }
    
    private static func overlay(_ source: Frame, into destination: inout Frame) {
        
        let offset = destination.offset - source.offset
        
        destination.data.withUnsafeMutableBytes() { (dstBuffer: UnsafeMutablePointer<UInt8>) in
            source.data.withUnsafeBytes() { (srcBuffer: UnsafePointer<UInt8>) in
                
                let dstStart_y = max(0, offset.y)
                let srcStart_y = offset.y < 0 ? -offset.y : 0
                
                let dstEnd_y = min(destination.size.height, offset.y+source.size.height)
                
                let dstStart_x = max(0, offset.x)
                let srcStart_x = offset.x < 0 ? -offset.x : 0
                
                let dstEnd_x = min(destination.size.width, offset.x+source.size.width)
                
                var dstLine = dstBuffer + (destination.size.width * dstStart_y)
                var srcLine = srcBuffer + (source.size.width * srcStart_y)
                
                for _ in dstStart_y..<dstEnd_y {
                    
                    var dstPixel = dstLine + dstStart_x
                    var srcPixel = srcLine + srcStart_x
                    
                    for _ in dstStart_x..<dstEnd_x {
                        let value = srcPixel.pointee
                        if value > 0 { dstPixel.pointee = value }
                        dstPixel += 1
                        srcPixel += 1
                    }
                    
                    dstLine += destination.size.width
                    srcLine += source.size.width
                }
                
            }
        }
        
        
    }
    
    enum GafLoadError: Error {
        case unknownFrameCompression(UInt8)
        case unsupportedFrameCompression(GafFrameCompressionMethod)
        case unexpectedSubframes
        case outOfBoundsFrameIndex
    }
}

extension TA_GAF_ENTRY {
    var name: String {
        let p = UnsafeRawPointer([nameBuffer]).assumingMemoryBound(to: CChar.self)
        return String(cString: p)
    }
}

extension TA_GAF_FRAME_DATA {
    var size: Size2D {
        return Size2D(width: Int(width), height: Int(height))
    }
    var offset: Point2D {
        return Point2D(x: Int(xOffset), y: Int(yOffset))
    }
}

private func debugPrint<File>(_ header: TA_GAF_HEADER, _ entryOffsets: [UInt32], _ gaf: File)
    throws where File: FileReadHandle
{
    Swift.print(
        """
        TA_GAF_HEADER {
          version: \(header.version)
          numberOfEntries: \(header.numberOfEntries)
          unknown_1: \(header.unknown_1)
        }
        """)
    
    for entryOffset in entryOffsets {
        
        gaf.seek(toFileOffset: entryOffset)
        let entryHeader = try gaf.readValue(ofType: TA_GAF_ENTRY.self)
        let frameEntries = try gaf.readArray(ofType: TA_GAF_FRAME_ENTRY.self, count: Int(entryHeader.numberOfFrames))
        
        Swift.print(
            """
                TA_GAF_ENTRY {
                  numberOfFrames: \(entryHeader.numberOfFrames)
                  unknown_1: \(entryHeader.unknown_1)
                  unknown_2: \(entryHeader.unknown_2)
                  name: \(entryHeader.name)
                }
            """)
        
        var i = 1
        for frameEntry in frameEntries {
            
            Swift.print(
                """
                        TA_GAF_FRAME_ENTRY [frame \(i)] {
                          offsetToFrameData: \(frameEntry.offsetToFrameData)
                          unknown_1: \(frameEntry.unknown_1)
                        }
                """)
            
            gaf.seek(toFileOffset: frameEntry.offsetToFrameData)
            let frameInfo = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
            
            let compression = GafFrameCompressionMethod(rawValue: frameInfo.compressionMethod) ?? .uncompressed
            
            Swift.print(
                """
                        TA_GAF_FRAME_DATA [frame \(i)] {
                          size: \(frameInfo.size) (\(frameInfo.size.area) pixels)
                          offset: \(frameInfo.offset)
                          unknown_1: \(frameInfo.unknown_1) | \(frameInfo.unknown_1.binaryString)
                          compression: \(compression)
                          numberOfSubFrames: \(frameInfo.numberOfSubFrames)
                          unknown_2: \(frameInfo.unknown_2)
                          offsetToFrameData: \(frameInfo.offsetToFrameData)
                          unknown_3: \(frameInfo.unknown_3) | \(frameInfo.unknown_3.binaryString)
                        }
                """)
            
            if frameInfo.numberOfSubFrames > 0 {
                gaf.seek(toFileOffset: frameInfo.offsetToFrameData)
                let subframeOffsets = try gaf.readArray(ofType: UInt32.self, count: Int(frameInfo.numberOfSubFrames))
                
                var j = 1
                for offset in subframeOffsets {
                    gaf.seek(toFileOffset: offset)
                    let subframeInfo = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
                    Swift.print(
                        """
                                    TA_GAF_FRAME_DATA [subframe \(j)] {
                                      size: \(subframeInfo.size) (\(subframeInfo.size.area) pixels)
                                      offset: \(subframeInfo.offset)
                                      unknown_1: \(subframeInfo.unknown_1) | \(subframeInfo.unknown_1.binaryString)
                                      compression: \(compression)
                                      numberOfSubFrames: \(subframeInfo.numberOfSubFrames)
                                      unknown_2: \(subframeInfo.unknown_2)
                                      offsetToFrameData: \(frameInfo.offsetToFrameData)
                                      unknown_3: \(subframeInfo.unknown_3) | \(subframeInfo.unknown_3.binaryString)
                                    }
                        """)
                    j += 1
                }
            }
            
            i += 1
        }
    }
}
