//
//  ModelViewRenderer+OpenglLegacy.swift
//  TAassets
//
//  Created by Logan Jones on 5/17/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL
import OpenGL.GL3
import GLKit


class LegacyOpenglModelViewRenderer: OpenglModelViewRenderer {
    
    static let desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAMinimumPolicy),
        UInt32(NSOpenGLPFADepthSize), UInt32(16),
        UInt32(NSOpenGLPFAAlphaSize), UInt32(8),
        0
    ]
    
    private var toLoad: UnitModel?
    private var model: GLWholeModel?
    private var modelTexture: GLuint = 0
    
    private let gridSize = Size2D(width: 16, height: 16)
    private let gridSpacing: Int = ModelViewState.gridSize
    
    init() {
        
    }
    
    func initializeOpenglState() {
        initScene()
    }
    
    func drawFrame(_ viewState: ModelViewState) {
        
        if let newModel = toLoad {
            model = GLWholeModel(newModel)
            toLoad = nil
        }
        
        drawScene(viewState)
    }
    
    func switchTo(_ model: UnitModel) {
        toLoad = model
    }
    
}

// MARK:- Setup

private extension LegacyOpenglModelViewRenderer {
    
    func makeTexture(_ texture: UnitTextureAtlas, _ data: Data) -> GLuint {
        
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
        
        printGlErrors(prefix: "Model Texture: ")
        return textureId
    }
    
}

// MARK:- Rendering

private extension LegacyOpenglModelViewRenderer {
    
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
    
    func reshape(_ viewState: ModelViewState) {
        glViewport(0, 0, GLsizei(viewState.viewportSize.width), GLsizei(viewState.viewportSize.height))
        
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        
        let scene = viewState.sceneSize
        glOrtho(0, GLdouble(scene.width), GLdouble(scene.height), 0, -1024, 256)
        
        glMatrixMode(GLenum(GL_MODELVIEW))
        glLoadIdentity()
        glTranslated(GLdouble(scene.width / 2), GLdouble(scene.height / 2), 0.0)
    }
    
