//
//  MapView.swift
//  HPIView
//
//  Created by Logan Jones on 6/3/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import AppKit

class MapView: NSImageView {
    
    func load<File>(contentsOf tntFile: File, using palette: Palette) throws
        where File: FileReadHandle
    {
        let header = try tntFile.readValue(ofType: TA_TNT_HEADER.self)
        let size = Size2D(width: Int(header.width), height: Int(header.height))
        
        guard let tntType = TntFormat.TntVersion(rawValue: header.version)
            else { throw Error.badTntType(Int(header.version)) }
        
        switch tntType {
        case .ta: return try loadTa(tntFile, mapSize: size, using: palette)
        case .tak: return try loadTak(tntFile, mapSize:size, using: palette)
        }
        
    }
    
    private func loadTa<File>(_ tntFile: File, mapSize: Size2D, using palette: Palette) throws
        where File: FileReadHandle
    {
        let header = try tntFile.readValue(ofType: TA_TNT_EXT_HEADER.self)
        
        tntFile.seek(toFileOffset: header.offsetToMiniMap)
        
        let minimapWidth = Int( try tntFile.readValue(ofType: UInt32.self) )
        let minimapHeight = Int( try tntFile.readValue(ofType: UInt32.self) )
        let data = try tntFile.readData(verifyingLength: minimapWidth * minimapHeight)
        
        self.image = NSImage(imageIndices: data,
                             imageWidth: minimapWidth,
                             imageHeight: minimapHeight,
                             palette: palette)
    }
    
    private func loadTak<File>(_ tntFile: File, mapSize: Size2D, using palette: Palette) throws
        where File: FileReadHandle
    {
        let header = try tntFile.readValue(ofType: TAK_TNT_EXT_HEADER.self)
        
        tntFile.seek(toFileOffset: header.offsetToLargeMiniMap)
        
        let minimapWidth = Int( try tntFile.readValue(ofType: UInt32.self) )
        let minimapHeight = Int( try tntFile.readValue(ofType: UInt32.self) )
        let data = try tntFile.readData(verifyingLength: minimapWidth * minimapHeight)
        
        self.image = NSImage(imageIndices: data,
                             imageWidth: minimapWidth,
                             imageHeight: minimapHeight,
                             palette: palette)
    }
    
    enum Error: Swift.Error {
        case failedToOpenTnt
        case badTntType(Int)
    }
    
}

public enum TntFormat {
    
    public enum TntVersion: UInt32 {
        
        /// This indicates that this is a Total Annihilation TNT file.
        /// The remaining potion of the header should use the TA_TNT_EXT_HEADER type
        case ta = 0x00002000
        
        /// This indicates that this is a Kingdoms TNT file.
        /// The remaining potion of the header should use the TAK_TNT_EXT_HEADER type
        case tak = 0x00004000
        
    }
}
