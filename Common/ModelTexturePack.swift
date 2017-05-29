//
//  ModelTexturePack.swift
//  TAassets
//
//  Created by Logan Jones on 2/15/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation


class ModelTexturePack {
    
    typealias Gaf = UnitTextureAtlas.GafContent
    private let textures: [String: Gaf]
    
    init(loadFrom filesystem: TaassetsFileSystem) {
        
        let texDirectectory = filesystem.root[directory: "textures"] ?? Asset.Directory()
        let list = texDirectectory.items
            .flatMap { $0.asFile() }
            .filter { $0.hasExtension("gaf") }
            .flatMap { try? filesystem.urlForFile($0, at: "textures/" + $0.name) }
            .flatMap { (try? Gaf.load(withContentsOf: $0)) ?? [] }
        
        var textures: [String: Gaf] = [:]
        for tex in list {
            textures[tex.item.name] = tex
        }
        self.textures = textures
        
        //let allSizes = textures.values.map { $0.item.size }.sorted(by: largestSize)
        //print("Sizes: \(allSizes)")
    }
    
    subscript(name: String) -> Gaf? {
        if let tex = textures[name] { return tex }
        else { return nil }
    }
    
}

//private func largestSize(a: Size2D, b: Size2D) -> Bool {
//    let areaA = a.width * a.height
//    let areaB = b.width * b.height
//    let perimeterA = a.width * 2 + a.height * 2
//    let perimeterB = b.width * 2 + b.height * 2
//    let maxA = max(a.width, a.height)
//    let maxB = max(b.width, b.height)
//    return areaA > areaB && perimeterA > perimeterB && maxA > maxB
//}

private extension ModelTexturePack.Gaf {

    static func load(withContentsOf gafUrl: URL) throws -> [ModelTexturePack.Gaf] {
        let listing = try GafListing(withContentsOf: gafUrl)
        return listing.items.map { ModelTexturePack.Gaf(url: gafUrl, item: $0) }
    }
    
}
