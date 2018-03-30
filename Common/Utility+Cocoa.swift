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
    
    static func createWith(imageIndices: Data, size: Size2D, palette: Palette, useTransparency: Bool = false, isFlipped: Bool = false) -> CGImage {
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
        return CGImage(
            width: size.width,
            height: size.height,
            bitsPerComponent: 8,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: CGDataProvider(data: data as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent)!
    }
    
    static func createWith(rawFrame: GafItem.Frame) -> CGImage {
        
        switch rawFrame.format {
            
        case .raw4444:
            return CGImage(
                width: rawFrame.size.width,
                height: rawFrame.size.height,
                bitsPerComponent: 4,
                bitsPerPixel: 16,
                bytesPerRow: rawFrame.size.width * 2,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGImageByteOrderInfo.order16Little.rawValue)],
                provider: CGDataProvider(data: rawFrame.data as CFData)!,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent)!
            
        case .raw1555://, .raw4444:
            let data = try! rawFrame.convertToRGBA()
            return CGImage(
                width: rawFrame.size.width,
                height: rawFrame.size.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: rawFrame.size.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)],
                provider: CGDataProvider(data: data as CFData)!,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent)!
            
        default:
            fatalError("Unsupported GAF frame pixel format: \(rawFrame.format)")
        }
    }
    
}

extension NSImage {
    
    convenience init(imageIndices: Data, size: Size2D, palette: Palette, useTransparency: Bool = false, isFlipped: Bool = false) {
        let image = CGImage.createWith(imageIndices: imageIndices, size: size, palette: palette, useTransparency: useTransparency, isFlipped: isFlipped)
        self.init(cgImage: image, size: NSSize(size))
    }
    
    convenience init(rawFrame: GafItem.Frame) {
        let image = CGImage.createWith(rawFrame: rawFrame)
        self.init(cgImage: image, size: NSSize(rawFrame.size))
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
