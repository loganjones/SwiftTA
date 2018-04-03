//
//  Palette+Files.swift
//  TAassets
//
//  Created by Logan Jones on 4/2/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


extension Palette {
    
    static func standardTaPalette(from filesystem: FileSystem) throws -> Palette {
        
        guard let palettesDirectory = filesystem.root[directory: "palettes"]
            else { throw FindPaletteError.noPalettesDirectory }
        
        let paletteName = "PALETTE.PAL"
        
        guard let file = palettesDirectory[file: paletteName]
            else { throw FindPaletteError.taPaletteNotFound }
        
        let handle = try filesystem.openFile(file)
        return Palette(palContentsOf: handle)
    }
    
}

// MARK:- Textures

extension Palette {
    
    static let textureTransparencies: Set<Int> = [5]
    
    static func texturePalette(for unit: UnitInfo, in sides: [SideInfo], from filesystem: FileSystem) throws -> Palette {
        
        guard let side = sides.first(withName: unit.side)
            else { throw FindPaletteError.sideNotFound(unit.side) }
        
        guard let paletteName = side.palette
            else { return try standardTaPalette(from: filesystem).applyingChromaKeys(textureTransparencies) }
        
        guard let palettesDirectory = filesystem.root[directory: "palettes"]
            else { throw FindPaletteError.noPalettesDirectory }
        
        if let file = palettesDirectory[file: paletteName] {
            
            if file.hasExtension("pal") {
                let handle = try filesystem.openFile(file)
                return Palette(palContentsOf: handle).applyingChromaKeys(textureTransparencies)
            }
            else if file.hasExtension("pcx") {
                let handle = try filesystem.openFile(file)
                return try Pcx.extractPalette(contentsOf: handle).applyingChromaKeys(textureTransparencies)
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
                return try Pcx.extractPalette(contentsOf: handle).applyingChromaKeys(textureTransparencies)
            }
            
        }
        
        throw FindPaletteError.paletteFileNotFound("palettes/\(paletteName)")
    }
    
}

// MARK:- Features

extension Palette {
    
    static let featureTransparencies: Set<Int> = [0]
    
    static func featurePalette(for feature: MapFeatureInfo, from filesystem: FileSystem) throws -> Palette {
        
        guard let world = feature.world
            else { return try standardTaPalette(from: filesystem).applyingChromaKeys(featureTransparencies) }
        
        if let palette = try? featurePalette(forWorld: world, from: filesystem) {
            return palette
        }
        
        // Use GAF filename?
        
        throw FindPaletteError.paletteFileNotFound("\(world)_features.pcx")
    }
    
    static func featurePalette(forWorld world: String, from filesystem: FileSystem) throws -> Palette {
        
        guard !world.isEmpty
            else { return try standardTaPalette(from: filesystem).applyingChromaKeys(featureTransparencies) }
        
        guard let palettesDirectory = filesystem.root[directory: "palettes"]
            else { throw FindPaletteError.noPalettesDirectory }
        
        let filename = "\(world.lowercased())_features.pcx"
        
        if let file = palettesDirectory[file: filename] {
            let handle = try filesystem.openFile(file)
            return try Pcx.extractPalette(contentsOf: handle).applyingChromaKeys(featureTransparencies)
        }
        
        throw FindPaletteError.paletteFileNotFound("palettes/\(filename)")
    }
    
    static func featurePaletteForTa(from filesystem: FileSystem) throws -> Palette {
        return try standardTaPalette(from: filesystem).applyingChromaKeys(featureTransparencies)
    }
    
}

private enum FindPaletteError: Error {
    case sideNotFound(String)
    case sideSpecifiesNoPalette
    case noPalettesDirectory
    case taPaletteNotFound
    case paletteFileNotFound(String)
}
