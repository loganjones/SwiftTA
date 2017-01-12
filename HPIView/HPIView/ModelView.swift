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
    
    var displayList: GLuint?
    var wireframe: GLuint?
    
    enum DrawMode: Int {
        case solid
        case wireframe
        case outlined
    }
    var drawMode = DrawMode.outlined
    
    private var trackingMouse = false
    private var rotateZ: GLfloat = 160
    private var rotateX: GLfloat = 0
    private var rotateY: GLfloat = 0
    
    private let showAxes = false
    
    override init(frame frameRect: NSRect) {
        let attributes : [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAMinimumPolicy),
            UInt32(NSOpenGLPFADepthSize), UInt32(24),
            UInt32(NSOpenGLPFAAlphaSize), UInt32(8),
        ]
        let format = NSOpenGLPixelFormat(attributes: attributes)
        super.init(frame: frameRect, pixelFormat: format)!
        wantsBestResolutionOpenGLSurface = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func draw(_ dirtyRect: NSRect) {
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
        
        switch drawMode {
        case .solid:
            glEnable(GLenum(GL_LIGHTING))
            if let model = displayList { glCallList(model) }
        case .wireframe:
            glDisable(GLenum(GL_LIGHTING))
            glColor3dv([0.3, 0.3, 0.3, 1])
            if let model = wireframe { glCallList(model) }
        case .outlined:
            glEnable(GLenum(GL_LIGHTING))
            glMaterialfv(GLenum(GL_FRONT), GLenum(GL_AMBIENT), [0.50, 0.40, 0.35, 1])
            glMaterialfv(GLenum(GL_FRONT), GLenum(GL_DIFFUSE), [0.45, 0.45, 0.45, 1])
            glEnable(GLenum(GL_POLYGON_OFFSET_FILL))
            glPolygonOffset(1.0, 1.0)
            if let model = displayList { glCallList(model) }
            glDisable(GLenum(GL_POLYGON_OFFSET_FILL))
            
            glDisable(GLenum(GL_LIGHTING))
            glColor3dv([0.3, 0.3, 0.3, 1])
            if let model = wireframe { glCallList(model) }
        }
        
        if showAxes {
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
        glFlush()
    }
    
    func loadModel(contentsOf modelURL: URL) throws {
        let data = try Data(contentsOf: modelURL)
        openGLContext?.makeCurrentContext()
        
        let model = glGenLists(2)
        data.withUnsafeBytes { (memory: UnsafePointer<UInt8>) -> Void in
            glNewList(model, GLenum(GL_COMPILE))
            ModelGL.drawFillModel(from: memory)
            glEndList()
            glNewList(model + 1, GLenum(GL_COMPILE))
            ModelGL.drawWireModel(from: memory)
            glEndList()
        }
        
        displayList = model
        wireframe = model + 1
        setNeedsDisplay(bounds)
    }
    
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
    }
    
    func reshape(viewport: CGSize) {
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
        default:
            ()
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}


enum ModelGL {
    
    static func drawWireModel(from memory: UnsafePointer<UInt8>) {
        drawPiece(atOffset:0, in: memory, level: 0) { (vertices) in
            glBegin(GLenum(GL_LINE_LOOP))
            vertices.forEach { glVertex($0) }
            glEnd()
        }
    }
    
    static func drawFillModel(from memory: UnsafePointer<UInt8>) {
        drawPiece(atOffset:0, in: memory, level: 0) { (vertices) in
            
            let glModelTriangle = { (a: Int, b: Int, c: Int) in
                glVertex(vertices[a])
                glVertex(vertices[b])
                glVertex(vertices[c])
            }
            let glModelNormal = { (a: Int, b: Int, c: Int) in
                let v1 = vertices[a]
                let v2 = vertices[b]
                let v3 = vertices[c]
                let u = v2 - v1
                let v = v3 - v1
                glNormal(u × v)
            }
            
            switch vertices.count {
            case 3: // Single Triangle
                glBegin(GLenum(GL_TRIANGLES))
                glModelNormal(2,1,0)
                glModelTriangle(2,1,0)
                glEnd()
            case 4: // Single Quad, split into two triangles
                glBegin(GLenum(GL_TRIANGLES))
                glModelNormal(3,1,0)
                glModelTriangle(3,1,0)
                glModelTriangle(3,2,1)
                glEnd()
            case 5: // Pentagon, split into three triangles
                glBegin(GLenum(GL_TRIANGLES))
                glModelNormal(2,1,0)
                glModelTriangle(2,1,0)
                glModelTriangle(3,2,0)
                glModelTriangle(4,3,0)
                glEnd()
            default: ()
            }
        }
    }
    
