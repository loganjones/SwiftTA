//
//  OpenglCore3UnitDrawable.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/4/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation

#if canImport(OpenGL)
import OpenGL
import OpenGL.GL3
#else
import Cgl
#endif


class OpenglCore3UnitDrawable {
    
    private let program: UnitProgram
    private var models: [UnitTypeId: Model] = [:]
    
    struct FrameState {
        fileprivate let instances: [UnitTypeId: [Instance]]
        fileprivate init(_ instances: [UnitTypeId: [Instance]]) {
            self.instances = instances
        }
    }
    
    init(_ units: [UnitTypeId: UnitData], sides: [SideInfo], filesystem: FileSystem) throws {
        
        program = try makeProgram()
        
        let textures = ModelTexturePack(loadFrom: filesystem)
        models = units.mapValues { try! Model($0, textures, sides, filesystem) }
    }
    
    func setupNextFrame(_ viewState: GameViewState) -> FrameState {
        return FrameState(buildInstanceList(
            for: viewState.objects,
            projectionMatrix: Matrix4x4f.ortho(Rect4f(size: viewState.viewport.size), -1024, 256),
            viewportPosition: viewState.viewport.origin))
    }
    
    func drawFrame(_ frameState: FrameState) {
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        glUseProgram(program.id)
        glUniform1i(program.uniform_texture, 0)
        
        for (unitType, instances) in frameState.instances {
            guard let model = models[unitType] else { continue }
            glBindTexture(GLenum(GL_TEXTURE_2D), model.texture.id)
            glBindVertexArray(model.buffer.vao)
            for instance in instances {
                glUniform4x4(program.uniform_vpMatrix, instance.vpMatrix)
                glUniform3x3(program.uniform_normalMatrix, instance.normalMatrix)
                glUniform4x4(program.uniform_pieces, instance.transformations)
                glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(model.vertexCount))
            }
        }
        
    }
    
    private func buildInstanceList(for objects: [GameViewObject], projectionMatrix: Matrix4x4f, viewportPosition: Point2f) -> [UnitTypeId: [Instance]] {
        var instances: [UnitTypeId: [Instance]] = [:]
        
        for case let .unit(unit) in objects {
            let viewMatrix = Matrix4x4f.translation(unit.position.x - viewportPosition.x, unit.position.y - viewportPosition.y, 0) * Matrix4x4f.taPerspective
            
            var draw = Instance(pieceCount: unit.pose.pieces.count)
            draw.vpMatrix = projectionMatrix * viewMatrix
            draw.normalMatrix = Matrix3x3f(topLeftOf: viewMatrix).inverseTranspose
            OpenglCore3UnitDrawable.Instance.applyPieceTransformations(orientation: unit.orientation, model: unit.type.model, instance: unit.pose, transformations: &draw.transformations)
            
            instances[unit.type.id, default: []].append(draw)
        }
        
        return instances
    }
    
}

// MARK:- Model

private extension OpenglCore3UnitDrawable {
    struct Model {
        var buffer: OpenglVertexBufferResource
        var vertexCount: Int
        var texture: OpenglTextureResource
    }
}

private extension OpenglCore3UnitDrawable.Model {
    