    func drawScene(_ viewState: ModelViewState) {
        
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
    
    func drawGrid(_ viewState: ModelViewState) {
        
        glDisable(GLenum(GL_TEXTURE_2D))
        glDisable(GLenum(GL_LIGHTING))
        glColor3dv([0.9, 0.9, 0.9, 1])
        glPushMatrix()
        
        let size = self.gridSize
        let gridSpacing = self.gridSpacing
        
        let psize = CGSize(size * gridSpacing)
        glTranslatef(GLfloat(-psize.width / 2), GLfloat(-psize.height / 2), -0.5)
        
        var n = 0
        let addLine: (Vertex3, Vertex3) -> () = { (a, b) in glVertex(a); glVertex(b); n += 2 }
        let makeVert: (Int, Int) -> Vertex3 = { (w, h) in Vertex3(x: Double(w * gridSpacing), y: Double(h * gridSpacing), z: 0) }
        
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
    
    func drawUnit(_ viewState: ModelViewState) {
        
        glBindTexture(GLenum(GL_TEXTURE_2D), modelTexture)
        
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

// MARK:- Draw Model (UnitModel)

private struct GLWholeModel {
    
    private var filledList: GLuint
    private var wireframeList: GLuint
    
    init(_ model: UnitModel) {
        let lists = glGenLists(2)
        filledList = lists + 0
        wireframeList = lists + 1
        
        glNewList(filledList, GLenum(GL_COMPILE))
        GLWholeModel.drawFillModel(from: model)
        glEndList()
        
        glNewList(wireframeList, GLenum(GL_COMPILE))
        GLWholeModel.drawWireModel(from: model)
        glEndList()
    }
    
    func drawFilled() {
        glCallList(filledList)
    }
    
    func drawWireframe() {
        glCallList(wireframeList)
    }
    
    static func drawWireModel(from model: UnitModel) {
        drawPiece(at: model.root, in: model, level: 0, draw: ModelGL.drawWireShape)
    }
    
    static func drawFillModel(from model: UnitModel) {
        drawPiece(at: model.root, in: model, level: 0, draw: ModelGL.drawFilledPrimitive)
    }
    
    static func drawPiece(at pieceIndex: Int, in model: UnitModel, level: Int, draw: ModelGL.DrawFunc) {
        
        let piece = model.pieces[pieceIndex]
        
        glPushMatrix()
        glTranslate(piece.offset)
        
        for primitiveIndex in piece.primitives.reversed() {
            guard primitiveIndex != model.groundPlate else { continue }
            let primitive = model.primitives[primitiveIndex]
            let indices = primitive.indices
            draw( indices.map({ model.vertices[$0] }), ModelGL.ZeroTexCoords )
        }
        
        for childIndex in piece.children {
            drawPiece(at: childIndex, in: model, level: level+1, draw: draw)
        }
        
        glPopMatrix()
        
    }
    
}

// MARK:- Draw Piece Vertices

private typealias QuadTexCoords = (Vertex2, Vertex2, Vertex2, Vertex2)

private enum ModelGL { }

private extension ModelGL {
    
    typealias DrawFunc = ([Vertex3], QuadTexCoords) -> ()
    
    static var ZeroTexCoords: QuadTexCoords {
        return (Vertex2.zero, Vertex2.zero, Vertex2.zero, Vertex2.zero)
    }
    
    static func drawWireShape(vertices: [Vertex3], tex: QuadTexCoords) {
        glBegin(GLenum(GL_LINE_LOOP))
        vertices.forEach { glVertex($0) }
        glEnd()
    }
    
    private static func glTexCoordOpt(_ v: Vertex2?) {
        if let v = v { glTexCoord2d(v.x, v.y) }
    }
    private static func glPrimitiveNormal(_ a: Int, _ b: Int, _ c: Int, in vertices: [Vertex3]) {
        let v1 = vertices[a]
        let v2 = vertices[b]
        let v3 = vertices[c]
        let u = v2 - v1
        let v = v3 - v1
        glNormal(u × v)
    }
    
    static func drawFilledPrimitive(vertices: [Vertex3], tex: QuadTexCoords) {
        switch vertices.count {
        case Int.min..<0: () // What?
        case 0: () // No Vertices
        case 1: () // A point?
        case 2: () // A line. Often used as a vector for sfx emitters
        case 3: // Single Triangle
            glBegin(GLenum(GL_TRIANGLES))
            glPrimitiveNormal(0,2,1, in: vertices)
            // Triangle 0,2,1
            glTexCoordOpt(tex.0); glVertex(vertices[0])
            glTexCoordOpt(tex.2); glVertex(vertices[2])
            glTexCoordOpt(tex.1); glVertex(vertices[1])
            glEnd()
        case 4: // Single Quad, split into two triangles
            glBegin(GLenum(GL_TRIANGLES))
            glPrimitiveNormal(0,2,1, in: vertices)
            // Triangle 0,2,1
            glTexCoordOpt(tex.0); glVertex(vertices[0])
            glTexCoordOpt(tex.2); glVertex(vertices[2])
            glTexCoordOpt(tex.1); glVertex(vertices[1])
            // Triangle 0,3,2
            glTexCoordOpt(tex.0); glVertex(vertices[0])
            glTexCoordOpt(tex.3); glVertex(vertices[3])
            glTexCoordOpt(tex.2); glVertex(vertices[2])
            glEnd()
        default: // Polygon with more than 4 sides
            glBegin(GLenum(GL_TRIANGLES))
            for n in 2 ..< vertices.count {
                glTexCoordOpt(tex.0); glVertex(vertices[0])
                glTexCoordOpt(tex.2); glVertex(vertices[n])
                glTexCoordOpt(tex.1); glVertex(vertices[n-1])
            }
            glEnd()
        }
    }
    
}