    static func drawPiece(atOffset offset: Int, in memory: UnsafePointer<UInt8>, level: Int, draw: ([Vertex3]) -> Void) {
        
        let object = UnsafeRawPointer(memory + offset).bindMemory(to: TA_3DO_OBJECT.self, capacity: 1).pointee
        //let name = String(cString: memory + object.offsetToObjectName)
        
        let vertices = UnsafeRawPointer(memory + object.offsetToVertexArray).bindMemoryBuffer(to: TA_3DO_VERTEX.self, capacity: Int(object.numberOfVertexes)).map({ Vertex3($0) })
        
        glPushMatrix()
        glTranslate(object.offsetFromParent)
        
        let primitives = UnsafeRawPointer(memory + object.offsetToPrimitiveArray).bindMemoryBuffer(to: TA_3DO_PRIMITIVE.self, capacity: Int(object.numberOfPrimitives))
        for (index, primitive) in primitives.enumerated().reversed() {
            guard index != Int(object.groundPlateIndex) else { continue }
            let indices = UnsafeRawPointer(memory + primitive.offsetToVertexIndexArray).bindMemoryBuffer(to: UInt16.self, capacity: Int(primitive.numberOfVertexIndexes))
            draw( indices.map({ vertices[$0] }) )
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

// MARK:- Geometry

let LINEAR_CONSTANT = 163840.0 / 2.5

struct Vertex3 {
    var x: Double
    var y: Double
    var z: Double
}
struct Vector3 {
    var x: Double
    var y: Double
    var z: Double
}

extension Vertex3 {
    init(_ v: TA_3DO_VERTEX) {
        x = Double(v.x) / LINEAR_CONSTANT
        y = Double(v.z) / LINEAR_CONSTANT
        z = Double(v.y) / LINEAR_CONSTANT
    }
}

extension Vertex3: CustomStringConvertible {
    var description: String {
        return "(\(x), \(y), \(z))"
    }
}
extension Vector3: CustomStringConvertible {
    var description: String {
        return "->(\(x), \(y), \(z))"
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

func +(lhs: Vertex3, rhs: Vector3) -> Vertex3 {
    return Vertex3(
        x: lhs.x + rhs.x,
        y: lhs.y + rhs.y,
        z: lhs.z + rhs.z
    )
}
func +(lhs: Vector3, rhs: Vector3) -> Vector3 {
    return Vector3(
        x: lhs.x + rhs.x,
        y: lhs.y + rhs.y,
        z: lhs.z + rhs.z
    )
}

func -(lhs: Vertex3, rhs: Vertex3) -> Vector3 {
    return Vector3(
        x: lhs.x - rhs.x,
        y: lhs.y - rhs.y,
        z: lhs.z - rhs.z
    )
}

infix operator •: MultiplicationPrecedence
func •(lhs: Vector3, rhs: Vector3) -> Double {
    return
        lhs.x * rhs.x +
            lhs.y * rhs.y +
            lhs.z * rhs.z
}

infix operator ×: MultiplicationPrecedence
func ×(lhs: Vector3, rhs: Vector3) -> Vector3 {
    return Vector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}


func glVertex(_ v: Vertex3) {
    glVertex3d(v.x, v.y, v.z)
}
func glNormal(_ v: Vector3) {
    glNormal3d(v.x, v.y, v.z)
}
func glTranslate(_ v: Vector3) {
    glTranslated(v.x, v.y, v.z)
}
