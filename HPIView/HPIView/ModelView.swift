//
//  ModelView.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL


class Model3DOView: NSOpenGLView {
    
    private var model: GLWholeModel?
    
    enum DrawMode: Int {
        case solid
        case wireframe
        case outlined
    }
    private var drawMode = DrawMode.outlined
    private var lighted = true
    
    private var trackingMouse = false
    private var rotateZ: GLfloat = 160
    private var rotateX: GLfloat = 0
    private var rotateY: GLfloat = 0
    
    private let showAxes = false
    
    override init(frame frameRect: NSRect) {
        let attributes : [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAMinimumPolicy),
            UInt32(NSOpenGLPFADepthSize), UInt32(16),
            UInt32(NSOpenGLPFAAlphaSize), UInt32(8),
            0
        ]
        let format = NSOpenGLPixelFormat(attributes: attributes)
        super.init(frame: frameRect, pixelFormat: format)!
        wantsBestResolutionOpenGLSurface = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        drawScene()
        glFlush()
    }
    
    private func drawScene() {
        
        reshape(viewport: convertToBacking(bounds).size)
        initScene()
        
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
        
        glRotatef(-rotateZ, 0.0, 0.0, 1.0)
        
        glRotatef(rotateX, 1.0, 0.0, 0.0)
        glRotatef(rotateY, 0.0, 1.0, 0.0)
        
        if let model = model { draw(model) }
        
        if showAxes {
            glDisable(GLenum(GL_TEXTURE_2D))
            glDisable(GLenum(GL_LIGHTING))
            glBegin(GLenum(GL_LINES))
            glColor3f(0, 0, 1)
            glVertex3f(0, 0, 0)
            glVertex3f(100, 0, 0)
            glColor3f(0, 1, 0)
            glVertex3f(0, 0, 0)
            glVertex3f(0, 100, 0)
            glColor3f(1, 0, 0)
            glVertex3f(0, 0, 0)
            glVertex3f(0, 0, 100)
            glEnd()
        }
        
        glPopMatrix()
    }
    
    private func draw<T: Drawable>(_ model: T) {
        switch drawMode {
        case .solid:
            if lighted {
                glEnable(GLenum(GL_LIGHTING))
                glMaterialfv(GLenum(GL_FRONT), GLenum(GL_AMBIENT), [0.50, 0.40, 0.35, 1])
                glMaterialfv(GLenum(GL_FRONT), GLenum(GL_DIFFUSE), [0.45, 0.45, 0.45, 1])
            }
            else {
                glDisable(GLenum(GL_LIGHTING))
                glColor3dv([1, 1, 1, 1])
            }
            model.drawFilled()
        case .wireframe:
            glDisable(GLenum(GL_TEXTURE_2D))
            glDisable(GLenum(GL_LIGHTING))
            glColor3dv([0.3, 0.3, 0.3, 1])
            model.drawWireframe()
        case .outlined:
            if lighted {
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
            model.drawFilled()
            glDisable(GLenum(GL_POLYGON_OFFSET_FILL))
            
            glDisable(GLenum(GL_TEXTURE_2D))
            glDisable(GLenum(GL_LIGHTING))
            glColor3dv([0.3, 0.3, 0.3, 1])
            model.drawWireframe()
        }
    }
    
    func load(_ model: UnitModel) {
        openGLContext?.makeCurrentContext()
        self.model = GLWholeModel(model)
        setNeedsDisplay(bounds)
    }
    
//    func loadModel_old(contentsOf modelURL: URL) throws {
//        openGLContext?.makeCurrentContext()
//        self.model = try? GLRawModel(contentsOf: modelURL)
//        setNeedsDisplay(bounds)
//    }
    
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
    
    private func reshape(viewport: CGSize) {
        glViewport(0, 0, GLsizei(viewport.width), GLsizei(viewport.height))
        
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        
        let aspectRatio = GLdouble(viewport.height) / GLdouble(viewport.width)
        let w: GLdouble = 160
        let scene = (width: w, height: w * aspectRatio)
        glOrtho(0, scene.width, scene.height, 0, -1024, 256)
        
        glMatrixMode(GLenum(GL_MODELVIEW))
        glLoadIdentity()
        glTranslated(scene.width / 2, scene.height / 2, 0.0)
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
        case .some("l"):
            lighted = !lighted
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

// MARK:- Draw Model (Memory)

private struct GLRawModel: Drawable {
    
    private var filledList: GLuint
    private var wireframeList: GLuint
    
    init(contentsOf modelURL: URL) throws {
        let data = try Data(contentsOf: modelURL)
        let lists = glGenLists(2)
        filledList = lists + 0
        wireframeList = lists + 1
        
        data.withUnsafeBytes { (memory: UnsafePointer<UInt8>) -> Void in
            
            glNewList(filledList, GLenum(GL_COMPILE))
            GLRawModel.drawFillModel(from: memory)
            glEndList()
            
            glNewList(wireframeList, GLenum(GL_COMPILE))
            GLRawModel.drawWireModel(from: memory)
            glEndList()
        }
        
    }
    
//    deinit {
//        glDeleteLists(filledList, 2)
//    }
    
    func drawFilled() {
        glCallList(filledList)
    }
    
    func drawWireframe() {
        glCallList(wireframeList)
    }
    
    static func drawWireModel(from memory: UnsafePointer<UInt8>) {
        drawPiece(atOffset:0, in: memory, level: 0, draw: ModelGL.drawWireShape)
    }
    
    static func drawFillModel(from memory: UnsafePointer<UInt8>) {
        drawPiece(atOffset:0, in: memory, level: 0, draw: ModelGL.drawFilledPrimitive)
    }
    
    static func drawPiece(atOffset offset: Int, in memory: UnsafePointer<UInt8>, level: Int, draw: ModelGL.DrawFunc) {
        
        let object = UnsafeRawPointer(memory + offset).bindMemory(to: TA_3DO_OBJECT.self, capacity: 1).pointee
        //let name = String(cString: memory + object.offsetToObjectName)
        
        let vertices = UnsafeRawPointer(memory + object.offsetToVertexArray).bindMemoryBuffer(to: TA_3DO_VERTEX.self, capacity: Int(object.numberOfVertexes)).map({ Vertex3($0) })
        
        glPushMatrix()
        glTranslate(object.offsetFromParent)
        
        let primitives = UnsafeRawPointer(memory + object.offsetToPrimitiveArray).bindMemoryBuffer(to: TA_3DO_PRIMITIVE.self, capacity: Int(object.numberOfPrimitives))
        for (index, primitive) in primitives.enumerated().reversed() {
            guard index != Int(object.groundPlateIndex) else { continue }
            let indices = UnsafeRawPointer(memory + primitive.offsetToVertexIndexArray).bindMemoryBuffer(to: UInt16.self, capacity: Int(primitive.numberOfVertexIndexes))
            draw( indices.map({ vertices[$0] }), ModelGL.ZeroTexCoords )
        }
        
        if object.offsetToChildObject != 0 {
            drawPiece(atOffset: Int(object.offsetToChildObject), in: memory, level: level+1, draw: draw)
        }
        
        glPopMatrix()
        
        if object.offsetToSiblingObject != 0 {
            drawPiece(atOffset: Int(object.offsetToSiblingObject), in: memory, level: level, draw: draw)
        }
        
    }
    
}

// MARK:- Draw Model (UnitModel)

private struct GLWholeModel: Drawable {
    
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

