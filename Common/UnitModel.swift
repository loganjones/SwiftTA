//
//  UnitModel.swift
//  TAassets
//
//  Created by Logan Jones on 2/19/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

struct UnitModel {
    
    typealias Pieces = Array<Piece>
    typealias Primitives = Array<Primitive>
    typealias Vertices = Array<Vertex3>
    typealias Textures = Array<Texture>
    
    var pieces: Pieces
    var primitives: Primitives
    var vertices: Vertices
    var textures: Textures
    
    var root: Pieces.Index
    var groundPlate: Primitives.Index
    
    var nameLookup: [String: Pieces.Index]
    
    init(contentsOf modelURL: URL) throws {
        let fileData = try Data(contentsOf: modelURL)
        let model = fileData.withUnsafeBytes { UnitModel.loadModel(from: $0) }
        
        pieces = model.pieces
        primitives = model.primitives
        vertices = model.vertices
        textures = model.textures
        
        root = model.roots.first!
        groundPlate = model.groundPlate
        
        var names: [String: Pieces.Index] = [:]
        for (index, piece) in pieces.enumerated() {
            names[piece.name] = index
        }
        nameLookup = names
    }
    
    func piece(named name: String) -> Piece? {
        if let index = nameLookup[name] { return pieces[index] }
        else { return nil }
    }
    
    struct Piece {
        var name: String
        var offset: Vector3
        var primitives: [Primitives.Index]
        var children: [Pieces.Index]
    }
    
    struct Primitive {
        var texture: Textures.Index
        var indices: [Vertices.Index]
    }
    
    enum Texture {
        case image(String)
        case color(Int)
    }
    
    struct Instance {
        var position: Vector3 = Vector3.zero
        var orientation: Vector3 = Vector3.zero
        var pieces: [PieceState]
    }
    
    struct PieceState {
        var move = Vector3.zero
        var turn = Vector3.zero
        var hidden = false
        var cache = true
        var shade = true
        var shadow = true
    }
    
}

private extension UnitModel {
    
    struct ModelData {
        var pieces: Pieces = []
        var primitives: Primitives = []
        var vertices: Vertices = []
        var textures: Textures = []
        var roots: [Pieces.Index] = []
        var groundPlate: Primitives.Index = 0
    }
    
    struct ModelCounts {
        var pieces = 0
        var primitives = 0
        var vertices = 0
    }
    
    static func loadModel(from memory: UnsafePointer<UInt8>) -> ModelData {
        
        let counts = ModelCounts(startingAt: 0, in: memory)
        var model = ModelData(reservingCapacity: counts)
        var queue = accumulateSiblingOffsets(atOffset: 0, in: memory)
        var groundPlateIndex: Primitives.Index? = nil
        
        model.roots = Array(0..<queue.count)
        
        while !queue.isEmpty {
            
            let offset = queue.remove(at: 0)
            let object = UnsafeRawPointer(memory + offset).bindMemory(to: TA_3DO_OBJECT.self, capacity: 1).pointee

            let vertices = UnsafeRawPointer(memory + object.offsetToVertexArray).bindMemoryBuffer(to: TA_3DO_VERTEX.self, capacity: Int(object.numberOfVertexes)).map({ Vertex3($0) })
            let verticesStart = model.vertices.append2(contentsOf: vertices)
            
            let primitives = UnsafeRawPointer(memory + object.offsetToPrimitiveArray)
                .bindMemoryBuffer(to: TA_3DO_PRIMITIVE.self, capacity: Int(object.numberOfPrimitives))
                .map { raw -> Primitive in
                    let texture = Texture(of: raw, in: memory)
                    let texIndex = model.textures.index(of: texture) ?? model.textures.append2(texture)
                    let indices = UnsafeRawPointer(memory + raw.offsetToVertexIndexArray)
                        .bindMemoryBuffer(to: UInt16.self, capacity: Int(raw.numberOfVertexIndexes))
                        .map { UnitModel.Vertices.Index($0) + verticesStart }
                    return Primitive(texture: texIndex, indices: indices)
            }
            let primitivesStart = model.primitives.append2(contentsOf: primitives)
            
            let childOffsets = object.offsetToChildObject != 0 ? accumulateSiblingOffsets(atOffset: Int(object.offsetToChildObject), in: memory) : []
            let childrenStart = model.pieces.count + 1 + queue.count

            queue += childOffsets
            
            if object.groundPlateIndex != -1 {
                if groundPlateIndex == nil { groundPlateIndex = primitivesStart + Int(object.groundPlateIndex) }
                else { print("!?!? groundPlateIndex already assigned?") }
            }
            
            let piece = Piece(name: String(cString: memory + object.offsetToObjectName),
                              offset: object.offsetFromParent,
                              primitives: Array(primitivesStart..<model.primitives.endIndex),
                              children: Array(childrenStart..<(childrenStart + childOffsets.count)))
            model.pieces.append(piece)
        }
        
        if let index = groundPlateIndex { model.groundPlate = index }
        else { print("!?!? No groundPlateIndex found?") }
        
        return model
    }
    
