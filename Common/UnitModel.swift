//
//  UnitModel.swift
//  TAassets
//
//  Created by Logan Jones on 2/19/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation
#if canImport(Ctypes)
import Ctypes
#endif

struct UnitModel {
    
    typealias Pieces = Array<Piece>
    typealias Primitives = Array<Primitive>
    typealias Vertices = Array<Vertex3f>
    typealias Textures = Array<Texture>
    
    var pieces: Pieces
    var primitives: Primitives
    var vertices: Vertices
    var textures: Textures
    
    var root: Pieces.Index
    var groundPlate: Primitives.Index
    
    var nameLookup: [String: Pieces.Index]
    
    init<File>(contentsOf file: File) throws
        where File: FileReadHandle
    {
        let fileData = file.readDataToEndOfFile()
        let model = fileData.withUnsafeBytes { UnitModel.loadModel(from: $0) }
        
        //UnitModel.dump(model)
        
        pieces = model.pieces
        primitives = model.primitives
        vertices = model.vertices
        textures = model.textures
        
        root = model.roots.first!
        groundPlate = model.groundPlate
        
        var names: [String: Pieces.Index] = [:]
        for (index, piece) in pieces.enumerated() {
            names[piece.name.lowercased()] = index
        }
        nameLookup = names
    }
    
    func piece(named name: String) -> Piece? {
        if let index = nameLookup[name] { return pieces[index] }
        else { return nil }
    }
    
    struct Piece {
        var name: String
        var offset: Vector3f
        var primitives: [Primitives.Index]
        var children: [Pieces.Index]
    }
    
    struct Primitive {
        var texture: Textures.Index
        var indices: [Vertices.Index]
    }
    
    enum Texture: Equatable {
        case image(String)
        case color(Int)
    }
    
}

extension UnitModel {
    struct PieceMap {
        var pieces: [Piece]
        var root: Array<Piece>.Index
        struct Piece {
            var parents: [Array<Piece>.Index]
            var children: [Array<Piece>.Index]
        }
        init(_ model: UnitModel) {
            root = model.root
            var pieces = model.pieces.map { Piece(parents: [], children: $0.children) }
            UnitModel.PieceMap.mapParents(of: model.root, in: &pieces)
            self.pieces = pieces
        }
        static func mapParents(of pieceIndex: Array<Piece>.Index, in pieces: inout Array<Piece>, parents: [Array<Piece>.Index] = []) {
            pieces[pieceIndex].parents = parents
            let newParents = parents + [pieceIndex]
            for childIndex in pieces[pieceIndex].children {
                mapParents(of: childIndex, in: &pieces, parents: newParents)
            }
        }
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
    
