//
//  pcx.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation
#if canImport(Ctypes)
import Ctypes
#endif

enum Pcx { }

// MARK:- Pcx Decoding

extension Pcx {
    
    static func extractImage<File>(contentsOf pcxFile: File) throws -> (data: Data, size: Size2<Int>)
        where File: FileReadHandle
    {
        // Read in the PCX header and check that the `identifer` is what we expect.
        // This is the full extenet to doing any compatibility checks;
        // from here on, we assume this is a standard TA PCX file.
        // (ie. 8-bit per pixel, VGA palette at end of file, etc)
        pcxFile.seek(toFileOffset: 0)
        let header = try pcxFile.readValue(ofType: PCX_HEADER.self)
        guard header.identifier == PCX_IDENTIFIER else { throw DecodeError.badIdentifier(header.identifier) }
        
        // Sanity checks
        let size = header.imageSize
        guard size.width > 0 && size.height > 0 else { throw DecodeError.badImageSize(header) }
        
        // Make a buffer for the final decoded image.
        let pixelBufferLength = size.width * size.height * 3
        let pixelBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelBufferLength)
        let output = Data(bytesNoCopy: pixelBuffer, count: pixelBufferLength, deallocator: .custom({ (bytes, length) in bytes.deallocate() }))
        
        // Read in the rest of the file and get decodin'
        let rawData = pcxFile.readDataToEndOfFile()
        try rawData.withUnsafeBytes { (p: UnsafeRawBufferPointer) throws in
            
            // Do a simple check for the end-of-file palette.
            // If it's not there, bail; we don't support any other type of PCX.
            guard rawData.count > 769, p[rawData.count - 769] == 0x0C
                else { throw DecodeError.noPalette }
            
            // Decode the PCX bytes into our `pixelBuffer`.
            decode(header, bytes: p, palette: p[(rawData.count - 768)...], into: pixelBuffer)
        }
        
        return (output, size)
    }
    
    static func extractPalette<File>(contentsOf pcxFile: File) throws -> Palette
        where File: FileReadHandle
    {
        guard pcxFile.fileSize > MemoryLayout<PCX_HEADER>.size + 1 + 768 else {
            throw DecodeError.noPalette
        }
        
        pcxFile.seek(toFileOffset: pcxFile.fileSize - 769)
        let data = pcxFile.readDataToEndOfFile()
        
        guard data.count == 769 && data[0] == 0x0C else {
            throw DecodeError.noPalette
        }
        
        var colors = [Palette.Color](repeating: .white, count: 256)
        
        data.withUnsafeBytes() { (bytes: UnsafeRawBufferPointer) in
            var pcxIndex = 1
            for colorsIndex in 0..<256 {
                colors[colorsIndex].red     = bytes[pcxIndex + 0]
                colors[colorsIndex].green   = bytes[pcxIndex + 1]
                colors[colorsIndex].blue    = bytes[pcxIndex + 2]
                pcxIndex += 3
            }
        }
        
        return Palette(colors)
    }
    
    /**
     Decodes the RLE compressed data in `bytes` using the provided `palette` and `header` information.
     */
    private static func decode(_ header: PCX_HEADER, bytes: UnsafeRawBufferPointer, palette: UnsafeRawBufferPointer.SubSequence,
                        into pixelBuffer: UnsafeMutablePointer<UInt8>) {
        
        let size = header.imageSize
        
        var pcxIndex = bytes.startIndex
        var line = pixelBuffer
        for _ in 0..<size.height {
            var x = 0
            var pixelX = 0
            while x < size.width {
                let byte = bytes[pcxIndex]
                pcxIndex += 1
                if 0xC0 == (0xC0 & byte) {
                    let count = 0x3F & byte
                    let byte2 = bytes[pcxIndex]
                    pcxIndex += 1
                    for _ in 0..<count {
                        setPixel(line + pixelX, to: byte2, palette: palette)
                        x += 1
                        pixelX += 3
                    }
                }
                else {
                    setPixel(line + pixelX, to: byte, palette: palette)
                    x += 1
                    pixelX += 3
                }
            }
            line += Int(header.bytesPerLine * 3)
        }
    }
    
    enum DecodeError: Error {
        case badIdentifier(UInt8)
        case badImageSize(PCX_HEADER)
        case noPalette
        case failedToCreateData
        case failedToCreateProvider
        case failedToCreateImage
    }
    
}

private func setPixel(_ pixel: UnsafeMutablePointer<UInt8>, to colorIndex: UInt8, palette: UnsafeRawBufferPointer.SubSequence) {
    let colorOffset = Int(colorIndex) * 3
    let paletteOffset = palette.startIndex + colorOffset
    pixel[0] = palette[paletteOffset + 0]
    pixel[1] = palette[paletteOffset + 1]
    pixel[2] = palette[paletteOffset + 2]
}

// MARK:- Analysis (Image or Palette)

extension Pcx {
    
    enum Analysis {
        case image
        case palette
    }
    
    static func analyze<File>(contentsOf pcxFile: File) throws -> Analysis
        where File: FileReadHandle
    {
        // At minimum, we only support paletted PCX files with the palette stuck on at the end of the file.
        // If the file is not big enough to hold at least the PCX header, the palette marker, and the palette,
        // then that is an easy check before we have to read anything
        guard pcxFile.fileSize > MemoryLayout<PCX_HEADER>.size + 1 + 768 else {
            throw DecodeError.noPalette
        }
        
        pcxFile.seek(toFileOffset: 0)
        let header = try pcxFile.readValue(ofType: PCX_HEADER.self)
        
        pcxFile.seek(toFileOffset: pcxFile.fileSize - 769)
        let paletteMarker = try pcxFile.readValue(ofType: UInt8.self)
        
        // The end-of-file palette must be preceded by this marker.
        guard paletteMarker == 0x0C else {
            throw DecodeError.noPalette
        }
        
        // The TA palette.pcx is missing a valid PCX_IDENTIFIER.
        // We will assume that any PCX missing this is a palette.
        guard header.identifier == PCX_IDENTIFIER else {
            return .palette
        }
        
        // The TAK palettes are all 1x1 PCX images.
        // Anything bigger we can just assume it's an image.
        let size = header.imageSize
        guard size.width > 1 && size.height > 1 else {
            return .palette
        }
        
        return .image
    }
    
}

// MARK:- Misc

extension PCX_HEADER {
    
    var imageSize: Size2<Int> {
        return Size2<Int>(width:  Int(window.xMax) - Int(window.xMin) + 1,
                      height: Int(window.yMax) - Int(window.yMin) + 1)
    }
    
}
