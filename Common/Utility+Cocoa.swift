//
//  CocoaUtility.swift
//  HPIView
//
//  Created by Logan Jones on 5/27/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import AppKit

// MARK:- Text File Loading

extension String {
    
    init(textContentsOf url: URL, usedEncoding inoutEncoding: inout String.Encoding) throws {
        do {
            try self.init(contentsOf: url, usedEncoding: &inoutEncoding)
        }
        catch {
            let cocoaError = error as NSError
            if cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSFileReadUnknownStringEncodingError {
                do {
                    try self.init(contentsOf: url, encoding: .utf8)
                    inoutEncoding = .utf8
                }
                catch {
                    do {
                        try self.init(contentsOf: url, encoding: .ascii)
                        inoutEncoding = .ascii
                    }
                    catch {
                        throw error
                    }
                }
            }
            else {
                throw error
            }
        }
    }
    
}

// MARK:- Image Loading

extension CGImage {
    
    static func createWith(imageIndices: Data, size: Size2D, palette: Palette, useTransparency: Bool = false, isFlipped: Bool = false) throws -> CGImage {
        
        let bitsPerPixel: Int
        let bytesPerRow: Int
        let bitmapInfo: CGBitmapInfo
        let data: Data
        
        if useTransparency {
            bitsPerPixel = 32
            bytesPerRow = size.width * 4
            bitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
            data = isFlipped ? palette.mapIndicesRgbaFlipped(imageIndices, size: size) : palette.mapIndicesRgba(imageIndices, size: size)
        }
        else {
            bitsPerPixel = 24
            bytesPerRow = size.width * 3
            bitmapInfo = []
            data = isFlipped ? palette.mapIndicesRgbFlipped(imageIndices, size: size) : palette.mapIndicesRgb(imageIndices, size: size)
        }
        
        guard let pixelProvider = CGDataProvider(data: data as CFData)
            else { throw ImageCreateError.failedToCreateProvider }
        
        guard let image = CGImage(
            width: size.width,
            height: size.height,
            bitsPerComponent: 8,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: pixelProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent)
            else { throw ImageCreateError.failedToCreateImage }
        
        return image
    }
    
    static func createWith<File>(pcxContentsOf pcxFile: File) throws -> CGImage
        where File: FileReadHandle
    {
        let (data, size) = try Pcx.extractImage(contentsOf: pcxFile)
        
        guard let pixelProvider = CGDataProvider(data: data as CFData)
            else { throw ImageCreateError.failedToCreateProvider }
        
        guard let image = CGImage(
            width: size.width,
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
            else { throw ImageCreateError.failedToCreateImage }
        
        return image
    }
    
    enum ImageCreateError: Error {
        case failedToCreateProvider
        case failedToCreateImage
    }
    
}

extension NSImage {
    
    convenience init(imageIndices: Data, size: Size2D, palette: Palette, useTransparency: Bool = false, isFlipped: Bool = false) throws {
        let image = try CGImage.createWith(imageIndices: imageIndices, size: size, palette: palette, useTransparency: useTransparency, isFlipped: isFlipped)
        self.init(cgImage: image, size: NSSize(size))
    }
    
    /**
     Creates an NSImage from the contents of a TA PCX file.
     
     - note: This loaer does *not* support to full breadth of the PCX format.
     Only 24-bit images with a VGA palette are supported.
     */
    convenience init<File>(pcxContentsOf pcxFile: File) throws
        where File: FileReadHandle
    {
        let image = try CGImage.createWith(pcxContentsOf: pcxFile)
        self.init(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
    
}

// MARK:- Misc Conversions

extension NSSize {
    
    init(_ size: Size2D) {
        self.init(width: size.width, height: size.height)
    }
    
}

extension NSRect {
    
    init(x: Int, y: Int, size: Size2D) {
        self.init(x: x, y: y, width: size.width, height: size.height)
    }
    
    init(size: Size2D) {
        self.init(x: 0, y: 0, width: size.width, height: size.height)
    }
    
}

extension Palette.Color {
    
    var nsColor: NSColor {
        return NSColor(calibratedRed: CGFloat(red) / 255.0,
                       green: CGFloat(green) / 255.0,
                       blue: CGFloat(blue) / 255.0,
                       alpha: CGFloat(alpha) / 255.0)
    }
    
    var cgColor: CGColor {
        return CGColor(red: CGFloat(red) / 255.0,
                       green: CGFloat(green) / 255.0,
                       blue: CGFloat(blue) / 255.0,
                       alpha: CGFloat(alpha) / 255.0)
    }
    
}