    static func accumulateSiblingOffsets(atOffset start: Int, in memory: UnsafePointer<UInt8>) -> [Int] {
        var offsets: [Int] = []
        var offset = start
        while true {
            offsets.append(offset)
            let object = UnsafeRawPointer(memory + offset).bindMemory(to: TA_3DO_OBJECT.self, capacity: 1).pointee
            if object.offsetToSiblingObject != 0 { offset = Int(object.offsetToSiblingObject) }
            else { break }
        }
        return offsets
    }
    
}

private extension UnitModel.Texture {
    
    init(of raw: TA_3DO_PRIMITIVE, in memory: UnsafePointer<UInt8>) {
        if raw.offsetToTextureName != 0 {
            self = .image(String(cString: memory + raw.offsetToTextureName))
        }
        else {
            self = .color(Int(raw.color))
        }
    }
    
}

extension UnitModel.Texture: Equatable {
    
    static func ==(lhs: UnitModel.Texture, rhs: UnitModel.Texture) -> Bool {
        switch (lhs, rhs) {
        case let (.image(l), .image(r)): return l.caseInsensitiveCompare(r) == .orderedSame
        case let (.color(l), .color(r)): return l == r
        case (.image, _), (.color, _): return false
        }
    }
    
}

extension UnitModel.Texture: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .color(let c): return "Color:\(c)"
        case .image(let i): return "Texture:"+i
        }
    }
    
}

extension UnitModel.ModelData {
    
    init(reservingCapacity counts: UnitModel.ModelCounts) {
        pieces.reserveCapacity(counts.pieces)
        primitives.reserveCapacity(counts.primitives)
        vertices.reserveCapacity(counts.vertices)
    }
    
}

extension UnitModel.ModelCounts {
    
    init(for object: TA_3DO_OBJECT) {
        pieces = 1
        primitives = Int(object.numberOfPrimitives)
        vertices = Int(object.numberOfVertexes)
    }
    
    init(startingAt offset: Int, in memory: UnsafePointer<UInt8>) {
        
        let object = UnsafeRawPointer(memory + offset).bindMemory(to: TA_3DO_OBJECT.self, capacity: 1).pointee
        
        let siblings: UnitModel.ModelCounts
        if object.offsetToSiblingObject != 0 {
            siblings = UnitModel.ModelCounts(startingAt: Int(object.offsetToSiblingObject), in: memory)
        }
        else { siblings = UnitModel.ModelCounts.zero }
        
        let children: UnitModel.ModelCounts
        if object.offsetToChildObject != 0 {
            children = UnitModel.ModelCounts(startingAt: Int(object.offsetToChildObject), in: memory)
        }
        else { children = UnitModel.ModelCounts.zero }
        
        let union = UnitModel.ModelCounts(for: object) + siblings + children
        
        pieces = union.pieces
        primitives = union.primitives
        vertices = union.vertices
    }
    
    static var zero: UnitModel.ModelCounts {
        return UnitModel.ModelCounts()
    }
    
    static func +(lhs: UnitModel.ModelCounts, rhs: UnitModel.ModelCounts) -> UnitModel.ModelCounts {
        return UnitModel.ModelCounts(pieces: rhs.pieces + lhs.pieces,
                                     primitives: rhs.primitives + lhs.primitives,
                                     vertices: rhs.vertices + lhs.vertices)
    }
    
}

private extension RangeReplaceableCollection {
    
    mutating func append2(_ newElement: Self.Iterator.Element) -> Self.Index {
        let index = endIndex
        append(newElement)
        return index
    }
    
    mutating func append2<S>(contentsOf newElements: S) -> Self.Index
        where S : Sequence, S.Iterator.Element == Self.Iterator.Element {
        let index = endIndex
        append(contentsOf: newElements)
        return index
    }
    
}

// MARK:- Geometry 3DO Extensions

let ANGULAR_CONSTANT = 182.0
let LINEAR_CONSTANT = 163840.0 / 2.5

extension Vertex3 {
    
    init(_ v: TA_3DO_VERTEX) {
        x = Double(v.x) / LINEAR_CONSTANT
        y = Double(v.z) / LINEAR_CONSTANT
        z = Double(v.y) / LINEAR_CONSTANT
    }
    
}

extension TA_3DO_OBJECT {
    
    var offsetFromParent: Vector3 {
        return Vector3(
            x: Double(xFromParent) / LINEAR_CONSTANT,
            y: Double(zFromParent) / LINEAR_CONSTANT,
            z: Double(yFromParent) / LINEAR_CONSTANT
        )
    }
    
}
