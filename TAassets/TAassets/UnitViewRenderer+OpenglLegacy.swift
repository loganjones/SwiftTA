//
//  UnitView+OpenglLegacyRenderer.swift
//  TAassets
//
//  Created by Logan Jones on 5/17/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL
import OpenGL.GL3


class LegacyOpenglUnitViewRenderer: OpenglUnitViewRenderer {
    
    static let desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFADoubleBuffer),
        UInt32(NSOpenGLPFAMinimumPolicy),
        UInt32(NSOpenGLPFADepthSize), UInt32(16),
        UInt32(NSOpenGLPFAAlphaSize), UInt32(8),
        0
    ]
    
    private var model: GLInstancePieces?
    private var modelTexture: OpenglTextureResource?
    
    private let gridSize = Size2<Int>(width: 16, height: 16)
    private let gridSpacing: Int = UnitViewState.gridSize
    
    init() {
        
    }
    
    func initializeOpenglState() {
        initScene()
    }
    
    func drawFrame(_ viewState: UnitViewState, _ currentTime: Double, _ deltaTime: Double) {
        drawScene(viewState)
    }
    
    func updateForAnimations(_ model: UnitModel, _ modelInstance: UnitModel.Instance) {
        self.model?.instance = modelInstance
    }
    
    func switchTo(_ instance: UnitModel.Instance, of model: UnitModel, with textureAtlas: UnitTextureAtlas, textureData: Data) {
        self.model = GLInstancePieces(instance, of: model, with: textureAtlas)
        modelTexture = makeTexture(textureAtlas, textureData)
    }
    
    func clear() {
        model = nil
        modelTexture = nil
    }
    
    var hasLoadedModel: Bool {
        return model != nil
    }
    
}

// MARK:- Setup

private extension LegacyOpenglUnitViewRenderer {
    
    func makeTexture(_ textureAtlas: UnitTextureAtlas, _ data: Data) -> OpenglTextureResource {
        
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
                $0)
        }
        
        printGlErrors(prefix: "Model Texture: ")
        return texture
    }
    
}

// MARK:- Rendering

private extension LegacyOpenglUnitViewRenderer {
    
