//
//  GAF.swift
//  HPIView
//
//  Created by Logan Jones on 12/4/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation
#if canImport(Ctypes)
import Ctypes
#endif

enum GafFrameEncoding: UInt8 {
    /// The data at `offsetToFrameData` is a raw collection of `width` x `height` bytes.
    /// Once read, the result is an 8-bit per pixel paletted image.
    case taUncompressed         = 0
    
    /// The data at `offsetToFrameData` is a RLE collection of bytes.
    /// When decoded, the result is an 8-bit per pixel paletted image.
    case taRunLengthEncoding    = 1
    
    /// The data at `offsetToFrameData` is a raw collection of `width` x `height` x 2 bytes.
    /// Once read, the result is a 16-bit per pixel image with a pixel format of 4444 (4 bits per component).
    case takUncompressed4444    = 4
    
    /// The data at `offsetToFrameData` is a raw collection of `width` x `height` x 2 bytes.
    /// Once read, the result is a 16-bit per pixel image with a pixel format of 1555 (5 bits per RGB component, 1 bit alpha).
    case takUncompressed1555    = 5
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
            if let index = items.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
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
        guard frameOffsets.indices.contains(index) else { throw GafLoadError.outOfBoundsFrameIndex }
        return try GafItem.extractFrame(from: gaf, at: frameOffsets[index])
    }
    
    func extractFrames<File>(from gaf: File, useCache: Bool = true) throws -> [Frame]
        where File: FileReadHandle
    {
        return try GafItem.extractFrames(from: gaf, at: frameOffsets, useCache: useCache)
    }
    
}

extension GafItem {
    
    /// The raw data of a GAF frame
    struct Frame {
        var data: Data
        var size: Size2<Int>
        var offset: Point2<Int>
        var format: PixelFormat
        
        enum PixelFormat {
            /// Each pixel is an 8-bit index into an associated palette.
            case paletteIndex
            /// Each pixel is a 16-bit color value (4 bits per component).
            case raw4444
            /// Each pixel is a 16-bit color value (5 bits per RGB component, 1 bit alpha).
            case raw1555
        }
    }
    
    static func extractFrame<File>(from gaf: File, at offset: Int) throws -> Frame
        where File: FileReadHandle
    {
        gaf.seek(toFileOffset: offset)
        let frame = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
        
        if frame.numberOfSubFrames == 0 {
            let frameData = try decodeFrameData(frame, from: gaf)
            return frameData
        }
        else {
            guard let encoding = GafFrameEncoding(rawValue: frame.encoding)
                else { throw GafLoadError.unknownFrameEncoding(frame.encoding) }
            
            var out = Frame(Data(count: frame.size.area), frame.size, frame.offset, encoding.pixelFormat)
            
            gaf.seek(toFileOffset: frame.offsetToFrameData)
            let subframeOffsets = try gaf.readArray(ofType: UInt32.self, count: Int(frame.numberOfSubFrames))

            for offset in subframeOffsets {
                gaf.seek(toFileOffset: offset)
                let subframeHeader = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
                let subframe = try decodeFrameData(subframeHeader, from: gaf)
                overlay(subframe, into: &out)
            }
            
            return out
        }
    }
    
