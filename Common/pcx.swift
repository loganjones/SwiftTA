//
//  pcx.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation

extension PCX_HEADER {
    
    var imageSize: Size2D {
        return Size2D(width:  Int(window.xMax) - Int(window.xMin) + 1,
                      height: Int(window.yMax) - Int(window.yMin) + 1)
    }
    
}

struct Size2D {
    var width: Int
    var height: Int
}
extension Size2D {
    static var zero: Size2D { return Size2D(width: 0, height: 0) }
    var area: Int { return width * height }
}
extension Size2D: CustomStringConvertible {
    var description: String { return "\(width)x\(height)" }
}
extension Size2D {
    init(_ tuple: (Int, Int)) {
        width = tuple.0
        height = tuple.1
    }
}
extension Size2D {
    static func / (size: Size2D, divisor: Int) -> Size2D {
        return Size2D(width: size.width / divisor, height: size.height / divisor)
    }
    static func /= (size: inout Size2D, divisor: Int) {
        size.width /= divisor
        size.height /= divisor
    }
    static func * (size: Size2D, multiplier: Int) -> Size2D {
        return Size2D(width: size.width * multiplier, height: size.height * multiplier)
    }
    static func *= (size: inout Size2D, multiplier: Int) {
        size.width *= multiplier
        size.height *= multiplier
    }
}

/**
 Decodes the RLE compressed data in `bytes` using the provided `palette` and `header` information.
 */
func decodePcx(_ header: PCX_HEADER, bytes: UnsafePointer<UInt8>, palette: UnsafePointer<UInt8>,
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
