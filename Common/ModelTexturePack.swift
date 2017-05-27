//
//  ModelTexturePack.swift
//  TAassets
//
//  Created by Logan Jones on 2/15/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation


class ModelTexturePack {
    
    private let textures: [String: ModelTextureInfo]
    
    init(loadFrom filesystem: TaassetsFileSystem) {
        
        let texDirectectory = filesystem.root[directory: "textures"] ?? Asset.Directory()
        let list = texDirectectory.items
            .flatMap { $0.asFile() }
            .filter { $0.hasExtension("gaf") }
            .flatMap { try? filesystem.urlForFile($0, at: "textures/" + $0.name) }
            .flatMap { (try? ModelTextureInfo.load(withContentsOf: $0)) ?? [] }
        
        var textures: [String: ModelTextureInfo] = [:]
        for tex in list {
            textures[tex.name] = tex
        }
        self.textures = textures
    }
    
    subscript(name: String) -> ModelTextureInfo? {
        if let tex = textures[name] { return tex }
        else { return nil }
    }
    
}

struct ModelTextureInfo {
    var gafUrl: URL
    var image: GafImage
}

extension ModelTextureInfo {
    var name: String { return image.name }
}

extension ModelTextureInfo {

    static func load(withContentsOf gafUrl: URL) throws -> [ModelTextureInfo] {
        
        let listing = try GafListing(withContentsOf: gafUrl)
        return listing.items.flatMap {
            switch $0 {
            case .image(let image):
                return ModelTextureInfo(gafUrl: gafUrl, image: image)
            }
        }
    }
    
}
