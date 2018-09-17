//
//  OpenglCore3OneTextureTntDrawable.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 9/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation
import OpenGL
import OpenGL.GL3
import GLKit


class OpenglCore3OneTextureTntDrawable: OpenglCore3TntDrawable {
    
    private let program: TntProgram
    private let texture: OpenglTextureResource
    private let textureSize: Size2D
    private let quad: TntQuadModel
    
    init(for map: MapModel, from filesystem: FileSystem) throws {
        
        program = try makeProgram()
        quad = TntQuadModel()
        
        switch map {
            
        case .ta(let map):
            let palette = try Palette.standardTaPalette(from: filesystem)
            texture = makeTexture(for: map, using: palette)
            textureSize = map.resolution
            
        case .tak(_):
            fatalError("Not implemented")
            //try tnt.load(map, from: loaded.filesystem)
        }
        
    }
    
    func setupNextFrame(_ viewState: GameViewState) {
        let (viewportPosition, quadOffset) = clamp(viewport: viewState.viewport, to: CGSize(textureSize))
        
        let modelMatrix = GLKMatrix4Identity
        let viewMatrix = GLKMatrix4MakeTranslation(Float(quadOffset.x), Float(quadOffset.y), 0)
        let projectionMatrix = GLKMatrix4MakeOrtho(0, Float(viewState.viewport.size.width), Float(viewState.viewport.size.height), 0, -1024, 256)
        
        glUseProgram(program.id)
        glUniformGLKMatrix4(program.uniform_mvp, projectionMatrix * viewMatrix * modelMatrix)
        glUniform1i(program.uniform_texture, 0)
        
        quad.setupNextFrame(viewportPosition, Vector2(viewState.viewport.size), Vector2(textureSize))
    }
    
    func drawFrame() {
        
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glEnable(GLenum(GL_LINE_SMOOTH))
        glEnable(GLenum(GL_POLYGON_SMOOTH))
        glHint(GLenum(GL_LINE_SMOOTH_HINT), GLenum(GL_NICEST))
        glHint(GLenum(GL_POLYGON_SMOOTH_HINT), GLenum(GL_NICEST))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        glTexEnvf(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GLfloat(GL_MODULATE))
        
        glActiveTexture(GLenum(GL_TEXTURE0));
        glBindTexture(GLenum(GL_TEXTURE_2D), texture.id);
        quad.draw()
    }
    
}

private func clamp(viewport: CGRect, to size: CGSize) -> (position: Vertex2, offset: Vector2) {
    let positionX: Double
    let positionY: Double
    let offsetX: Double
    let offsetY: Double
    
    if viewport.minX < 0 { offsetX = Double(-viewport.minX); positionX = 0 }
    else if viewport.maxX > size.width { offsetX = Double(size.width - viewport.maxX); positionX = Double(size.width - viewport.size.width) }
    else { offsetX = 0; positionX = Double(viewport.minX) }
    
    if viewport.minY < 0 { offsetY = Double(-viewport.minY); positionY = 0 }
    else if viewport.maxY > size.height { offsetY = Double(size.height - viewport.maxY); positionY = Double(size.height - viewport.size.height) }
    else { offsetY = 0; positionY = Double(viewport.minY) }
    
    return (Vertex2(positionX, positionY), Vector2(offsetX, offsetY))
}

// MARK:- Texture Loading

private func makeTexture(for map: TaMapModel, using palette: Palette) -> OpenglTextureResource {
    let beginAll = Date()
    
    let mapSize = map.resolution
    let textureSize = mapSize//.map { Int(UInt32($0).nextPowerOfTwo) }
    let tntTileSize = map.tileSet.tileSize
    
    let beginConversion = Date()
    let tileBuffer = map.convertTilesBGRA(using: palette)
    defer { tileBuffer.deallocate() }
    let endConversion = Date()
    
    let texture = OpenglTextureResource()
    glBindTexture(GLenum(GL_TEXTURE_2D), texture.id)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT )
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT )
    
    glTexImage2D(
        GLenum(GL_TEXTURE_2D),
        0,
        GLint(GL_RGBA),
        GLsizei(textureSize.width),
        GLsizei(textureSize.height),
        0,
        GLenum(GL_BGRA),
        GLenum(GL_UNSIGNED_BYTE),
        nil)
    
    let beginTexture = Date()
    map.tileIndexMap.eachIndex(inColumns: 0 ..< map.tileIndexMap.size.width, rows: 0 ..< map.tileIndexMap.size.height) {
        (index, column, row) in
        let tile = tileBuffer.baseAddress! + (index * tntTileSize.area * 4)
        glTexSubImage2D(
            GLenum(GL_TEXTURE_2D), 0,
            GLint(column * tntTileSize.width), GLint(row * tntTileSize.height),
            GLsizei(tntTileSize.width), GLsizei(tntTileSize.height),
            GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE),
            tile)
    }
    let endTexture = Date()
    let endAll = Date()
    
    print("""
        Tnt Texture load time: \(endAll.timeIntervalSince(beginAll)) seconds
          Tile Buffer: \(tileBuffer.count) bytes
          Conversion: \(endConversion.timeIntervalSince(beginConversion)) seconds
          Texture: \(textureSize) -> \(textureSize.area * 4) bytes
          Fill: \(endTexture.timeIntervalSince(beginTexture)) seconds
        """)
    printGlErrors(prefix: "Map Texture: ")
    return texture
}