    func initScene() {
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_POSITION), [ 5.0, 5.0, 10.0, 0.0 ])
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_AMBIENT), [ 0.8, 0.8, 0.8, 1 ])
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_DIFFUSE), [ 0.5, 0.5, 0.5, 1 ])
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_LIGHTING))
        glEnable(GLenum(GL_LIGHT0))
        glEnable(GLenum(GL_DEPTH_TEST))
        glEnable(GLenum(GL_NORMALIZE))
        glEnable(GLenum(GL_LINE_SMOOTH))
        glEnable(GLenum(GL_POLYGON_SMOOTH))
        glHint(GLenum(GL_LINE_SMOOTH_HINT), GLenum(GL_NICEST))
        glHint(GLenum(GL_POLYGON_SMOOTH_HINT), GLenum(GL_NICEST))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        glTexEnvf(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GLfloat(GL_MODULATE))
    }
    
    func reshape(_ viewState: UnitViewState) {
        glViewport(0, 0, GLsizei(viewState.viewportSize.width), GLsizei(viewState.viewportSize.height))
        
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        
        let scene = viewState.sceneSize
        glOrtho(0, GLdouble(scene.width), GLdouble(scene.height), 0, -1024, 256)
        
        glMatrixMode(GLenum(GL_MODELVIEW))
        glLoadIdentity()
        glTranslated(GLdouble(scene.width / 2), GLdouble(scene.height / 2), 0.0)
    }
    
    func drawScene(_ viewState: UnitViewState) {
        
        reshape(viewState)
        
        glClearColor(1, 1, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        glPushMatrix()
        
        let perspective: [GLfloat] = [
            -1,   0,   0,   0,
             0,   1,   0,   0,
             0,-0.5,   1,   0,
             0,   0,   0,   1
        ]
        glMultMatrixf(perspective)
        
        glRotatef(-viewState.rotateZ, 0.0, 0.0, 1.0)
        
        glRotatef(viewState.rotateX, 1.0, 0.0, 0.0)
        glRotatef(viewState.rotateY, 0.0, 1.0, 0.0)
        
        drawGrid(viewState)
        drawUnit(viewState)
        
        glPopMatrix()
    }
    
    func drawGrid(_ viewState: UnitViewState) {
        
        glDisable(GLenum(GL_TEXTURE_2D))
        glDisable(GLenum(GL_LIGHTING))
        glColor3dv([0.9, 0.9, 0.9, 1])
        glPushMatrix()
        
        let size = self.gridSize
        let gridSpacing = self.gridSpacing
        
        let psize = Size2(size * gridSpacing)
        glTranslatef(GLfloat(-psize.width / 2), GLfloat(-psize.height / 2) + GLfloat(viewState.movement), -0.5)
        
        var n = 0
        let addLine: (Vertex3f, Vertex3f) -> () = { (a, b) in glVertex(a); glVertex(b); n += 2 }
        let makeVert: (Int, Int) -> Vertex3f = { (w, h) in Vertex3f(x: GameFloat(w * gridSpacing), y: GameFloat(h * gridSpacing), z: 0) }
        
        glBegin(GLenum(GL_LINES))
        for h in 0..<size.height {
            for w in 0..<size.width {
                if h == 0 { addLine(makeVert(w,h), makeVert(w+1,h)) }
                addLine(makeVert(w+1,h), makeVert(w+1,h+1))
                addLine(makeVert(w+1,h+1), makeVert(w,h+1))
                if w == 0 { addLine(makeVert(w,h+1), makeVert(w,h)) }
            }
        }
        glEnd()
        
        glPopMatrix()
    }
    
    func drawUnit(_ viewState: UnitViewState) {
        
        glBindTexture(GLenum(GL_TEXTURE_2D), modelTexture?.id ?? 0)
        
        switch viewState.drawMode {
            
        case .solid:
            if viewState.textured { glEnable(GLenum(GL_TEXTURE_2D)) }
            else { glDisable(GLenum(GL_TEXTURE_2D)) }
            if viewState.lighted {
                glEnable(GLenum(GL_LIGHTING))
                glMaterialfv(GLenum(GL_FRONT), GLenum(GL_AMBIENT), [0.50, 0.40, 0.35, 1])
                glMaterialfv(GLenum(GL_FRONT), GLenum(GL_DIFFUSE), [0.45, 0.45, 0.45, 1])
            }
            else {
                glDisable(GLenum(GL_LIGHTING))
                glColor3dv([1, 1, 1, 1])
            }
            model?.drawFilled()
            
        case .wireframe:
            glDisable(GLenum(GL_TEXTURE_2D))
            glDisable(GLenum(GL_LIGHTING))
            glColor3dv([0.3, 0.3, 0.3, 1])
            model?.drawWireframe()
            
        case .outlined:
            if viewState.textured { glEnable(GLenum(GL_TEXTURE_2D)) }
            else { glDisable(GLenum(GL_TEXTURE_2D)) }
            if viewState.lighted {
                glEnable(GLenum(GL_LIGHTING))
                glMaterialfv(GLenum(GL_FRONT), GLenum(GL_AMBIENT), [0.50, 0.40, 0.35, 1])
                glMaterialfv(GLenum(GL_FRONT), GLenum(GL_DIFFUSE), [0.45, 0.45, 0.45, 1])
            }
            else {
                glDisable(GLenum(GL_LIGHTING))
                glColor3dv([1, 1, 1, 1])
            }
            glEnable(GLenum(GL_POLYGON_OFFSET_FILL))
            glPolygonOffset(1.0, 1.0)
            model?.drawFilled()
            glDisable(GLenum(GL_POLYGON_OFFSET_FILL))
            
            glDisable(GLenum(GL_TEXTURE_2D))
            glDisable(GLenum(GL_LIGHTING))
            glColor3dv([0.3, 0.3, 0.3, 1])
            model?.drawWireframe()
        }
        
    }
    
}

// MARK:- Draw Instance (UnitModel.Instance)

private struct GLInstancePieces {
    
    private var filled: [GLuint]
    private var wireframe: [GLuint]
    fileprivate var model: UnitModel
    fileprivate var instance: UnitModel.Instance
    
    init(_ instance: UnitModel.Instance, of model: UnitModel, with textures: UnitTextureAtlas? = nil) {
        let pieceCount = model.pieces.count
        let lists = glGenLists(GLsizei(pieceCount * 2))
        filled = Array(lists ..< (lists + GLuint(pieceCount)))
        wireframe = Array((lists + GLuint(pieceCount)) ..< (lists + GLuint(pieceCount * 2)))
        
        GLInstancePieces.initPieces(filled, model: model, textures: textures, draw: ModelGL.drawFilledPrimitive)
        GLInstancePieces.initPieces(wireframe, model: model, textures: textures, draw: ModelGL.drawWireShape)
        
        self.model = model
        self.instance = instance
    }
    
    func drawFilled() {
        GLInstancePieces.drawPiece(at: model.root, instance: instance, model: model, displayLists: filled)
    }
    
    func drawWireframe() {
        GLInstancePieces.drawPiece(at: model.root, instance: instance, model: model, displayLists: wireframe)
    }
    
    static func initPieces(_ displayLists: [GLuint], model: UnitModel, textures: UnitTextureAtlas?, draw: ModelGL.DrawFunc) {
        for i in 0 ..< displayLists.count {
            let displayList = displayLists[i]
            let piece = model.pieces[i]
            glNewList(displayList, GLenum(GL_COMPILE))
            for primitiveIndex in piece.primitives.reversed() {
                guard primitiveIndex != model.groundPlate else { continue }
                let primitive = model.primitives[primitiveIndex]
                let indices = primitive.indices
                let texCoords = textures?.textureCoordinates(for: primitive.texture) ?? ModelGL.ZeroTexCoords
                draw( indices.map({ model.vertices[$0] }), texCoords )
            }
            glEndList()
        }
    }
    
