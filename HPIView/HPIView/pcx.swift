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
    
    convenience init(pcxContentsOf pcxURL: URL) {
        let data = try! Data(contentsOf: pcxURL)
        self.init(withPCX: data)
    }
    convenience init(withPCX pcxData: Data) {
        
        var size = (width: 0, height: 0)
        let cfdata = pcxData.withUnsafeBytes({ (pcx: UnsafePointer<UInt8>) -> CFData in
            
            let header = pcx.withMemoryRebound(to: PCX_HEADER.self, capacity: 1) { $0.pointee }
            size = (width: Int(header.window.xMax - header.window.xMin + 1),
                    height: Int(header.window.yMax - header.window.yMin + 1))
            
            var pcxBytes = pcx + 128
            
            var indexData = Data(count: Int(header.bytesPerLine) * size.height)
            indexData.withUnsafeMutableBytes({ (indices: UnsafeMutablePointer<UInt8>) -> Void in
                var raw = indices
                for _ in 0..<size.height {
                    var x = 0
                    while x < size.width {
                        let byte = pcxBytes.pointee
                        pcxBytes += 1
                        if 0xC0 == (0xC0 & byte) {
                            let count = 0x3F & byte
                            let byte2 = pcxBytes.pointee
                            pcxBytes += 1
                            for _ in 0..<count {
                                raw[x] = byte2
                                x += 1
                            }
                        }
                        else {
                            raw[x] = byte
                            x += 1
                        }
                    }
                    raw += Int(header.bytesPerLine)
                }
            })
            
            let paletteCheck = pcx + (pcxData.count - 769)
            guard paletteCheck[0] == 0x0C else { fatalError() }
            let palette = paletteCheck + 1
            
            var pixelData = Data(count: size.width * size.height * 3)
            return pixelData.withUnsafeMutableBytes({ (pixels: UnsafeMutablePointer<UInt8>) -> CFData in
                indexData.withUnsafeBytes({ (indices: UnsafePointer<UInt8>) -> Void in
                    var pixel = pixels
                    var raw = indices
                    for _ in 0..<(size.width * size.height) {
                        let colorIndex = raw.pointee
                        let colorOffset = Int(colorIndex) * 3
                        pixel[0] = palette[colorOffset + 0]
                        pixel[1] = palette[colorOffset + 1]
                        pixel[2] = palette[colorOffset + 2]
                        pixel += 3
                        raw += 1
                    }
                })
                return CFDataCreate(kCFAllocatorDefault, pixels, pixelData.count)
            })
        })
        
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
}
