//
//  OpenglCore3FeatureDrawable.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/1/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation

#if canImport(OpenGL)
import OpenGL
import OpenGL.GL3
#else
import Cgl
#endif


class OpenglCore3FeatureDrawable {
    
    private let program: FeatureProgram
    private var features: [Feature] = []
    private var shadows: [Feature] = []
    
    init(_ features: [FeatureTypeId: MapFeatureInfo], containedIn map: MapModel, filesystem: FileSystem) throws {
        
        program = try makeProgram()
        
        let loaded = loadFeatures(features, andInstancesFrom: map, filesystem: filesystem)
        self.features = loaded.features
        self.shadows = loaded.shadows
        
    }
    
    func setupNextFrame(_ viewState: GameViewState) {
        
        let modelMatrix = Matrix4x4f.identity
        let viewMatrix = Matrix4x4f.translation(-Vector2f(viewState.viewport.origin), 0)
        let projectionMatrix = Matrix4x4f.ortho(Rect4f(size: viewState.viewport.size), -1024, 256)
        
        glUseProgram(program.id)
        glUniform4x4(program.uniform_mvp, projectionMatrix * viewMatrix * modelMatrix)
        glUniform1i(program.uniform_texture, 0)
    }
    
    func drawFrame() {
        let features = self.features
        let shadows = self.shadows
        
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glEnable(GLenum(GL_LINE_SMOOTH))
        glEnable(GLenum(GL_POLYGON_SMOOTH))
        glHint(GLenum(GL_LINE_SMOOTH_HINT), GLenum(GL_NICEST))
        glHint(GLenum(GL_POLYGON_SMOOTH_HINT), GLenum(GL_NICEST))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        glTexEnvf(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GLfloat(GL_MODULATE))
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        glUseProgram(program.id)
        
        for type in features {
            switch type {
            case .static(let feature):
                glBindTexture(GLenum(GL_TEXTURE_2D), feature.texture.id)
                glBindVertexArray(feature.instancesVertexBuffer.vao)
                glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(feature.instancesVertexCount))
            case .animated(_):
                ()
            }
        }
        
        for type in shadows {
            switch type {
            case .static(let feature):
                glBindTexture(GLenum(GL_TEXTURE_2D), feature.texture.id)
                glBindVertexArray(feature.instancesVertexBuffer.vao)
                glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(feature.instancesVertexCount))
            case .animated(_):
                ()
            }
        }
    }
    
}

private extension OpenglCore3FeatureDrawable {
    
    enum Feature {
        case `static`(StaticFeature)
        case animated(AnimatedFeature)
    }
    
    struct StaticFeature {
        var texture: OpenglTextureResource
        var textureSize: Size2<Int>
        var instancesVertexBuffer: OpenglVertexBufferResource
        var instancesVertexCount: Int
    }
    
    struct AnimatedFeature {
        var texture: OpenglTextureResource
        var textureSize: Size2<Int>
        var frames: Frame
        typealias Frame = (slice: Int, offset: Point2<Int>)
    }
    
