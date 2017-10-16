//
//  main.swift
//  ModelView
//
//  Created by Logan Jones on 11/2/16.
//

import Foundation
import OpenGL
import Darwin

var model = Data()

var view_rotx: GLfloat = 20.0
var view_roty: GLfloat = 30.0
var view_rotz: GLfloat = 0.0
var gear1: GLuint = 0
var gear2: GLuint = 0
var gear3: GLuint = 0
var angle: GLfloat = 0.0

var t0 = -1
var frames = 0

let π = GLfloat.pi

func printTimeElapsedWhenRunningCode(title:String, operation:()->()) {
    let startTime = CFAbsoluteTimeGetCurrent()
    for _ in 0..<100_000 { operation() }
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("Time elapsed for \(title): \(timeElapsed) s")
}



func drawPiece(atOffset offset: Int, in memory: UnsafePointer<UInt8>, level: Int = 0) {
    
    let object = UnsafeRawPointer(memory + offset).bindMemory(to: TA_3DO_OBJECT.self, capacity: 1).pointee
    //let name = String(cString: memory + object.offsetToObjectName)
    
    let vertices = UnsafeRawPointer(memory + object.offsetToVertexArray).bindMemoryBuffer(to: TA_3DO_VERTEX.self, capacity: Int(object.numberOfVertexes)).map({ Vertex3($0) })
    /*
    let textures = UnsafeRawPointer(memory + object.offsetToPrimitiveArray).bindMemoryBuffer(to: TA_3DO_PRIMITIVE.self, capacity: Int(object.numberOfPrimitives)).map({
        primitive in
        (primitive.offsetToTextureName != 0)
            ? String(cString: memory + primitive.offsetToTextureName)
            : String(primitive.color)
    }).joined(separator: ", ")
    */
    //print(String(repeating: " ", count: level)+name+"[\(textures)]")
    
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



/* return current time (in seconds) */
func current_time() -> Int {
    var tv = timeval()
    var tz = timezone()
    gettimeofday(&tv, &tz)
    return tv.tv_sec
}


func draw() {
    
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
    
    glPushMatrix()
    glRotatef(view_rotx, 1.0, 0.0, 0.0)
    glRotatef(view_roty, 0.0, 1.0, 0.0)
    glRotatef(view_rotz, 0.0, 0.0, 1.0)
    
    model.withUnsafeBytes { (memory: UnsafePointer<UInt8>) -> Void in
        drawPiece(atOffset: 0, in: memory)
    }
    
    glPopMatrix()
}


/* new window size or exposure */
func reshape(width: Int, height: Int) {
    let h = GLdouble(height) / GLdouble(width)
    glViewport(0, 0, GLsizei(width), GLsizei(height))
    glMatrixMode(GLenum(GL_PROJECTION))
    glLoadIdentity()
    glFrustum(-1.0, 1.0, -h, h, 5.0, 120.0)
    glMatrixMode(GLenum(GL_MODELVIEW))
    glLoadIdentity()
    glTranslatef(0.0, 0.0, -100.0)
}


func initScene() {
    let pos: [GLfloat] = [ 5.0, 5.0, 10.0, 0.0 ]
    glLightfv(GLenum(GL_LIGHT0), GLenum(GL_POSITION), pos)
    glEnable(GLenum(GL_CULL_FACE))
    glEnable(GLenum(GL_LIGHTING))
    glEnable(GLenum(GL_LIGHT0))
    glEnable(GLenum(GL_DEPTH_TEST))
    glEnable(GLenum(GL_NORMALIZE))
}



print("Hello 3DO!")

func main() {
    
    let url = URL(fileURLWithPath: "/Users/lojones/Dropbox/Development/SwiftTA/Files/corak.3do", isDirectory: false)
    let file = try! FileHandle(forReadingFrom: url)
    model = file.readDataToEndOfFile()
    
    glfwSetErrorCallback() { (error, description) in
        fputs(description, stderr)
    }
    
    if glfwInit() == 0 {
        exit(EXIT_FAILURE)
    }
    
    let window = glfwCreateWindow(300, 300, "glxgears", nil, nil)
    guard window != nil
        else {
            glfwTerminate()
            exit(EXIT_FAILURE)
    }
    
    glfwMakeContextCurrent(window)
    glfwSetKeyCallback(window) { (win, key, scancode, action, mods) in
        switch (action, key) {
        case (GLFW_PRESS,  GLFW_KEY_LEFT): fallthrough
        case (GLFW_REPEAT, GLFW_KEY_LEFT):
            view_roty += 5.0
        case (GLFW_PRESS,  GLFW_KEY_RIGHT): fallthrough
        case (GLFW_REPEAT, GLFW_KEY_RIGHT):
            view_roty -= 5.0
        case (GLFW_PRESS,  GLFW_KEY_UP): fallthrough
        case (GLFW_REPEAT, GLFW_KEY_UP):
            view_rotx += 5.0
        case (GLFW_PRESS,  GLFW_KEY_DOWN): fallthrough
        case (GLFW_REPEAT, GLFW_KEY_DOWN):
            view_rotx -= 5.0
        case (GLFW_PRESS, GLFW_KEY_ESCAPE):
            glfwSetWindowShouldClose(win, GL_TRUE)
        default:
            ()
        }
    }
    glfwSetWindowSizeCallback(window) { (win, width, height) in
        reshape(width: Int(width), height: Int(height))
    }
    
    reshape(width: 300, height: 300)
    initScene()
    
    while glfwWindowShouldClose(window) == 0 {
        
        
        /* next frame */
        angle += 2.0
        
        draw()
        
        glfwSwapBuffers(window)
        glfwPollEvents()
        
        /* calc framerate */
        do {
            let t = current_time()
            
            if (t0 < 0) {
                t0 = t
            }
            
            frames += 1
            
            if t - t0 >= 5 {
                let seconds = t - t0
                let fps = GLfloat(frames) / GLfloat(seconds)
                print("\(frames) frames in \(seconds) seconds = \(fps) FPS")
                t0 = t
                frames = 0
            }
        }
    }
    
    glfwDestroyWindow(window)
    glfwTerminate()
    exit(EXIT_SUCCESS)
}


main()
