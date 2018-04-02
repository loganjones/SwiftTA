//
//  Palette+Files.swift
//  TAassets
//
//  Created by Logan Jones on 4/2/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


extension Palette {
    
    static func texturePalette(for unit: UnitInfo, in sides: [SideInfo], from filesystem: FileSystem) throws -> Palette {
        
        guard let side = sides.first(withPrefix: unit.side)
            else { throw FindPaletteError.sideNotFound(unit.side) }
        
        guard let paletteName = side.palette
            else { return try standardTaPalette(from: filesystem) }
        
        guard let palettesDirectory = filesystem.root[directory: "palettes"]
            else { throw FindPaletteError.noPalettesDirectory }
        
        if let file = palettesDirectory[file: paletteName] {
            
            if file.hasExtension("pal") {
                let handle = try filesystem.openFile(file)
                return Palette(contentsOf: handle)
            }
            else if file.hasExtension("pcx") {
                let handle = try filesystem.openFile(file)
                return try Pcx.extractPalette(contentsOf: handle)
            }
            else {
                throw FindPaletteError.paletteFileNotFound("palettes/\(paletteName)")
            }
            
        }
        
        let normalized = paletteName.lowercased()
        if normalized.hasSuffix(".pal") {
            
            let pcxPaletteName = normalized.replacingOccurrences(of: ".pal", with: ".pcx")
            
            if let file = palettesDirectory[file: pcxPaletteName] {
                let handle = try filesystem.openFile(file)
                return try Pcx.extractPalette(contentsOf: handle)
            }
            
        }
        
        throw FindPaletteError.paletteFileNotFound("palettes/\(paletteName)")
    }
    
    static func standardTaPalette(from filesystem: FileSystem) throws -> Palette {
        
        guard let palettesDirectory = filesystem.root[directory: "palettes"]
            else { throw FindPaletteError.noPalettesDirectory }
        
        let paletteName = "PALETTE.PAL"
        
        guard let file = palettesDirectory[file: paletteName]
            else { throw FindPaletteError.taPaletteNotFound }
        
        let handle = try filesystem.openFile(file)
        return Palette(contentsOf: handle)
    }
    
    enum FindPaletteError: Error {
        case sideNotFound(String)
        case sideSpecifiesNoPalette
        case noPalettesDirectory
        case taPaletteNotFound
        case paletteFileNotFound(String)
    }
    
}
