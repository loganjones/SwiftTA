//
//  PcxImage.swift
//  HPIView
//
//  Created by Logan Jones on 5/27/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation
import Cocoa


extension NSImage {
    
    /**
     Creates an NSImage from the contents of a TA PCX file at `pcxURL`.
     
     - note: This loaer does *not* support to full breadth of the PCX format.
     Only 24-bit images with a VGA palette are supported.
     */
    convenience init<File>(pcxContentsOf pcxFile: File) throws
        where File: FileReadHandle
    {
        // Read in the PCX header and check that the `identifer` is what we expect.
        // This is the full extenet to doing any compatibility checks;
        // from here on, we assume this is a standard TA PCX file.
        // (ie. 8-bit per pixel, VGA palette at end of file, etc)
        let header = try pcxFile.readValue(ofType: PCX_HEADER.self)
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