    init(_ unit: UnitData, _ textures: ModelTexturePack, _ sides: [SideInfo], _ filesystem: FileSystem) throws {
        
        let palette = try Palette.texturePalette(for: unit.info, in: sides, from: filesystem)
        let atlas = UnitTextureAtlas(for: unit.model.textures, from: textures)
        let texture = try makeTexture(atlas, palette, filesystem)
        
        let vertexCount = countVertices(in: unit.model)
        var arrays = VertexArrays(capacity: vertexCount)
        collectVertexAttributes(pieceIndex: unit.model.root, model: unit.model, textures: atlas, vertexArray: &arrays)
        
        let buffer = OpenglVertexBufferResource(bufferCount: 4)
        glBindVertexArray(buffer.vao)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer.vbo[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), arrays.positions, GLenum(GL_STATIC_DRAW))
        let vertexAttrib: GLuint = 0
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_GAMEFLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer.vbo[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), arrays.normals, GLenum(GL_STATIC_DRAW))
        let normalAttrib: GLuint = 1
        glVertexAttribPointer(normalAttrib, 3, GLenum(GL_GAMEFLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(normalAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer.vbo[2])
        glBufferData(GLenum(GL_ARRAY_BUFFER), arrays.texCoords, GLenum(GL_STATIC_DRAW))
        let texAttrib: GLuint = 2
        glVertexAttribPointer(texAttrib, 2, GLenum(GL_GAMEFLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(texAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer.vbo[3])
        glBufferData(GLenum(GL_ARRAY_BUFFER), arrays.pieceIndices.map { UInt8($0) }, GLenum(GL_STATIC_DRAW))
        let pieceAttrib: GLuint = 3
        glVertexAttribIPointer(pieceAttrib, 1, GLenum(GL_UNSIGNED_BYTE), 0, nil)
        glEnableVertexAttribArray(pieceAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.buffer = buffer
        self.vertexCount = vertexCount
        self.texture = texture
    }
    
}

private func countVertices(in model: UnitModel) -> Int {
    return model.primitives.reduce(0) {
        (count, primitive) in
        let num = primitive.indices.count
        return count + (num >= 3 ? (num - 2) * 3 : 0)
    }
}

private func collectVertexAttributes(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, textures: UnitTextureAtlas, vertexArray: inout VertexArrays) {
    
    let piece = model.pieces[pieceIndex]
    
    for primitiveIndex in piece.primitives {
        guard primitiveIndex != model.groundPlate else { continue }
        collectVertexAttributes(primitive: model.primitives[primitiveIndex], pieceIndex: pieceIndex, model: model, textures: textures, vertexArray: &vertexArray)
    }
    
    for child in piece.children {
        collectVertexAttributes(pieceIndex: child, model: model, textures: textures, vertexArray: &vertexArray)
    }
}

private func collectVertexAttributes(primitive: UnitModel.Primitive, pieceIndex: UnitModel.Pieces.Index, model: UnitModel, textures: UnitTextureAtlas, vertexArray: inout VertexArrays) {
    
    let vertices = primitive.indices.map({ model.vertices[$0] })
    let texCoords = textures.textureCoordinates(for: primitive.texture)
    
    switch vertices.count {
        
    case Int.min..<0: () // What?
    case 0: () // No Vertices
    case 1: () // A point?
    case 2: () // A line. Often used as a vector for sfx emitters
        
    case 3: // Single Triangle
        // Triangle 0,2,1
        let normal = makeNormal(0,2,1, in: vertices)
        vertexArray.append(
               texCoords.0, vertices[0],
               texCoords.2, vertices[2],
               texCoords.1, vertices[1],
               normal, pieceIndex
        )
        
    case 4: // Single Quad, split into two triangles
        // Triangle 0,2,1
        let normal = makeNormal(0,2,1, in: vertices)
        vertexArray.append(
               texCoords.0, vertices[0],
               texCoords.2, vertices[2],
               texCoords.1, vertices[1],
               normal, pieceIndex
        )
        // Triangle 0,3,2
        vertexArray.append(
               texCoords.0, vertices[0],
               texCoords.3, vertices[3],
               texCoords.2, vertices[2],
               normal, pieceIndex
        )
        
    default: // Polygon with more than 4 sides
        let normal = makeNormal(0,2,1, in: vertices)
        for n in 2 ..< vertices.count {
            vertexArray.append(
                   texCoords.0, vertices[0],
                   texCoords.2, vertices[n],
                   texCoords.1, vertices[n-1],
                   normal, pieceIndex
            )
        }
    }
}

private func makeNormal(_ a: Int, _ b: Int, _ c: Int, in vertices: [Vertex3f]) -> Vector3f {
    let v1 = vertices[a]
    let v2 = vertices[b]
    let v3 = vertices[c]
    let u = v2 - v1
    let v = v3 - v1
    return u × v
}

private struct VertexArrays {
    var positions: [Vertex3f]
    var normals: [Vector3f]
    var texCoords: [Vertex2f]
    var pieceIndices: [Int]
    
    init() {
        positions = []
        normals = []
        texCoords = []
        pieceIndices = []
    }
    init(capacity: Int) {
        positions = []
        positions.reserveCapacity(capacity)
        normals = []
        normals.reserveCapacity(capacity)
        texCoords = []
        texCoords.reserveCapacity(capacity)
        pieceIndices = []
        pieceIndices.reserveCapacity(capacity)
    }
    
    mutating func append(_ texCoord1: Vertex2f, _ vertex1: Vertex3f,
                         _ texCoord2: Vertex2f, _ vertex2: Vertex3f,
                         _ texCoord3: Vertex2f, _ vertex3: Vertex3f,
                         _ normal: Vector3f,
                         _ pieceIndex: Int) {
        
        positions.append(vertex1)
        texCoords.append(texCoord1)
        normals.append(normal)
        pieceIndices.append(pieceIndex)
        
        positions.append(vertex2)
        texCoords.append(texCoord2)
        normals.append(normal)
        pieceIndices.append(pieceIndex)
        
        positions.append(vertex3)
        texCoords.append(texCoord3)
        normals.append(normal)
        pieceIndices.append(pieceIndex)
    }
    
    mutating func clear() {
        positions = []
        normals = []
        texCoords = []
        pieceIndices = []
    }
}

private func makeTexture(_ textureAtlas: UnitTextureAtlas, _ palette: Palette, _ filesystem: FileSystem) throws -> OpenglTextureResource {
    
    let data = textureAtlas.build(from: filesystem, using: palette)
    
    let texture = OpenglTextureResource()
    glBindTexture(GLenum(GL_TEXTURE_2D), texture.id)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT )
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT )
    
    data.withUnsafeBytes {
        glTexImage2D(
            GLenum(GL_TEXTURE_2D),
            0,
            GLint(GL_RGBA),
            GLsizei(textureAtlas.size.width),
            GLsizei(textureAtlas.size.height),
            0,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            $0.baseAddress!)
    }
    
    printGlErrors(prefix: "Model Texture: ")
    return texture
}

// MARK:- Instance

private extension OpenglCore3UnitDrawable {
    struct Instance {
        var vpMatrix: Matrix4x4f
        var normalMatrix: Matrix3x3f
        var transformations: [Matrix4x4f]
    }
}

private extension OpenglCore3UnitDrawable.Instance {
    
    init(pieceCount: Int) {
        vpMatrix = .identity
        normalMatrix = .identity
        transformations = [Matrix4x4f](repeating: .identity, count: pieceCount)
    }
    
    static func applyPieceTransformations(orientation: Vector3f, model: UnitModel, instance: UnitModel.Instance, transformations: inout [Matrix4x4f]) {
        let initial = Matrix4x4f.rotation(radians: -orientation.z, axis: Vector3f(0,0,1))
        applyPieceTransformations(pieceIndex: model.root, p: initial, model: model, instance: instance, transformations: &transformations)
    }
    
    static func applyPieceTransformations(pieceIndex: UnitModel.Pieces.Index, p: Matrix4x4f, model: UnitModel, instance: UnitModel.Instance, transformations: inout [Matrix4x4f]) {
        let piece = model.pieces[pieceIndex]
        let anims = instance.pieces[pieceIndex]
        
        guard !anims.hidden else {
            applyPieceDiscard(pieceIndex: pieceIndex, model: model, transformations: &transformations)
            return
        }
        
        let offset = piece.offset
        let move = anims.move
        
        let deg2rad = GameFloat.pi / 180
        let sin: Vector3f = anims.turn.map { ($0 * deg2rad).sine }
        let cos: Vector3f = anims.turn.map { ($0 * deg2rad).cosine }
        
        let t = Matrix4x4f(
            cos.y * cos.z,
            (sin.y * cos.x) + (sin.x * cos.y * sin.z),
            (sin.x * sin.y) - (cos.x * cos.y * sin.z),
            0,
            
            -sin.y * cos.z,
            (cos.x * cos.y) - (sin.x * sin.y * sin.z),
            (sin.x * cos.y) + (cos.x * sin.y * sin.z),
            0,
            
            sin.z,
            -sin.x * cos.z,
            cos.x * cos.z,
            0,
            
            offset.x - move.x,
            offset.y - move.z,
            offset.z + move.y,
            1
        )
        
        let pt = p * t
        transformations[pieceIndex] = pt
        
        for child in piece.children {
            applyPieceTransformations(pieceIndex: child, p: pt, model: model, instance: instance, transformations: &transformations)
        }
    }
    
    static func applyPieceDiscard(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, transformations: inout [Matrix4x4f]) {
        
        transformations[pieceIndex] = Matrix4x4f.translation(0, 0, -1000)
        
        let piece = model.pieces[pieceIndex]
        for child in piece.children {
            applyPieceDiscard(pieceIndex: child, model: model, transformations: &transformations)
        }
    }
    
}

// MARK:- Shader Loading

private struct UnitProgram {
    
    let id: GLuint
    
    let uniform_vpMatrix: GLint
    let uniform_normalMatrix: GLint
    let uniform_pieces: GLint
    let uniform_texture: GLint
    
    init(_ program: GLuint) {
        id = program
        uniform_vpMatrix = glGetUniformLocation(program, "vpMatrix")
        uniform_normalMatrix = glGetUniformLocation(program, "normalMatrix")
        uniform_pieces = glGetUniformLocation(program, "pieces")
        uniform_texture = glGetUniformLocation(program, "colorTexture")
    }
    
    init() {
        id = 0
        uniform_vpMatrix = -1
        uniform_normalMatrix = -1
        uniform_pieces = -1
        uniform_texture = -1
    }
    
    static var unset: UnitProgram { return UnitProgram() }
    
}

private func makeProgram() throws -> UnitProgram {
    
    let vertexShader = try compileShader(GLenum(GL_VERTEX_SHADER), source: vertexShaderCode)
    let fragmentShader = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderCode)
    let program = try linkShaders(vertexShader, fragmentShader)
    
    glDeleteShader(fragmentShader)
    glDeleteShader(vertexShader)
    
    printGlErrors(prefix: "Shader Programs: ")
    return UnitProgram(program)
}

