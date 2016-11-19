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
    
    override func draw(_ dirtyRect: NSRect) {
        reshape(width: Int(bounds.size.width), height: Int(bounds.size.height))
        initScene()
        
        glClearColor(0.95, 0.95, 0.95, 0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        glPushMatrix()
        glRotatef(75, 1.0, 0.0, 0.0)
        glRotatef(30, 0.0, 1.0, 0.0)
        if let model = displayList { glCallList(model) }
        glPopMatrix()
        glFlush()
    }
    
    func loadModel(contentsOf modelURL: URL) throws {
        let data = try Data(contentsOf: modelURL)
        openGLContext?.makeCurrentContext()
        
        let model = glGenLists(1)
        glNewList(model, GLenum(GL_COMPILE))
        data.withUnsafeBytes { (memory: UnsafePointer<UInt8>) -> Void in
            ModelGL.drawPiece(atOffset: 0, in: memory)
        }
        glEndList()
        
        displayList = model
        setNeedsDisplay(bounds)
    }
    
    func initScene() {
        let pos: [GLfloat] = [ 5.0, 5.0, 10.0, 0.0 ]
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_POSITION), pos)
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_AMBIENT), [ 0.8, 0.8, 0.8, 1 ])
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_DIFFUSE), [ 0.5, 0.5, 0.5, 1 ])
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_LIGHTING))
        glEnable(GLenum(GL_LIGHT0))
        glEnable(GLenum(GL_DEPTH_TEST))
        glEnable(GLenum(GL_NORMALIZE))
    }
    
    func reshape(width: Int, height: Int) {
        let h = GLdouble(height) / GLdouble(width)
        glViewport(0, 0, GLsizei(width), GLsizei(height))
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        glFrustum(-1.0, 1.0, -h, h, 5.0, 360.0)
        glMatrixMode(GLenum(GL_MODELVIEW))
        glLoadIdentity()
        glTranslatef(0.0, 0.0, -333.0)
    }
    
}


enum ModelGL {
    
    static func drawPiece(atOffset offset: Int, in memory: UnsafePointer<UInt8>, level: Int = 0) {
        
        let object = UnsafeRawPointer(memory + offset).bindMemory(to: TA_3DO_OBJECT.self, capacity: 1).pointee
        //let name = String(cString: memory + object.offsetToObjectName)
        
        let vertices = UnsafeRawPointer(memory + object.offsetToVertexArray).bindMemoryBuffer(to: TA_3DO_VERTEX.self, capacity: Int(object.numberOfVertexes)).map({ Vertex3($0) })
        
        glPushMatrix()
        glTranslate(object.offsetFromParent)
        
        let primitives = UnsafeRawPointer(memory + object.offsetToPrimitiveArray).bindMemoryBuffer(to: TA_3DO_PRIMITIVE.self, capacity: Int(object.numberOfPrimitives))
        primitives.forEach { (primitive) in
            let indices = UnsafeRawPointer(memory + primitive.offsetToVertexIndexArray).bindMemoryBuffer(to: UInt16.self, capacity: Int(primitive.numberOfVertexIndexes))
            switch indices.count {
            case 3: // Single Triangle
                glBegin(GLenum(GL_TRIANGLES))
                glNormal((vertices[indices[1]] - vertices[indices[0]]) × (vertices[indices[2]] - vertices[indices[0]]))
                glVertex(vertices[indices[0]])
                glVertex(vertices[indices[1]])
                glVertex(vertices[indices[2]])
                glEnd()
            case 4: // Single Quad, split into two triangles
                glBegin(GLenum(GL_TRIANGLES))
                glNormal((vertices[indices[1]] - vertices[indices[0]]) × (vertices[indices[3]] - vertices[indices[0]]))
                glVertex(vertices[indices[0]])
                glVertex(vertices[indices[1]])
                glVertex(vertices[indices[3]])
                glVertex(vertices[indices[1]])
                glVertex(vertices[indices[2]])
                glVertex(vertices[indices[3]])
                glEnd()
            case 5: // Pentagon, split into three triangles
                glBegin(GLenum(GL_TRIANGLES))
                glNormal((vertices[indices[1]] - vertices[indices[0]]) × (vertices[indices[2]] - vertices[indices[0]]))
                glVertex(vertices[indices[0]])
                glVertex(vertices[indices[1]])
                glVertex(vertices[indices[2]])
                glVertex(vertices[indices[0]])
                glVertex(vertices[indices[2]])
                glVertex(vertices[indices[3]])
                glVertex(vertices[indices[0]])
                glVertex(vertices[indices[3]])
                glVertex(vertices[indices[4]])
                glEnd()
            default: ()
            }
        }
        
        if object.offsetToChildObject != 0 {
            drawPiece(atOffset: Int(object.offsetToChildObject), in: memory, level: level+1)
        }
        
        glPopMatrix()
        
        if object.offsetToSiblingObject != 0 {
            drawPiece(atOffset: Int(object.offsetToSiblingObject), in: memory, level: level)
        }
        
    }
    
}

// MARK:- Memory Extensions

public func +<Pointee>(lhs: UnsafePointer<Pointee>, rhs: UInt32) -> UnsafePointer<Pointee> {
    return lhs + Int(rhs)
}

extension UnsafeRawPointer {
    public func bindMemoryBuffer<T>(to type: T.Type, capacity count: Int) -> UnsafeBufferPointer<T> {
        let p = self.bindMemory(to: type, capacity: count)
        return UnsafeBufferPointer<T>(start: p, count: count)
    }
}

extension Array {
    public subscript(index: UInt16) -> Element { return self[Int(index)] }
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
        y = Double(v.y) / LINEAR_CONSTANT
        z = Double(v.z) / LINEAR_CONSTANT
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
            y: Double(yFromParent) / LINEAR_CONSTANT,
            z: Double(zFromParent) / LINEAR_CONSTANT
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
