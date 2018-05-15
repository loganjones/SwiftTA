//
//  ModelView.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL
import OpenGL.GL3
import GLKit


class Model3DOView: NSOpenGLView {
    
    private var toload: ToLoad?
    
    private var model: GLBufferedStaticModel?
    private var dummyTransformations: [GLKMatrix4] = []
    private var modelTexture: GLuint = 0
    private var program_unlit: GLuint = 0
    private var program_lighted: GLuint = 0
    private var uniform_model: GLint = 0
    private var uniform_view: GLint = 0
    private var uniform_projection: GLint = 0
    private var uniform_pieces: GLint = 0
    private var uniform_lightPosition: GLint = 0
    private var uniform_viewPosition: GLint = 0
    private var uniform_texture: GLint = 0
    private var uniform_objectColor: GLint = 0
    
    private var viewportSize = CGSize()
    private var currentProgram: GLuint = 0
    private var changeProgram: GLuint? = nil
    
    private var aspectRatio: Float = 1
    private var sceneSize: (width: Float, height: Float) = (0,0)
    
    enum DrawMode: Int {
        case solid
        case wireframe
        case outlined
    }
    private var drawMode = DrawMode.outlined
    private var textured = false
    private var lighted = true
    
    private var trackingMouse = false
    private var rotateZ: GLfloat = 160
    private var rotateX: GLfloat = 0
    private var rotateY: GLfloat = 0
    
    private let showAxes = false
    
