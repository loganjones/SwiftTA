//
//  GafView.swift
//  HPIView
//
//  Created by Logan Jones on 5/27/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import AppKit

class GafView: NSImageView {
    
    func load<File>(_ item: GafItem, from gaf: File, using palette: Palette) throws
        where File: FileReadHandle
    {
        
        Swift.print("Loading \(item.name) from \(gaf.fileName)")
        Swift.print("  \(item.frames.count) frames")
        Swift.print("  \(item.size.width)x\(item.size.height)")
        Swift.print("  item.unknown_1: \(item.unknown1) | \(item.unknown1.binaryString)")
        Swift.print("  item.unknown_2: \(item.unknown2) | \(item.unknown2.binaryString)")
        
        var i = 1
        for frameEntry in item.frames {
            
            gaf.seek(toFileOffset: frameEntry.offsetToFrameData)
            let frameInfo = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
            
            let compression = GafFrameCompressionMethod(rawValue: frameInfo.compressionMethod) ?? .uncompressed
            
            Swift.print("  frame \(i):")
            Swift.print("    \(frameInfo.width)x\(frameInfo.height)")
            Swift.print("    compression: \(compression)")
            Swift.print("    sub-frames: \(frameInfo.numberOfSubFrames)")
            Swift.print("    entry.unknown_1: \(frameEntry.unknown_1) | \(frameEntry.unknown_1.binaryString)")
            Swift.print("    info.unknown_1: \(frameInfo.unknown_1) | \(frameInfo.unknown_1.binaryString)")
            Swift.print("    info.unknown_2: \(frameInfo.unknown_2)")
            Swift.print("    info.unknown_3: \(frameInfo.unknown_3) | \(frameInfo.unknown_3.binaryString)")
            
            if frameInfo.numberOfSubFrames > 0 {
                gaf.seek(toFileOffset: frameInfo.offsetToFrameData)
                let subframeOffsets = try gaf.readArray(ofType: UInt32.self, count: Int(frameInfo.numberOfSubFrames))
                
                var j = 1
                for offset in subframeOffsets {
                    gaf.seek(toFileOffset: offset)
                    let subframeInfo = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
                    Swift.print("    subframe \(j):")
                    Swift.print("      \(subframeInfo.width)x\(subframeInfo.height)")
                    Swift.print("      compression: \(compression)")
                    Swift.print("      sub-frames: \(subframeInfo.numberOfSubFrames)")
                    Swift.print("      info.unknown_1: \(subframeInfo.unknown_1) | \(subframeInfo.unknown_1.binaryString)")
                    Swift.print("      info.unknown_2: \(subframeInfo.unknown_2)")
                    Swift.print("      info.unknown_3: \(subframeInfo.unknown_3) | \(subframeInfo.unknown_3.binaryString)")
                    j += 1
                }
            }
            
            i += 1
        }
        
        self.image = nil
        if let frameEntry = item.frames.first {
            
            gaf.seek(toFileOffset: frameEntry.offsetToFrameData)
            let frameInfo = try gaf.readValue(ofType: TA_GAF_FRAME_DATA.self)
            
            if frameInfo.numberOfSubFrames == 0,
                let frameData = try? GafItem.read(frame: frameInfo, from: gaf) {
                self.image = NSImage(imageIndices: frameData,
                                     size: frameInfo.size,
                                     palette: palette)
            }
        }
    }
    
    enum LoadError: Error {
        case failedToOpenGAF
        case noFrames
        case unsupportedFrameCompression(UInt8)
    }
    
}

extension TA_GAF_FRAME_DATA {
    var size: Size2D {
        return Size2D(width: Int(width), height: Int(height))
    }
}