    func loadFeatures(_ featureInfo: MapFeatureInfo.FeatureInfoCollection, andInstancesFrom map: MapModel, filesystem: FileSystem) -> (features: [Feature], shadows: [Feature]) {
        
        let palettes = MapFeatureInfo.loadFeaturePalettes(featureInfo, from: filesystem)
        let occurrences = groupFeatureOccurrences(map.featureMap)
        
        var features: [Feature] = []
        var shadows: [Feature] = []
        features.reserveCapacity(featureInfo.count)
        shadows.reserveCapacity(featureInfo.count/2)
        
        let shadowPalette = Palette.shadow
        
        MapFeatureInfo.collateFeatureGafItems(featureInfo, from: filesystem) {
            (name, info, item, gafHandle, gafListing) in
            
            guard let featureIndex = map.features.index(of: name) else { return }//.firstIndex(of: name) else { return }
            guard let occurrences = occurrences[featureIndex], !occurrences.isEmpty else { return }
            guard let gafFrames = try? item.extractFrames(from: gafHandle) else { return }
            guard let palette = palettes[info.world ?? ""] else { return }
            
            if gafFrames.count == 1 {
                if let texture = try? makeTexture(for: gafFrames[0], using: palette),
                    let instances = buildInstances(of: (gafFrames[0].size, gafFrames[0].offset, info.footprint), from: occurrences, in: map)
                {
                    features.append(.static(StaticFeature(texture: texture, textureSize: gafFrames[0].size, instancesVertexBuffer: instances.0, instancesVertexCount: instances.1)))
                }
                
                if let shadowName = info.shadowGafItemName,
                    let shadowItem = gafListing[shadowName],
                    let shadowFrame = try? shadowItem.extractFrame(index: 0, from: gafHandle),
                    let shadowTexture = try? makeTexture(for: shadowFrame, using: shadowPalette),
                    let shadowInstances = buildInstances(of: (shadowFrame.size, shadowFrame.offset, info.footprint), from: occurrences, in: map)
                {
                    shadows.append(.static(StaticFeature(texture: shadowTexture, textureSize: shadowFrame.size, instancesVertexBuffer: shadowInstances.0, instancesVertexCount: shadowInstances.1)))
                }
            }
            else {
                // TEMP
                print("TODO: Support animated map feature \(name) (\(gafFrames.count) frames)")
                let texture = try! makeTexture(for: gafFrames[0], using: palette)
                let instances = buildInstances(of: (gafFrames[0].size, gafFrames[0].offset, info.footprint), from: occurrences, in: map)!
                features.append(.static(StaticFeature(texture: texture, textureSize: gafFrames[0].size, instancesVertexBuffer: instances.0, instancesVertexCount: instances.1)))
            }
        }
        
        return (features, shadows)
    }
    
    func makeTexture(for gafFrame: GafItem.Frame, using palette: Palette) throws -> OpenglTextureResource {
        
        let texture = OpenglTextureResource()
        glBindTexture(GLenum(GL_TEXTURE_2D), texture.id)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT )
        