    override init(frame frameRect: NSRect) {
        let attributes : [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAAllowOfflineRenderers),
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFADepthSize), UInt32(24),
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            0
        ]
        let format = NSOpenGLPixelFormat(attributes: attributes)
        super.init(frame: frameRect, pixelFormat: format)!
        wantsBestResolutionOpenGLSurface = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var frame: NSRect {
        didSet { viewportSize = convertToBacking(bounds).size }
    }
    
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        guard let context = openGLContext
            else { return }
        
        var swapInt: GLint = 1
        context.setValues(&swapInt, for: .swapInterval)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        drawFrame()
    }
    
    fileprivate func drawFrame() {
        
        guard let context = openGLContext
            else { return }
        context.makeCurrentContext()
        CGLLockContext(context.cglContextObj!)
        
        makeProgram()
        
        if let program = changeProgram {
            currentProgram = program
            
            uniform_model = glGetUniformLocation(program, "model")
            uniform_view = glGetUniformLocation(program, "view")
            uniform_projection = glGetUniformLocation(program, "projection")
            uniform_pieces = glGetUniformLocation(program, "pieces")
            uniform_lightPosition = glGetUniformLocation(program, "lightPosition")
            uniform_viewPosition = glGetUniformLocation(program, "viewPosition")
            uniform_texture = glGetUniformLocation(program, "colorTexture")
            uniform_objectColor = glGetUniformLocation(program, "objectColor")
            
            changeProgram = nil
        }
        
        if let toload = toload {
            self.model = nil
            self.model = GLBufferedStaticModel(toload.model)
            self.dummyTransformations = [GLKMatrix4](repeating: GLKMatrix4Identity, count: toload.model.pieces.count)
            self.toload = nil
        }
        
        drawScene()
        glFlush()
        
        CGLFlushDrawable(context.cglContextObj!)
        CGLUnlockContext(context.cglContextObj!)
    }
    
    private func drawScene() {
        
        reshape(viewport: viewportSize)
        initScene()
        
        glClearColor(1, 1, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        let projection = GLKMatrix4MakeOrtho(0, sceneSize.width, sceneSize.height, 0, -1024, 256)
        
        let centering = GLKMatrix4MakeTranslation(sceneSize.width / 2, sceneSize.height / 2, 0)
        let flatten = GLKMatrix4Make(
            -1,   0,   0,   0,
            0,   1,   0,   0,
            0,-0.5,   1,   0,
            0,   0,   0,   1
        )
        let view = GLKMatrix4Multiply(centering, flatten)
        
        let model = GLKMatrix4Rotate(GLKMatrix4Identity, -rotateZ * (Float.pi / 180.0), 0, 0, 1)
        
        glUseProgram(currentProgram)
        glUniformGLKMatrix4(uniform_model, model)
        glUniformGLKMatrix4(uniform_view, view)
        glUniformGLKMatrix4(uniform_projection, projection)
        glUniformGLKMatrix4(uniform_pieces, dummyTransformations)
        
        let lightPosition = GLKVector3Make(50, 50, 100)
        let viewPosition = GLKVector3Make(sceneSize.width / 2, sceneSize.height / 2, 0)
        glUniformGLKVector3(uniform_lightPosition, lightPosition)
        glUniformGLKVector3(uniform_viewPosition, viewPosition)
        
        glActiveTexture(GLenum(GL_TEXTURE0));
        glBindTexture(GLenum(GL_TEXTURE_2D), modelTexture);
        glUniform1i(uniform_texture, 0);
        
        if let unitmodel = self.model { draw(unitmodel) }
        
        glBindVertexArray(0)
        glUseProgram(0)
    }
    
    private func draw<T: Drawable>(_ model: T) {
        switch drawMode {
        case .solid:
            glUniformGLKVector4(uniform_objectColor, textured ? GLKVector4Make(0, 0, 0, 0) : GLKVector4Make(0.95, 0.85, 0.80, 1))
            model.drawFilled()
        case .wireframe:
            glUniformGLKVector4(uniform_objectColor, GLKVector4Make(0.4, 0.35, 0.3, 1))
            model.drawWireframe()
        case .outlined:
            glUniformGLKVector4(uniform_objectColor, textured ? GLKVector4Make(0, 0, 0, 0) : GLKVector4Make(0.95, 0.85, 0.80, 1))
            
            glEnable(GLenum(GL_POLYGON_OFFSET_FILL))
            glPolygonOffset(1.0, 1.0)
            model.drawFilled()
            glDisable(GLenum(GL_POLYGON_OFFSET_FILL))
            
            glUniformGLKVector4(uniform_objectColor, textured ? GLKVector4Make(0.95, 0.85, 0.80, 1) : GLKVector4Make(0.4, 0.35, 0.3, 1))
            model.drawWireframe()
        }
    }
    
    private struct ToLoad {
        var model: UnitModel
    }
    
    func load(_ model: UnitModel) throws {
        let toload = ToLoad(
            model: model)
        self.toload = toload
    }
    
    private func makeTexture(_ texture: UnitTextureAtlas, _ filesystem: FileSystem, _ palette: Palette) {
        let data = texture.build(from: filesystem, using: palette)
        makeTexture(texture, data)
    }
    
    private func makeTexture(_ texture: UnitTextureAtlas, _ data: Data) {
        
        var textureId: GLuint = 0
        glGenTextures(1, &textureId)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureId)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT )
        
        data.withUnsafeBytes {
            glTexImage2D(
                GLenum(GL_TEXTURE_2D),
                0,
                GLint(GL_RGBA),
                GLsizei(texture.size.width),
                GLsizei(texture.size.height),
                0,
                GLenum(GL_RGBA),
                GLenum(GL_UNSIGNED_BYTE),
                $0)
        }
        
        modelTexture = textureId
        printGlErrors()
    }
    
    private func makeProgram() {
        guard program_unlit == 0 else { return }
        guard let vertexShaderUrl = Bundle.main.url(forResource: "unit-view.glsl", withExtension: "vert") else { return }
        guard let fragmentShaderUrl = Bundle.main.url(forResource: "unit-view.glsl", withExtension: "frag") else { return }
        guard let fragmentShaderLightedUrl = Bundle.main.url(forResource: "unit-view-lighted.glsl", withExtension: "frag") else { return }
        
        do {
            let vertexShaderCode = try String(contentsOf: vertexShaderUrl)
            let fragmentShaderCode = try String(contentsOf: fragmentShaderUrl)
            let fragmentShaderLightedCode = try String(contentsOf: fragmentShaderLightedUrl)
            
            let vertexShader = try compileShader(GLenum(GL_VERTEX_SHADER), source: vertexShaderCode)
            let fragmentShader = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderCode)
            let fragmentShaderLighted = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderLightedCode)
            program_unlit = try linkShaders(vertexShader, fragmentShader)
            program_lighted = try linkShaders(vertexShader, fragmentShaderLighted)
            
            glDeleteShader(fragmentShaderLighted)
            glDeleteShader(fragmentShader)
            glDeleteShader(vertexShader)
            
            changeProgram = lighted ? program_lighted : program_unlit
        }
        catch {
            print("Shader setup failed:\n\(error)")
        }
        
        printGlErrors()
    }
    
    private func printGlErrors() {
        var err = GL_NO_ERROR
        repeat {
            err = Int32(glGetError())
            if (err != GL_NO_ERROR) {
                Swift.print("GL ERROR: \(err)")
            }
        } while (err != GL_NO_ERROR)
    }
    
    private func initScene() {
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glEnable(GLenum(GL_LINE_SMOOTH))
        glEnable(GLenum(GL_POLYGON_SMOOTH))
        glHint(GLenum(GL_LINE_SMOOTH_HINT), GLenum(GL_NICEST))
        glHint(GLenum(GL_POLYGON_SMOOTH_HINT), GLenum(GL_NICEST))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        glTexEnvf(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GLfloat(GL_MODULATE))
    }
    
    private func reshape(viewport: CGSize) {
        glViewport(0, 0, GLsizei(viewport.width), GLsizei(viewport.height))
        
        aspectRatio = Float(viewport.height) / Float(viewport.width)
        let w: Float = 160
        sceneSize = (width: w, height: w * aspectRatio)
    }
    
    override func mouseDown(with event: NSEvent) {
        trackingMouse = true
    }
    
    override func mouseUp(with event: NSEvent) {
        trackingMouse = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        if trackingMouse {
            if event.modifierFlags.contains(.shift) { rotateX += GLfloat(event.deltaX) }
            else if event.modifierFlags.contains(.option) { rotateY += GLfloat(event.deltaX) }
            else { rotateZ += GLfloat(event.deltaX) }
            setNeedsDisplay(bounds)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.characters {
        case .some("w"):
            let i = drawMode.rawValue
            if let mode = DrawMode(rawValue: i+1) { drawMode = mode }
            else { drawMode = .solid }
            setNeedsDisplay(bounds)
        case .some("t"):
            textured = !textured
            setNeedsDisplay(bounds)
        case .some("l"):
            lighted = !lighted
            changeProgram = lighted ? program_lighted : program_unlit
            setNeedsDisplay(bounds)
        default:
            ()
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

// MARK:- Drawables

private protocol Drawable {
    func drawFilled()
    func drawWireframe()
}

// MARK:- Draw Instance (VBO & VAO)

private class GLBufferedStaticModel: Drawable {
    
    private let vao: GLuint
    private let vbo: [GLuint]
    private let elementCount: Int
    
    private let vaoOutline: GLuint
    private let vboOutline: [GLuint]
    private let elementCountOutline: Int
    
    fileprivate var model: UnitModel
    
    init(_ model: UnitModel) {
        
        var buffers = Buffers()
        GLBufferedStaticModel.collectVertexAttributes(pieceIndex: model.root, model: model, buffers: &buffers)
        elementCount = buffers.vertices.count
        
        var vao: GLuint = 0
        glGenVertexArrays(1, &vao)
        glBindVertexArray(vao)
        self.vao = vao
        
        var vbo = [GLuint](repeating: 0, count: 4)
        glGenBuffers(GLsizei(vbo.count), &vbo)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.vertices, GLenum(GL_STATIC_DRAW))
        let vertexAttrib: GLuint = 0
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.normals, GLenum(GL_STATIC_DRAW))
        let normalAttrib: GLuint = 1
        glVertexAttribPointer(normalAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(normalAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[2])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.texCoords, GLenum(GL_STATIC_DRAW))
        let texAttrib: GLuint = 2
        glVertexAttribPointer(texAttrib, 2, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(texAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[3])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.pieceIndices.map { UInt8($0) }, GLenum(GL_STATIC_DRAW))
        let pieceAttrib: GLuint = 3
        glVertexAttribIPointer(pieceAttrib, 1, GLenum(GL_UNSIGNED_BYTE), 0, nil)
        glEnableVertexAttribArray(pieceAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.vbo = vbo
        
        buffers.clear()
        GLBufferedStaticModel.collectOutlines(pieceIndex: model.root, model: model, buffers: &buffers)
        elementCountOutline = buffers.vertices.count
        
        var vao2: GLuint = 0
        glGenVertexArrays(1, &vao2)
        glBindVertexArray(vao2)
        self.vaoOutline = vao2
        
        var vbo2 = [GLuint](repeating: 0, count: 2)
        glGenBuffers(GLsizei(vbo2.count), &vbo2)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo2[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.vertices, GLenum(GL_STATIC_DRAW))
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo2[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.pieceIndices.map { UInt8($0) }, GLenum(GL_STATIC_DRAW))
        glVertexAttribIPointer(pieceAttrib, 1, GLenum(GL_UNSIGNED_BYTE), 0, nil)
        glEnableVertexAttribArray(pieceAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.vboOutline = vbo2
        
        self.model = model
    }
    
    deinit {
        var vbo = self.vbo
        glDeleteBuffers(GLsizei(vbo.count), &vbo)
        
        var vao = self.vao
        glDeleteVertexArrays(1, &vao)
        
        var vbo2 = self.vboOutline
        glDeleteBuffers(GLsizei(vbo.count), &vbo2)
        
        var vao2 = self.vaoOutline
        glDeleteVertexArrays(1, &vao2)
    }
    
    func drawFilled() {
        glBindVertexArray(vao)
        glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(elementCount))
    }
    
    func drawWireframe() {
        glBindVertexArray(vaoOutline)
        glDrawArrays(GLenum(GL_LINES), 0, GLsizei(elementCountOutline))
    }
    
    private static func collectVertexAttributes(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, parentOffset: Vector3 = .zero, textures: UnitTextureAtlas? = nil, buffers: inout Buffers) {
        
        let piece = model.pieces[pieceIndex]
        let offset = piece.offset + parentOffset
        
        for primitiveIndex in piece.primitives {
            guard primitiveIndex != model.groundPlate else { continue }
            collectVertexAttributes(primitive: model.primitives[primitiveIndex], pieceIndex: pieceIndex, model: model, offset: offset, textures: textures, buffers: &buffers)
        }
        
        for child in piece.children {
            collectVertexAttributes(pieceIndex: child, model: model, parentOffset: offset, textures: textures, buffers: &buffers)
        }
    }
    
    private static func collectVertexAttributes(primitive: UnitModel.Primitive, pieceIndex: UnitModel.Pieces.Index, model: UnitModel, offset: Vector3, textures: UnitTextureAtlas?, buffers: inout Buffers) {
        
        let vertices = primitive.indices.map({ model.vertices[$0] + offset })
        let texCoords = textures?.textureCoordinates(for: primitive.texture) ?? (Vertex2.zero, Vertex2.zero, Vertex2.zero, Vertex2.zero)
        
        switch vertices.count {
            
        case Int.min..<0: () // What?
        case 0: () // No Vertices
        case 1: () // A point?
        case 2: () // A line. Often used as a vector for sfx emitters
            
        case 3: // Single Triangle
            // Triangle 0,2,1
            let normal = makeNormal(0,2,1, in: vertices)
            buffers.append(
                texCoords.0, vertices[0],
                texCoords.2, vertices[2],
                texCoords.1, vertices[1],
                normal, pieceIndex
            )
            
        case 4: // Single Quad, split into two triangles
            // Triangle 0,2,1
            let normal = makeNormal(0,2,1, in: vertices)
            buffers.append(
                texCoords.0, vertices[0],
                texCoords.2, vertices[2],
                texCoords.1, vertices[1],
                normal, pieceIndex
            )
            // Triangle 0,3,2
            buffers.append(
                texCoords.0, vertices[0],
                texCoords.3, vertices[3],
                texCoords.2, vertices[2],
                normal, pieceIndex
            )
            
        default: // Polygon with more than 4 sides
            let normal = makeNormal(0,2,1, in: vertices)
            for n in 2 ..< vertices.count {
                buffers.append(
                    texCoords.0, vertices[0],
                    texCoords.2, vertices[n],
                    texCoords.1, vertices[n-1],
                    normal, pieceIndex
                )
            }
        }
    }
    
    private static func collectOutlines(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, parentOffset: Vector3 = .zero, buffers: inout Buffers) {
        
        let piece = model.pieces[pieceIndex]
        let offset = piece.offset + parentOffset
        
        for primitiveIndex in piece.primitives {
            guard primitiveIndex != model.groundPlate else { continue }
            let primitive = model.primitives[primitiveIndex]
            let vertices = primitive.indices.map({ model.vertices[$0] + offset })
            for n in 1 ..< vertices.count {
                buffers.vertices.append(vertices[n-1])
                buffers.vertices.append(vertices[n])
                buffers.pieceIndices.append(pieceIndex)
                buffers.pieceIndices.append(pieceIndex)
            }
            let n = vertices.count - 1
            buffers.vertices.append(vertices[n])
            buffers.vertices.append(vertices[0])
            buffers.pieceIndices.append(pieceIndex)
            buffers.pieceIndices.append(pieceIndex)
        }
        
        for child in piece.children {
            collectOutlines(pieceIndex: child, model: model, parentOffset: offset, buffers: &buffers)
        }
    }
    
    private static func makeNormal(_ a: Int, _ b: Int, _ c: Int, in vertices: [Vertex3]) -> Vector3 {
        let v1 = vertices[a]
        let v2 = vertices[b]
        let v3 = vertices[c]
        let u = v2 - v1
        let v = v3 - v1
        return u × v
    }
    
    private struct Buffers {
        var vertices: [Vertex3]
        var normals: [Vector3]
        var texCoords: [Vertex2]
        var pieceIndices: [Int]
        
        init() {
            vertices = []
            normals = []
            texCoords = []
            pieceIndices = []
        }
        
        mutating func append(_ texCoord1: Vertex2, _ vertex1: Vertex3,
                             _ texCoord2: Vertex2, _ vertex2: Vertex3,
                             _ texCoord3: Vertex2, _ vertex3: Vertex3,
                             _ normal: Vector3,
                             _ pieceIndex: Int) {
            
            vertices.append(vertex1)
            texCoords.append(texCoord1)
            normals.append(normal)
            pieceIndices.append(pieceIndex)
            
            vertices.append(vertex2)
            texCoords.append(texCoord2)
            normals.append(normal)
            pieceIndices.append(pieceIndex)
            
            vertices.append(vertex3)
            texCoords.append(texCoord3)
            normals.append(normal)
            pieceIndices.append(pieceIndex)
        }
        
        mutating func clear() {
            vertices = []
            normals = []
            texCoords = []
            pieceIndices = []
        }
    }
    
}