    static func extractFrames<File>(from gaf: File, at offsets: [Int], useCache: Bool = true) throws -> [Frame]
        where File: FileReadHandle
    {
        var resultFrames: [Frame] = []
        var frameDataCache: [UInt32: Frame] = [:]
        
        for offset in offsets {
            
            gaf.seek(toFileOffset: offset)
            let frame = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
        
            if frame.numberOfSubFrames == 0 {
                
                if useCache, let cached = frameDataCache[frame.offsetToFrameData] {
                    resultFrames.append(cached)
                }
                else {
                    let frameData = try decodeFrameData(frame, from: gaf)
                    frameDataCache[frame.offsetToFrameData] = frameData
                    resultFrames.append(frameData)
                }
                
            }
            else {
                guard let encoding = GafFrameEncoding(rawValue: frame.encoding)
                    else { throw GafLoadError.unknownFrameEncoding(frame.encoding) }
                
                var out = Frame(Data(count: frame.size.area), frame.size, frame.offset, encoding.pixelFormat)
                
                gaf.seek(toFileOffset: frame.offsetToFrameData)
                let subframeOffsets = try gaf.readArray(ofType: UInt32.self, count: Int(frame.numberOfSubFrames))
                
                for offset in subframeOffsets {
                    
                    gaf.seek(toFileOffset: offset)
                    let subframeHeader = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
                    
                    let subframe: Frame
                    if useCache, let cached = frameDataCache[subframeHeader.offsetToFrameData] {
                        subframe = cached
                    }
                    else {
                        subframe = try decodeFrameData(subframeHeader, from: gaf)
                        frameDataCache[subframeHeader.offsetToFrameData] = subframe
                    }
                    
                    overlay(subframe, into: &out)
                }
                
                resultFrames.append(out)
            }
            
        }
        
        return resultFrames
    }
    
    private static func decodeFrameData<File>(_ frame: TA_GAF_FRAME_DATA, from gaf: File) throws -> Frame
        where File: FileReadHandle
    {
        guard frame.numberOfSubFrames == 0 else { throw GafLoadError.unexpectedSubframes }
        
        guard let encoding = GafFrameEncoding(rawValue: frame.encoding)
            else { throw GafLoadError.unknownFrameEncoding(frame.encoding) }
        
        gaf.seek(toFileOffset: frame.offsetToFrameData)
        let frameData: Data
        
        switch encoding {
        case .taUncompressed:
            frameData = try gaf.readData(verifyingLength: frame.size.area)
        case .takUncompressed4444, .takUncompressed1555:
            frameData = try gaf.readData(verifyingLength: frame.size.area * 2)
        case .taRunLengthEncoding:
            let compressed = gaf.readData(ofLength: frame.size.area * 2)
            frameData = decompressTaImageBits(compressed, decompressedSize: frame.size)
        }
        
        return Frame(frameData, frame.size, frame.offset, encoding.pixelFormat)
    }
    
    private static func decompressTaImageBits(_ data: Data, decompressedSize size: Size2<Int>) -> Data {
        
        var imageData = Data(count: size.area)
        imageData.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) -> Void in
            data.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
                
                var inputLine = input.startIndex
                var outputIndex = output.startIndex
                