        let image = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: gafFrame.size.area * 4)
        defer { image.deallocate() }
        gafFrame.data.withUnsafeBytes() {
            (source: UnsafePointer<UInt8>) in
            for sourceIndex in 0..<gafFrame.size.area {
                let destinationIndex = sourceIndex * 4
                let colorIndex = Int(source[sourceIndex])
                image[destinationIndex+0] = palette[colorIndex].red
                image[destinationIndex+1] = palette[colorIndex].green
                image[destinationIndex+2] = palette[colorIndex].blue
                image[destinationIndex+3] = palette[colorIndex].alpha
            }
        }
        
        glTexImage2D(
            GLenum(GL_TEXTURE_2D),
            0,
            GLint(GL_RGBA),
            GLsizei(gafFrame.size.width),
            GLsizei(gafFrame.size.height),
            0,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            image.baseAddress!)
        
        return texture
    }
    
    enum TextureError: Swift.Error {
        case badTextureDescriptor
    }
    
    func groupFeatureOccurrences(_ featureMap: [Int?]) -> [Int: [Int]] {
        var featureOccurrences: [Int: [Int]] = [:]
        
        for i in featureMap.indices {
            guard let featureIndex = featureMap[i] else { continue }
            featureOccurrences[featureIndex, default: []].append(i)
        }
        
        return featureOccurrences
    }
    
    func buildInstances(of feature: (size: Size2<Int>, offset: Point2<Int>, footprint: Size2<Int>), from occurrenceIndices: [Int], in map: MapModel) -> (OpenglVertexBufferResource, Int)? {
        
        let vertexCount = occurrenceIndices.count * 6
        var vertices = (position: [Vertex3f](repeating: .zero, count: vertexCount), texCoord: [Vector2f](repeating: .zero, count: vertexCount))
        var index = 0
        
        for i in occurrenceIndices {
            
            let boundingBox = map.worldPosition(ofMapIndex: i)
                .center(inFootprint: feature.footprint)
                .offset(by: feature.offset)
                .adjust(forHeight: map.heightMap.samples[i])
                .makeRect(size: Size2f(feature.size))
            
            createRect(boundingBox, in: &vertices, &index)
            index += 6
        }
        
//        var vao: GLuint = 0
//        glGenVertexArrays(1, &vao)
//        glBindVertexArray(vao)
//
//        var vbo = [GLuint](repeating: 0, count: 2)
//        glGenBuffers(GLsizei(vbo.count), &vbo)
        let vertexBuffer = OpenglVertexBufferResource(bufferCount: 2)
        glBindVertexArray(vertexBuffer.vao)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer.vbo[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.position, GLenum(GL_STATIC_DRAW))
        let vertexAttrib: GLuint = 0
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_GAMEFLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer.vbo[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.texCoord, GLenum(GL_STATIC_DRAW))
        let texAttrib: GLuint = 1
        glVertexAttribPointer(texAttrib, 2, GLenum(GL_GAMEFLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(texAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        return (vertexBuffer, vertexCount)
    }
    
}

private extension OpenglCore3FeatureDrawable.Feature {
    
    var texture: OpenglTextureResource {
        switch self {
        case .static(let f): return f.texture
        case .animated(let f): return f.texture
        }
    }
    
    var size: Size2<Int> {
        switch self {
        case .static(let f):
            return f.textureSize
        case .animated(let f):
            return f.textureSize
        }
    }
    
}

private extension MapModel {
    func worldPosition(ofMapIndex index: Int) -> Point2<Int> {
        return Point2<Int>(index: index, stride: self.mapSize.width) * 16
    }
}
private extension Point2 where Element == Int {
    
    func center(inFootprint footprint: Size2<Int>) -> Point2<Int> {
        return self + Point2(footprint * 8)
    }
    
    func offset(by offset: Point2<Int>) -> Point2<Int> {
        return Point2(self - offset)
    }
    
    func adjust(forHeight height: Int) -> Point2f {
        var p = Point2f(self)
        p.y -= GameFloat(height) / 2.0
        return p
    }
    
}

private func createRect(_ rect: Rect4f, in vertices: inout (position: [Vertex3f], texCoord: [Vector2f]), _ index: inout Int) {
    
    let x = rect.origin.x
    let y = rect.origin.y
    let z = rect.maxY / (32000.0 / 256.0)//Double(10)
    let w = rect.size.width
    let h = rect.size.height
    
    vertices.position[index+0] = Vertex3f(x+0, y+0, z)
    vertices.texCoord[index+0] = Vector2f(0, 0)
    vertices.position[index+1] = Vertex3f(x+0, y+h, z)
    vertices.texCoord[index+1] = Vector2f(0, 1)
    vertices.position[index+2] = Vertex3f(x+w, y+h, z)
    vertices.texCoord[index+2] = Vector2f(1, 1)
    
    vertices.position[index+3] = Vertex3f(x+0, y+0, z)
    vertices.texCoord[index+3] = Vector2f(0, 0)
    vertices.position[index+4] = Vertex3f(x+w, y+h, z)
    vertices.texCoord[index+4] = Vector2f(1, 1)
    vertices.position[index+5] = Vertex3f(x+w, y+0, z)
    vertices.texCoord[index+5] = Vector2f(1, 0)
}


// MARK:- Shader Loading

private struct FeatureProgram {
    
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
    
    static var unset: FeatureProgram { return FeatureProgram() }
    
}

private func loadShaderCode(forResource name: String, withExtension ext: String) throws -> String {
    guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { throw RuntimeError("Neccessary shader file not found.") }
    return try String(contentsOf: url)
}

private func makeProgram() throws -> FeatureProgram {
    
    let vertexShader = try compileShader(GLenum(GL_VERTEX_SHADER), source: vertexShaderCode)
    let fragmentShader = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderCode)
    let program = try linkShaders(vertexShader, fragmentShader)
    
    glDeleteShader(fragmentShader)
    glDeleteShader(vertexShader)
    
    printGlErrors(prefix: "Shader Programs: ")
    return FeatureProgram(program)
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
        vec4 texel = texture(colorTexture, fragment_texture);
        if (texel.a < 0.2)
            discard;
        out_color = texel;
    }
    """