    static func drawPiece(at pieceIndex: Int, instance: UnitModel.Instance, model: UnitModel, displayLists: [GLuint]) {
        
        let state = instance.pieces[pieceIndex]
        let piece = model.pieces[pieceIndex]
        
        glPushMatrix()
        glMultMatrixf(makeTransform(from: state, with: piece.offset))
        
        if !state.hidden {
            glCallList(displayLists[pieceIndex])
        }
        
        for childIndex in piece.children {
            drawPiece(at: childIndex, instance: instance, model: model, displayLists: displayLists)
        }
        
        glPopMatrix()
        
    }
    
    mutating func animate(_ script: UnitScript.Context, for deltaTime: GameFloat) {
        script.applyAnimations(to: &instance, for: deltaTime)
    }
    
}


// MARK:- Draw Piece Vertices

private typealias QuadTexCoords = (Vertex2f, Vertex2f, Vertex2f, Vertex2f)

private enum ModelGL { }

private extension ModelGL {
    
    typealias DrawFunc = ([Vertex3f], QuadTexCoords) -> ()
    
    static var ZeroTexCoords: QuadTexCoords {
        return (Vertex2f.zero, Vertex2f.zero, Vertex2f.zero, Vertex2f.zero)
    }
    
    static func drawWireShape(vertices: [Vertex3f], tex: QuadTexCoords) {
        glBegin(GLenum(GL_LINE_LOOP))
        vertices.forEach { glVertex($0) }
        glEnd()
    }
    
    private static func glPrimitiveNormal(_ a: Int, _ b: Int, _ c: Int, in vertices: [Vertex3f]) {
        let v1 = vertices[a]
        let v2 = vertices[b]
        let v3 = vertices[c]
        let u = v2 - v1
        let v = v3 - v1
        glNormal(u × v)
    }
    
    static func drawFilledPrimitive(vertices: [Vertex3f], tex: QuadTexCoords) {
        switch vertices.count {
        case Int.min..<0: () // What?
        case 0: () // No Vertices
        case 1: () // A point?
        case 2: () // A line. Often used as a vector for sfx emitters
        case 3: // Single Triangle
            glBegin(GLenum(GL_TRIANGLES))
            glPrimitiveNormal(0,2,1, in: vertices)
            // Triangle 0,2,1
            glTexCoord(tex.0); glVertex(vertices[0])
            glTexCoord(tex.2); glVertex(vertices[2])
            glTexCoord(tex.1); glVertex(vertices[1])
            glEnd()
        case 4: // Single Quad, split into two triangles
            glBegin(GLenum(GL_TRIANGLES))
            glPrimitiveNormal(0,2,1, in: vertices)
            // Triangle 0,2,1
            glTexCoord(tex.0); glVertex(vertices[0])
            glTexCoord(tex.2); glVertex(vertices[2])
            glTexCoord(tex.1); glVertex(vertices[1])
            // Triangle 0,3,2
            glTexCoord(tex.0); glVertex(vertices[0])
            glTexCoord(tex.3); glVertex(vertices[3])
            glTexCoord(tex.2); glVertex(vertices[2])
            glEnd()
        default: // Polygon with more than 4 sides
            glBegin(GLenum(GL_TRIANGLES))
            for n in 2 ..< vertices.count {
                glTexCoord(tex.0); glVertex(vertices[0])
                glTexCoord(tex.2); glVertex(vertices[n])
                glTexCoord(tex.1); glVertex(vertices[n-1])
            }
            glEnd()
        }
    }
    
}

private func makeTransform(from piece: UnitModel.PieceState, with offset: Vector3f) -> [GameFloat] {
    
    var M: [GameFloat] = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1]
    
    let rad2deg = GameFloat.pi / 180
    let sin = piece.turn.map { Darwin.sin($0 * rad2deg) }
    let cos = piece.turn.map { Darwin.cos($0 * rad2deg) }
    
    M[12] = offset.x - piece.move.x
    M[13] = offset.y - piece.move.z
    M[14] = offset.z + piece.move.y
    
    M[0] = cos.y * cos.z
    M[1] = (sin.y * cos.x) + (sin.x * cos.y * sin.z)
    M[2] = (sin.x * sin.y) - (cos.x * cos.y * sin.z)
    
    M[4] = -sin.y * cos.z
    M[5] = (cos.x * cos.y) - (sin.x * sin.y * sin.z)
    M[6] = (sin.x * cos.y) + (cos.x * sin.y * sin.z)
    
    M[8] = sin.z
    M[9] = -sin.x * cos.z
    M[10] = cos.x * cos.z
    
    return M
}