                // Decompress one line at a time
                for lineNo in 0..<size.height {
                    
                    // Get the length of the compressed line
                    guard inputLine+2 < input.endIndex else { break }
                    let byte1 = input[inputLine + 0]
                    let byte2 = input[inputLine + 1]
                    let lineLength = Int((UInt16(byte2) << 8) | UInt16(byte1))
                    
                    guard lineLength <= size.width*2 else {
                        print("!!! Warning, bad line length detected while decompressing GAF frame. [line: \(lineNo+1), length: \(lineLength)]")
                        break
                    }
                    
                    let lineBits = inputLine + MemoryLayout<UInt16>.size
                    
                    var inputLineIndex = 0
                    while inputLineIndex < lineLength && (lineBits + inputLineIndex) < input.endIndex && outputIndex < output.endIndex {
                        
                        // The first byte tells us how to
                        // handle the next few pixels.
                        let controlByte = input[lineBits + inputLineIndex]
                        inputLineIndex += 1
                        
                        if (controlByte & 1) == 1 {
                            // A controlByte of 1 denotes a run of transparent pixels.
                            // The rest of the byte is the length of the run (ie. how many successive pixels are transparent).
                            let count = Int(controlByte >> 1)
                            outputIndex += count
                        }
                        else if (controlByte & 2) == 2 {
                            // A controlByte of 2 denotes a run of a specific color.
                            // The rest of the control byte is the length of the run (ie. how many successive pixels are the color),
                            // and the next input byte is the color to use for the run.
                            guard (lineBits + inputLineIndex) < input.endIndex else { print("!!! GAF decoding ended prematurely at line \(lineNo+1) of \(size.height)"); break }
                            let colorIndex = input[lineBits + inputLineIndex]
                            inputLineIndex += 1
                            let count = min(Int(controlByte >> 2) + 1, output.endIndex - outputIndex)
                            for i in 0..<count { output[outputIndex + i] = colorIndex }
                            outputIndex += count
                        }
                        else {
                            // A controlByte of aything else is a direct copy of some number of pixels.
                            // The rest of the control byte is the length of the copy (ie. how many successive pixels are copied).
                            let count = min(Int(controlByte >> 2) + 1, output.endIndex - outputIndex, input.endIndex - (lineBits + inputLineIndex))
                            for i in 0..<count { output[outputIndex + i] = input[lineBits + inputLineIndex + i] }
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
        
        guard source.format == destination.format else {
            print("!!! Subframes with differing pixel formats not supported.")
            return
        }
        
        let offset = destination.offset &- source.offset
        let pixelLength = source.format.pixelLength
        
        destination.data.withUnsafeMutableBytes() { (dstBuffer: UnsafeMutableRawBufferPointer) in
            source.data.withUnsafeBytes() { (srcBuffer: UnsafeRawBufferPointer) in
                
                let dstStart_y = max(0, offset.y)
                let srcStart_y = offset.y < 0 ? -offset.y : 0
                
                let dstEnd_y = min(destination.size.height, offset.y+source.size.height)
                
                let dstStart_x = max(0, offset.x)
                let srcStart_x = offset.x < 0 ? -offset.x : 0
                
                let dstEnd_x = min(destination.size.width, offset.x+source.size.width)
                
                var dstLine = destination.size.width * dstStart_y
                var srcLine = source.size.width * srcStart_y
                
                for _ in dstStart_y..<dstEnd_y {
                    
                    var dstPixel = dstLine + dstStart_x
                    var srcPixel = srcLine + srcStart_x
                    
                    for _ in dstStart_x..<dstEnd_x {
                        if pixelLength == 1 {
                            let value = srcBuffer[srcPixel]
                            if value > 0 { dstBuffer[dstPixel] = value }
                        }
                        else {
                            for i in 0..<pixelLength {
                                dstBuffer[dstPixel+i] = srcBuffer[srcPixel+i]
                            }
                        }
                        dstPixel += pixelLength
                        srcPixel += pixelLength
                    }
                    
                    dstLine += destination.size.width * pixelLength
                    srcLine += source.size.width * pixelLength
                }
                
            }
        }
        
        
    }
    
    enum GafLoadError: Error {
        case unknownFrameEncoding(UInt8)
        case unexpectedSubframes
        case outOfBoundsFrameIndex
    }
}

extension GafItem.Frame {
    
    init(_ data: Data, _ size: Size2<Int>, _ offset: Point2<Int>, _ format: PixelFormat = .paletteIndex) {
        self.data = data
        self.size = size
        self.offset = offset
        self.format = format
    }
    
}

extension GafItem.Frame.PixelFormat {
    
    var pixelLength: Int {
        switch self {
        case .paletteIndex:
            return 1
        case .raw4444, .raw1555:
            return 2
        }
    }
    
}

extension GafFrameEncoding {
    
    var pixelFormat: GafItem.Frame.PixelFormat {
        switch self {
        case .taRunLengthEncoding, .taUncompressed:
            return .paletteIndex
        case .takUncompressed4444:
            return .raw4444
        case .takUncompressed1555:
            return .raw1555
        }
    }
    
    var pixelLength: Int {
        switch self {
        case .taRunLengthEncoding, .taUncompressed:
            return 1
        case .takUncompressed4444, .takUncompressed1555:
            return 2
        }
    }
    
}

extension TA_GAF_ENTRY {
    var name: String {
        var t = nameBuffer
        let buffer = UnsafeBufferPointer(start: &t, count: MemoryLayout.size(ofValue: t))
        guard let raw = UnsafeRawPointer(buffer.baseAddress) else { return "" }
        return String(cString: raw.assumingMemoryBound(to: CChar.self))
    }
}

extension TA_GAF_FRAME_DATA {
    var size: Size2<Int> {
        return Size2(Int(width), Int(height))
    }
    var offset: Point2<Int> {
        return Point2(Int(xOffset), Int(yOffset))
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
            
            let encoding = GafFrameEncoding(rawValue: frameInfo.encoding) ?? .taUncompressed
            
            Swift.print(
                """
                        TA_GAF_FRAME_DATA [frame \(i)] {
                          size: \(frameInfo.size) (\(frameInfo.size.area) pixels)
                          offset: \(frameInfo.offset)
                          unknown_1: \(frameInfo.unknown_1) | \(frameInfo.unknown_1.binaryString)
                          encoding: \(encoding)
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
                                      encoding: \(encoding)
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

// MARK:- Pixel Format Conversion

func decompose(argb4444 pixel: UInt16) -> (red: Double, green: Double, blue: Double, alpha: Double) {
    
    let alphaValue = (pixel & 0xF000) >> 12
    let redValue = (pixel & 0x0F00) >> 8
    let greenValue = (pixel & 0x00F0) >> 4
    let blueValue = (pixel & 0x000F) >> 0
    
    let divisor = Double(0x000F)
    
    return (Double(redValue) / divisor, Double(greenValue) / divisor, Double(blueValue) / divisor, Double(alphaValue) / divisor)
}

func decompose(argb1555 pixel: UInt16) -> (red: Double, green: Double, blue: Double, alpha: Double) {
    
    let alphaValue = (pixel & 0x8000) >> 15
    let redValue = (pixel & 0x7C00) >> 10
    let greenValue = (pixel & 0x03E0) >> 5
    let blueValue = (pixel & 0x001F) >> 0
    
    let divisor = Double(0x001F)
    
    return (Double(redValue) / divisor, Double(greenValue) / divisor, Double(blueValue) / divisor, Double(alphaValue))
}

extension Palette.Color {
    
    init(_ v: (red: Double, green: Double, blue: Double, alpha: Double)) {
        let magnitude = Double(UInt8.max)
        red = UInt8(v.red * magnitude)
        green = UInt8(v.green * magnitude)
        blue = UInt8(v.blue * magnitude)
        alpha = UInt8(v.alpha * magnitude)
    }
    
    init(argb4444 pixel: UInt16) {
        alpha = UInt8((pixel & 0xF000) >> 8)
        red = UInt8((pixel & 0x0F00) >> 4)
        green = UInt8((pixel & 0x00F0))
        blue = UInt8((pixel & 0x000F) << 4)
    }
    
}

extension GafItem.Frame {
    
    func convertToRGBA() throws -> Data {
        switch format {
            
        case .paletteIndex:
            throw ConvertError.palettedFrameUnsupported
            
        case .raw4444:
            let output = UnsafeMutablePointer<Palette.Color>.allocate(capacity: size.area)
            defer { output.deallocate() }
            data.withUnsafeBytes() {
                let input = $0.bindMemory(to: UInt16.self)
                for i in 0..<size.area {
                    output[i] = Palette.Color(argb4444: input[i])
                }
            }
            return Data(bytes: output, count: size.area * 4)
            
        case .raw1555:
            let output = UnsafeMutablePointer<Palette.Color>.allocate(capacity: size.area)
            defer { output.deallocate() }
            data.withUnsafeBytes() {
                let input = $0.bindMemory(to: UInt16.self)
                for i in 0..<size.area {
                    output[i] = Palette.Color(decompose(argb1555: input[i]))
                }
            }
            return Data(bytes: output, count: size.area * 4)

        }
    }
    
    enum ConvertError: Error {
        case palettedFrameUnsupported
    }
    
}
