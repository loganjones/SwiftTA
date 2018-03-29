//
//  MapView.swift
//  TAassets
//
//  Created by Logan Jones on 3/23/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import AppKit


class MapView: NSView {
    
    private let tntView: TntView
    
    private var info: MapInfo!
    private var features: [String: Feature] = [:]
    private var featureInstances: [FeatureInstance] = []
    
    override init(frame frameRect: NSRect) {
        
        let tntView = TntView(frame: frameRect)
        tntView.autoresizingMask = [.width, .height]
        
        self.tntView = tntView
        super.init(frame: frameRect)
        
        addSubview(tntView)
        tntView.drawFeatures = { [unowned self] in self.drawMapFeatures($0,$1) }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(_ mapName: String, from filesystem: FileSystem, using palette: Palette) throws {
        
        let beginMap = Date()
        
        let beginOta = Date()
        guard let otaFile = filesystem.root[filePath: "maps/" + mapName + ".ota"]
            else { throw FileSystem.Directory.ResolveError.notFound }
        info = try MapInfo(contentsOf: otaFile, in: filesystem)
        let endOta = Date()
        
        let beginTnt = Date()
        let tntFile = try filesystem.openFile(at: "maps/" + mapName + ".tnt")
        let map = try MapModel(contentsOf: tntFile)
        tntView.load(map, using: palette, filesystem: filesystem)
        let endTnt = Date()
        
        let beginFeatures = Date()
        let featureNames = Set(map.features)
        features = MapView.loadMapFeatures(featureNames, planet: info.properties["planet"] ?? "", from: filesystem, using: palette)
        featureInstances = MapView.indexFeatureLocations(map, features)
        let endFeatures = Date()
        
        let endMap = Date()
        
        print("""
            Map load time: \(endMap.timeIntervalSince(beginMap)) seconds
                   OTA: \(endOta.timeIntervalSince(beginOta)) seconds
                   TNT: \(endTnt.timeIntervalSince(beginTnt)) seconds
              Features: \(endFeatures.timeIntervalSince(beginFeatures)) seconds
            """)
        print("Features: \(featureNames)")
        
    }
    
    static func loadMapFeatures(_ featureNames: Set<String>, planet: String, from filesystem: FileSystem, using palette: Palette) -> [String: Feature] {
        
        let featureInfo = MapFeatureInfo.collectFeatures(named: featureNames, strartingWith: planet, from: filesystem)
        
        var features: [String: Feature] = [:]
        features.reserveCapacity(featureInfo.count)
        
        let byGaf = Dictionary(grouping: featureInfo, by: { a in a.value.gafFilename })
        let shadow = Palette.shadow
        
        for (gafName, featuresInGaf) in byGaf {
            
            guard let gaf = try? filesystem.openFile(at: "anims/" + gafName + ".gaf"),
                let listing = try? GafListing(withContentsOf: gaf)
                else { continue }
            
            for (name, info) in featuresInGaf {
                guard let item = listing[info.primaryGafItemName] else { continue }
                guard let gafFrames = try? item.extractFrames(from: gaf) else { continue }
                
                let frames: [Feature.Frame] = gafFrames.map {
                    let image = CGImage.createWith(imageIndices: $0.data, size: $0.size, palette: palette, useTransparency: true, isFlipped: true)
                    return Feature.Frame(image: image, offset: $0.offset)
                }
                
                let shadowFrame: Feature.Frame? = info.shadowGafItemName.flatMap {
                    guard let item = listing[$0] else { return nil }
                    guard let frame = try? item.extractFrame(index: 0, from: gaf) else { return nil }
                    let image = CGImage.createWith(imageIndices: frame.data, size: frame.size, palette: shadow, useTransparency: true, isFlipped: true)
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
    
    static func indexFeatureLocations(_ map: MapModel, _ features: [String: Feature]) -> [FeatureInstance] {
        
        var instances: [FeatureInstance] = []
        
        for i in map.featureMap.indexRange {
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
    
    func drawMapFeatures(_ rect: CGRect, _ context: CGContext) {
        for instance in featureInstances {
            guard let feature = features[instance.featureName] else { continue }
            if let shadowFrame = feature.shadow, let rect = instance.shadowRect {
                context.draw(shadowFrame.image, in: rect)
            }
            context.draw(feature.frames[0].image, in: instance.rect)
        }
    }
    
}

extension MapView {
    
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
    
}

extension CGImage {
    var size: Size2D {
        return Size2D(width: width, height: height)
    }
}
