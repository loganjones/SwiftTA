//
//  MapView+Cocoa.swift
//  TAassets
//
//  Created by Logan Jones on 3/23/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import AppKit

class CocoaMapView: CocoaTntView, MapViewLoader {
    
    private var map: MapData?
    
    func load(_ mapName: String, from filesystem: FileSystem) throws {
        super.drawFeatures = { [unowned self] in self.drawCocoaMapFeatures($0,$1) }
        
        let beginMap = Date()
        
        let beginOta = Date()
        guard let otaFile = filesystem.root[filePath: "maps/" + mapName + ".ota"]
            else { throw FileSystem.Directory.ResolveError.notFound }
        let info = try MapInfo(contentsOf: otaFile, in: filesystem)
        let endOta = Date()
        
        let tileCountString: String
        let beginTnt = Date()
        let tntFile = try filesystem.openFile(at: "maps/" + mapName + ".tnt")
        let map = try MapModel(contentsOf: tntFile)
        switch map {
        case .ta(let model):
            let palette = try Palette.standardTaPalette(from: filesystem)
            super.load(model, using: palette)
            let tileCount = model.tileSet.count
            tileCountString = "count:\(tileCount) pixels:\(tileCount * 16 * 16)"
        case .tak(let model):
            super.load(model, from: filesystem)
            tileCountString = ""
        }
        let endTnt = Date()
        
        let beginFeatures = Date()
        let featureNames = Set(map.features)
        let features = CocoaMapView.loadMapFeatures(featureNames, planet: info.properties["planet"] ?? "", from: filesystem)
        let featureInstances = CocoaMapView.indexFeatureLocations(map, features)
        let endFeatures = Date()
        
        self.map = MapData(info: info, features: features, featureInstances: featureInstances)
        let endMap = Date()
        
        print("""
            Map load time: \(endMap.timeIntervalSince(beginMap)) seconds
            OTA: \(endOta.timeIntervalSince(beginOta)) seconds
            TNT: \(endTnt.timeIntervalSince(beginTnt)) seconds
            Features: \(endFeatures.timeIntervalSince(beginFeatures)) seconds
            """)
        print("Features: \(featureNames)")
        print("Map Size: tiles:\(map.mapSize) pixels:\(map.resolution)")
        print("Tiles: "+tileCountString)
    }
    
    override func clear() {
        super.clear()
        map = nil
    }
    
    func drawCocoaMapFeatures(_ rect: CGRect, _ context: CGContext) {
        guard let map = map else { return }
        for instance in map.featureInstances {
            guard let feature = map.features[instance.featureName] else { continue }
            if let shadowFrame = feature.shadow, let rect = instance.shadowRect {
                context.draw(shadowFrame.image, in: rect)
            }
            context.draw(feature.frames[0].image, in: instance.rect)
        }
    }
    
}

private extension CocoaMapView {
    
    struct MapData {
        var info: MapInfo
        var features: [String: Feature] = [:]
        var featureInstances: [FeatureInstance] = []
    }
    
    struct Feature {
        var name: String
        var info: MapFeatureInfo
        var frames: [Frame]
        var shadow: Frame?
        typealias Frame = (image: CGImage, offset: Point2D)
    }
    
    struct FeatureInstance {
        var featureName: String
        var rect: CGRect
        var shadowRect: CGRect?
    }
    
    static func loadMapFeatures(_ featureNames: Set<String>, planet: String, from filesystem: FileSystem) -> [String: Feature] {
        
        let featureInfo = MapFeatureInfo.collectFeatures(named: featureNames, strartingWith: planet, from: filesystem)
        let palettes = loadFeaturePalettes(featureInfo, from: filesystem)
        
        var features: [String: Feature] = [:]
        features.reserveCapacity(featureInfo.count)
        
        let byGaf = Dictionary(grouping: featureInfo, by: { a in a.value.gafFilename ?? "" })
        let shadow = Palette.shadow
        
        for (gafName, featuresInGaf) in byGaf {
            
            guard let gaf = try? filesystem.openFile(at: "anims/" + gafName + ".gaf"),
                let listing = try? GafListing(withContentsOf: gaf)
                else { continue }
            
            for (name, info) in featuresInGaf {
                guard let itemName = info.primaryGafItemName, let item = listing[itemName] else { continue }
                guard let gafFrames = try? item.extractFrames(from: gaf) else { continue }
                guard let palette = palettes[info.world ?? ""] else { continue }
                
                let frames: [Feature.Frame] = gafFrames.map {
                    let image = try! CGImage.createWith(imageIndices: $0.data, size: $0.size, palette: palette, useTransparency: true, isFlipped: true)
                    return Feature.Frame(image: image, offset: $0.offset)
                }
                
                let shadowFrame: Feature.Frame? = info.shadowGafItemName.flatMap {
                    guard let item = listing[$0] else { return nil }
                    guard let frame = try? item.extractFrame(index: 0, from: gaf) else { return nil }
                    guard let image = try? CGImage.createWith(imageIndices: frame.data, size: frame.size, palette: shadow, useTransparency: true, isFlipped: true) else { return nil }
                    return Feature.Frame(image: image, offset: frame.offset)
                }
                
                features[name] = Feature(name: name,
                                         info: info,
                                         frames: frames,
                                         shadow: shadowFrame)
            }
            
        }
        
        return features
    }
    
    static func loadFeaturePalettes(_ featureInfo: MapFeatureInfo.FeatureInfoCollection, from filesystem: FileSystem) -> [String: Palette] {
        return featureInfo.reduce(into: [String: Palette]()) { (palettes, info) in
            let world = info.value.world ?? ""
            guard palettes[world] == nil else { return }
            if let palette = try? Palette.featurePalette(forWorld: world, from: filesystem) {
                palettes[world] = palette
            }
            else if let palette = try? Palette.featurePaletteForTa(from: filesystem) {
                palettes[world] = palette
            }
        }
    }
    
    static func indexFeatureLocations(_ map: MapModel, _ features: [String: Feature]) -> [FeatureInstance] {
        
        var instances: [FeatureInstance] = []
        
        for i in map.featureMap.indices {
            guard let featureIndex = map.featureMap[i] else { continue }
            guard let feature = features[map.features[featureIndex]] else { continue }
            
            let y = i / map.mapSize.width
            let x = i - (y * map.mapSize.width)
            let h = CGFloat(map.heightMap[i]) / 2.0
            let size = feature.frames[0].image.size
            let offset = feature.frames[0].offset
            
            let xx = (x * 16) + feature.info.footprint.width * 8
            let yy = (y * 16) + feature.info.footprint.height * 8
            
            let rect = CGRect(x: CGFloat(xx - offset.x),
                              y: CGFloat(yy - offset.y) - h,
                              width: CGFloat(size.width),
                              height: CGFloat(size.height))
            
            let shadowRect: CGRect? = feature.shadow.map {
                CGRect(x: CGFloat(xx - $0.offset.x),
                       y: CGFloat(yy - $0.offset.y) - h,
                       width: CGFloat($0.image.width),
                       height: CGFloat($0.image.height))
            }
            
            instances.append(FeatureInstance(featureName: feature.name, rect: rect, shadowRect: shadowRect))
        }
        
        return instances
    }
    
}