private let vertexShaderCode: String = """
    #version 330 core

    layout (location = 0) in vec3 in_position;
    layout (location = 1) in vec3 in_normal;
    layout (location = 2) in vec2 in_texture;
    layout (location = 3) in uint in_offset;

    out vec3 fragment_position_m;
    out vec3 fragment_normal;
    smooth out vec2 fragment_texture;

    uniform mat4 vpMatrix;
    uniform mat3 normalMatrix;
    uniform mat4 pieces[40];

    void main(void) {
        vec4 position = pieces[in_offset] * vec4(in_position, 1.0);
        gl_Position = vpMatrix * position;
        fragment_position_m = vec3(position);
        fragment_normal = normalMatrix * in_normal;
        fragment_texture = in_texture;
    }
    """

private let fragmentShaderCode: String = """
    #version 330 core
    precision highp float;

    smooth in vec2 fragment_texture;

    out vec4 out_color;

    uniform sampler2D colorTexture;

    void main(void) {
        out_color = texture(colorTexture, fragment_texture);
    }
    """
//private let fragmentShaderCode: String = """
//    #version 330 core
//    precision highp float;
//
//    in vec3 fragment_position_m;
//    in vec3 fragment_normal;
//    smooth in vec2 fragment_texture;
//
//    out vec4 out_color;
//
//    uniform sampler2D colorTexture;
//    uniform vec3 lightPosition;
//    uniform vec3 viewPosition;
//    uniform vec4 objectColor;
//
//    void main(void) {
//
//        vec3 lightColor = vec3(1.0, 1.0, 1.0);
//
//        // ambient
//        float ambientStrength = 0.6;
//        vec3 ambient = ambientStrength * lightColor;
//
//        // diffuse
//        float diffuseStrength = 0.4;
//        vec3 norm = normalize(fragment_normal);
//        vec3 lightDir = normalize(lightPosition - fragment_position_m);
//        float diff = max(dot(norm, lightDir), 0.0);
//        vec3 diffuse = diffuseStrength * diff * lightColor;
//
//        // specular
//        float specularStrength = 0.1;
//        vec3 viewDir = normalize(viewPosition - fragment_position_m);
//        vec3 reflectDir = reflect(-lightDir, norm);
//        float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
//        vec3 specular = specularStrength * spec * lightColor;
//
//        // all together now
//        vec4 lightContribution = vec4(ambient + diffuse + specular, 1.0);
//
//        if (objectColor.a == 0.0) {
//            out_color = lightContribution * texture(colorTexture, fragment_texture);
//        }
//        else {
//            out_color = lightContribution * objectColor;
//        }
//
//    }
//    """