    static func loadModel(from memory: UnsafeRawBufferPointer) -> ModelData {
        
        let counts = ModelCounts(startingAt: 0, in: memory)
        var model = ModelData(reservingCapacity: counts)
        var queue = accumulateSiblingOffsets(atOffset: 0, in: memory)
        var groundPlateIndex: Primitives.Index? = nil
        
        model.roots = Array(0..<queue.count)
        
        while !queue.isEmpty {
            
            let offset = queue.remove(at: 0)
            let object = memory.load(fromByteOffset: offset, as: TA_3DO_OBJECT.self)

            let vertices = memory.bindMemory(atByteOffset: Int(object.offsetToVertexArray), count: Int(object.numberOfVertexes), to: TA_3DO_VERTEX.self)
                .map({ Vertex3($0) })
            let verticesStart = model.vertices.append2(contentsOf: vertices)
            
            let primitives = memory.bindMemory(atByteOffset: Int(object.offsetToPrimitiveArray), count: Int(object.numberOfPrimitives), to: TA_3DO_PRIMITIVE.self)
                .map { raw -> Primitive in
                    let texture = Texture(of: raw, in: memory)
                    let texIndex = model.textures.firstIndex(of: texture) ?? model.textures.append2(texture)
                    let indices = memory.bindMemory(atByteOffset: Int(raw.offsetToVertexIndexArray), count: Int(raw.numberOfVertexIndexes), to: UInt16.self)
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
            
            let piece = Piece(name: memory.loadCString(fromByteOffset: Int(object.offsetToObjectName)),
                              offset: object.offsetFromParent,
                              primitives: Array(primitivesStart..<model.primitives.endIndex),
                              children: Array(childrenStart..<(childrenStart + childOffsets.count)))
            model.pieces.append(piece)
        }
        
        if let index = groundPlateIndex { model.groundPlate = index }
        else { print("!?!? No groundPlateIndex found?") }
        
        return model
    }
    
    static func accumulateSiblingOffsets(atOffset start: Int, in memory: UnsafeRawBufferPointer) -> [Int] {
        var offsets: [Int] = []
        var offset = start
        while true {
            offsets.append(offset)
            let object = memory.load(fromByteOffset: offset, as: TA_3DO_OBJECT.self)
            if object.offsetToSiblingObject != 0 { offset = Int(object.offsetToSiblingObject) }
            else { break }
        }
        return offsets
    }
    
    static func dump(_ model: ModelData) {
        model.roots.forEach { pieceIndex in
            dumpPiece(at: pieceIndex, from: model)
        }
    }
    
    private static func dumpPiece(at pieceIndex: Int, from model: ModelData, level: Int = 0) {
        
        let prefix1 = String(repeating: "    ", count: level)
        let piece = model.pieces[pieceIndex]
        
        print(prefix1+"Piece #\(pieceIndex): \(piece.name)")
        let prefix2 = prefix1 + " "
        print(prefix2+"offset: \(piece.offset)")
        print(prefix2+"primitives: \(piece.primitives.count)")
        piece.primitives.forEach { primitiveIndex in
            let prefix3 = prefix2 + " "
            let primitive = model.primitives[primitiveIndex]
            print(prefix3+"Primitive #\(primitiveIndex)")
            let prefix4 = prefix3 + " "
            print(prefix4+"texture: #\(primitive.texture) -> \(model.textures[primitive.texture])")
            print(prefix4+"vertices: \(primitive.indices.count)")
            primitive.indices.forEach { vertexIndex in
                let prefix5 = prefix4 + " "
                print(prefix5+"Vertex #\(vertexIndex): \(model.vertices[vertexIndex])")
            }
        }
        
        print(prefix2+"children: \(piece.children.count)")
        piece.children.forEach { childIndex in
            dumpPiece(at: childIndex, from: model, level: level + 1)
        }
    }
    
}

private extension UnitModel.Texture {
    
    init(of raw: TA_3DO_PRIMITIVE, in memory: UnsafeRawBufferPointer) {
        if raw.offsetToTextureName != 0 {
            self = .image(memory.loadCString(fromByteOffset: Int(raw.offsetToTextureName)))
        }
        else {
            self = .color(Int(raw.color))
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
    
    init(startingAt offset: Int, in memory: UnsafeRawBufferPointer) {
        
        let object = memory.load(fromByteOffset: offset, as: TA_3DO_OBJECT.self)
        
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

let ANGULAR_CONSTANT: GameFloat = 65536.0 / 360.0
let LINEAR_CONSTANT: GameFloat = 163840.0 / 2.5

extension Vertex3 where Element == GameFloat {
    
    init(_ v: TA_3DO_VERTEX) {
        self.init(
            x: GameFloat(v.x) / LINEAR_CONSTANT,
            y: GameFloat(v.z) / LINEAR_CONSTANT,
            z: GameFloat(v.y) / LINEAR_CONSTANT
        )
    }
    
}

extension TA_3DO_OBJECT {
    
    var offsetFromParent: Vector3f {
        return Vector3f(
            x: GameFloat(xFromParent) / LINEAR_CONSTANT,
            y: GameFloat(zFromParent) / LINEAR_CONSTANT,
            z: GameFloat(yFromParent) / LINEAR_CONSTANT
        )
    }
    
}
