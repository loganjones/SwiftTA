//
//  pcx.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation
import Cocoa


extension NSImage {
    
    /**
     Creates an NSImage from the contents of a TA PCX file at `pcxURL`.
     
     - note: This loaer does *not* support to full breadth of the PCX format.
             Only 24-bit images with a VGA palette are supported. 
     */
    convenience init(pcxContentsOf pcxURL: URL) throws {
        
        // Read in the PCX header and check that the `identifer` is what we expect.
        // This is the full extenet to doing any compatibility checks;
        // from here on, we assume this is a standard TA PCX file.
        // (ie. 8-bit per pixel, VGA palette at end of file, etc)
        let pcxFile = try FileHandle(forReadingFrom: pcxURL)
        let header = pcxFile.readValue(ofType: PCX_HEADER.self)
        guard header.identifier == PCX_IDENTIFIER else { throw PcxError.badIdentifier(header.identifier) }
        
        // Sanity checks
        let size = header.imageSize
        guard size.width > 0 && size.height > 0 else { throw PcxError.badImageSize(header) }
        
        // Make a buffer for the final decoded image.
        let pixelBufferLength = size.width * size.height * 3
        let pixelBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelBufferLength)
        defer { pixelBuffer.deallocate(capacity: pixelBufferLength) }
        
        // Read in the rest of the file and get decodin'
        let rawData = pcxFile.readDataToEndOfFile()
        try rawData.withUnsafeBytes { (p: UnsafePointer<UInt8>) throws in
            // Do a simple check for the end-of-file palette.
            // If it's not there, bail; we don't support any other tyoe of PCX.
            guard rawData.count > 769, p[rawData.count - 769] == 0x0C
                else { throw PcxError.noPalette }
            // Decode the PCX bytes into our `pixelBuffer`.
            decodePcx(header, bytes: p, palette: p + (rawData.count - 768), into: pixelBuffer)
        }
        
        // Create a NSImage with our `pixelBuffer`. Doing this is pretty convoluted.
        // The easiest way I know to get raw pixels into an NSImage is through a CGImage, by way of a CGDataProvider.
        // This will involve a few copies unfortunately; but at least PCXs are pretty small.
        guard let pixelData = CFDataCreate(kCFAllocatorDefault, pixelBuffer, pixelBufferLength)
            else { throw PcxError.failedToCreateData }
        guard let pixelProvider = CGDataProvider(data: pixelData)
            else { throw PcxError.failedToCreateProvider }
        guard let image = CGImage(width: size.width,
                                  height: size.height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 24,
                                  bytesPerRow: size.width * 3,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: [],
                                  provider: pixelProvider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent)
            else { throw PcxError.failedToCreateImage }
        self.init(cgImage: image, size: NSSize(size))
    }
    
    enum PcxError: Error {
        case badIdentifier(UInt8)
        case badImageSize(PCX_HEADER)
        case noPalette
        case failedToCreateData
        case failedToCreateProvider
        case failedToCreateImage
    }
    
}

private extension PCX_HEADER {
    
    var imageSize: Size2D {
        return Size2D(width:  Int(window.xMax) - Int(window.xMin) + 1,
                      height: Int(window.yMax) - Int(window.yMin) + 1)
    }
    
}

private struct Size2D {
    var width: Int = 0
    var height: Int = 0
}

private extension NSSize {
    
    init(_ size: Size2D) {
        self.init(width: size.width, height: size.height)
    }
    
}

/**
 Decodes the RLE compressed data in `bytes` using the provided `palette` and `header` information.
 */
private func decodePcx(_ header: PCX_HEADER, bytes: UnsafePointer<UInt8>, palette: UnsafePointer<UInt8>,
                       into pixelBuffer: UnsafeMutablePointer<UInt8>) {
    
    let size = header.imageSize
    
    var pcxBytes = bytes
    var line = pixelBuffer
    for _ in 0..<size.height {
        var x = 0
        var pixelX = 0
        while x < size.width {
            let byte = pcxBytes.pointee
            pcxBytes += 1
            if 0xC0 == (0xC0 & byte) {
                let count = 0x3F & byte
                let byte2 = pcxBytes.pointee
                pcxBytes += 1
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

private func setPixel(_ pixel: UnsafeMutablePointer<UInt8>, to colorIndex: UInt8, palette: UnsafePointer<UInt8>) {
    let colorOffset = Int(colorIndex) * 3
    pixel[0] = palette[colorOffset + 0]
    pixel[1] = palette[colorOffset + 1]
    pixel[2] = palette[colorOffset + 2]
}