// MARK:- Shader Loading

private struct TntProgram {
    
    let id: GLuint
    
    let uniform_mvp: GLint
    let uniform_texture: GLint
    
    init(_ program: GLuint) {
        id = program
        uniform_mvp = glGetUniformLocation(program, "mvpMatrix")
        uniform_texture = glGetUniformLocation(program, "colorTexture")
    }
    
    init() {
        id = 0
        uniform_mvp = -1
        uniform_texture = -1
    }
    
    static var unset: TntProgram { return TntProgram() }
    
}

private func loadShaderCode(forResource name: String, withExtension ext: String) throws -> String {
    guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { throw RuntimeError("Neccessary shader file not found.") }
    return try String(contentsOf: url)
}

private func makeProgram() throws -> TntProgram {
    
    let vertexShader = try compileShader(GLenum(GL_VERTEX_SHADER), source: vertexShaderCode)
    let fragmentShader = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderCode)
    let program = try linkShaders(vertexShader, fragmentShader)
    
    glDeleteShader(fragmentShader)
    glDeleteShader(vertexShader)
    
    printGlErrors(prefix: "Shader Programs: ")
    return TntProgram(program)
}

private let vertexShaderCode: String = """
    #version 330 core

    layout (location = 0) in vec3 in_position;
    layout (location = 1) in vec2 in_texture;

    smooth out vec2 fragment_texture;

    uniform mat4 mvpMatrix;

    void main(void) {
        fragment_texture = in_texture;
        gl_Position = mvpMatrix * vec4(in_position, 1.0);
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

// MARK:- Model

private class TntQuadModel {
    
    private let vao: GLuint
    private let vbo: [GLuint]
    
    init() {
        let vertices = [Vertex3](repeating: .zero, count: 4)
        let texCoords = [Vector2](repeating: .zero, count: 4)
        
        var vao: GLuint = 0
        glGenVertexArrays(1, &vao)
        glBindVertexArray(vao)
        self.vao = vao
        
        var vbo = [GLuint](repeating: 0, count: 2)
        glGenBuffers(GLsizei(vbo.count), &vbo)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices, GLenum(GL_STATIC_DRAW))
        let vertexAttrib: GLuint = 0
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), texCoords, GLenum(GL_STATIC_DRAW))
        let texAttrib: GLuint = 1
        glVertexAttribPointer(texAttrib, 2, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(texAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.vbo = vbo
        printGlErrors(prefix: "Map Geometry: ")
    }
    
    deinit {
        var vbo = self.vbo
        glDeleteBuffers(GLsizei(vbo.count), &vbo)
        
        var vao = self.vao
        glDeleteVertexArrays(1, &vao)
    }
    
    func setupNextFrame(_ viewportPosition: Vertex2, _ viewportSize: Vector2, _ texteureSize: Vector2) {
        let vx = viewportSize.x
        let vy = viewportSize.y
        let tx = viewportPosition.x / texteureSize.x
        let ty = viewportPosition.y / texteureSize.y
        let tw = viewportSize.x / texteureSize.x
        let th = viewportSize.y / texteureSize.y
        
        let vertices: [Vertex3] = [
            Vertex3( 0,  0, 0),
            Vertex3( 0, vy, 0),
            Vertex3(vx,  0, 0),
            Vertex3(vx, vy, 0),
        ]
        let texCoords: [Vector2] = [
            Vector2(tx, ty),
            Vector2(tx, ty+th),
            Vector2(tx+tw, ty),
            Vector2(tx+tw, ty+th),
        ]
        
        glBindVertexArray(vao)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[0])
        glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, vertices)
    
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[1])
        glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, texCoords)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
    }
    
    func draw() {
        glBindVertexArray(vao)
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
    }

}
