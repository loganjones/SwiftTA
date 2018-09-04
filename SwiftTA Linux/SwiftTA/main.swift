//
//  main.swift
//  SwiftTA
//
//  Created by Logan Jones on 7/27/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation
import Cglfw

struct GearScene {
    let gear1: GLuint
    let gear2: GLuint
    let gear3: GLuint
    var angle: GLfloat = 0.0
    var view_rot = Vector3(x: 20.0, y: 30.0, z: 0.0)
    
    init(gear1: GLuint, gear2: GLuint, gear3: GLuint) {
        self.gear1 = gear1
        self.gear2 = gear2
        self.gear3 = gear3
    }
    init() {
        gear1 = 0
        gear2 = 0
        gear3 = 0
    }
}

struct FrameRate {
    var tRot0 = -1.0
    var tRate0 = -1.0
    var frames = 0
    
    init() { }
    
    mutating func sample(_ t: Double) -> Double {
        
        if tRot0 < 0.0 {
            tRot0 = t
        }
        
        let dt = t - tRot0
        tRot0 = t
        
        frames += 1
        
        if tRate0 < 0.0 {
            tRate0 = t
        }
        if t - tRate0 >= 5 {
            let seconds = t - tRate0
            let fps = GLfloat(frames) / GLfloat(seconds)
            print("\(frames) frames in \(seconds) seconds = \(fps) FPS")
            tRate0 = t
            frames = 0
        }
        
        return dt
    }
    
}

class AppContext {
    var gears: GearScene
    var viewState: GameViewState
    
    init() {
        gears = GearScene()
        viewState = GameViewState(viewport: .zero)
    }
}


/* return current time (in seconds) */
func current_time() -> Double
{
    var tv = timeval()
    var tz = timezone()
    gettimeofday(&tv, &tz)
    return Double(tv.tv_sec) + (Double(tv.tv_usec) / 1000000.0)
}


/*
 *
 *  Draw a gear wheel.  You'll probably want to call this function when
 *  building a display list since we do a lot of trig here.
 *
 *  Input:  inner_radius - radius of hole at center
 *          outer_radius - radius at center of teeth
 *          width - width of gear
 *          teeth - number of teeth
 *          tooth_depth - depth of tooth
 */
func gear(inner_radius: GLfloat, outer_radius: GLfloat, width: GLfloat, teeth: GLint, tooth_depth: GLfloat)
{
//    GLint i;
//    GLfloat r0, r1, r2;
//    GLfloat angle, da;
//    GLfloat u, v, len;
    
    let π = GLfloat.pi
    let r0 = inner_radius
    let r1 = outer_radius - tooth_depth / 2.0
    let r2 = outer_radius + tooth_depth / 2.0
    
    glShadeModel(GLenum(GL_FLAT))
    
    glNormal3f(0.0, 0.0, 1.0)
    
    /* draw front face */
    do {
        glBegin(GLenum(GL_QUAD_STRIP))
        let da = 2.0 * π / GLfloat(teeth) / 4.0
        for i in 0...teeth {
            let angle = GLfloat(i) * 2.0 * π / GLfloat(teeth)
            glVertex3f(r0 * cos(angle), r0 * sin(angle), width * 0.5)
            glVertex3f(r1 * cos(angle), r1 * sin(angle), width * 0.5)
            if i < teeth {
                glVertex3f(r0 * cos(angle), r0 * sin(angle), width * 0.5)
                glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), width * 0.5)
            }
        }
        glEnd()
    }
    
    /* draw front sides of teeth */
    do {
        glBegin(GLenum(GL_QUADS))
        let da = 2.0 * π / GLfloat(teeth) / 4.0
        for i in 0...teeth {
            let angle = GLfloat(i) * 2.0 * π / GLfloat(teeth)
            glVertex3f(r1 * cos(angle), r1 * sin(angle), width * 0.5)
            glVertex3f(r2 * cos(angle + da), r2 * sin(angle + da), width * 0.5)
            glVertex3f(r2 * cos(angle + 2 * da), r2 * sin(angle + 2 * da), width * 0.5)
            glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), width * 0.5)
        }
        glEnd()
    }
    
    glNormal3f(0.0, 0.0, -1.0)
    
    /* draw back face */
    do {
        glBegin(GLenum(GL_QUAD_STRIP))
        let da = 2.0 * π / GLfloat(teeth) / 4.0
        for i in 0...teeth {
            let angle = GLfloat(i) * 2.0 * π / GLfloat(teeth)
            glVertex3f(r1 * cos(angle), r1 * sin(angle), -width * 0.5)
            glVertex3f(r0 * cos(angle), r0 * sin(angle), -width * 0.5)
            if i < teeth {
                glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da),
                           -width * 0.5)
                glVertex3f(r0 * cos(angle), r0 * sin(angle), -width * 0.5)
            }
        }
        glEnd()
    }
    
    /* draw back sides of teeth */
    do {
        glBegin(GLenum(GL_QUADS))
        let da = 2.0 * π / GLfloat(teeth) / 4.0
        for i in 0...teeth {
            let angle = GLfloat(i) * 2.0 * π / GLfloat(teeth)
            glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), -width * 0.5)
            glVertex3f(r2 * cos(angle + 2 * da), r2 * sin(angle + 2 * da), -width * 0.5)
            glVertex3f(r2 * cos(angle + da), r2 * sin(angle + da), -width * 0.5)
            glVertex3f(r1 * cos(angle), r1 * sin(angle), -width * 0.5)
        }
        glEnd()
    }
    
    /* draw outward faces of teeth */
    do {
        glBegin(GLenum(GL_QUAD_STRIP))
        let da = 2.0 * π / GLfloat(teeth) / 4.0
        for i in 0...teeth {
            let angle = GLfloat(i) * 2.0 * π / GLfloat(teeth)
            glVertex3f(r1 * cos(angle), r1 * sin(angle), width * 0.5)
            glVertex3f(r1 * cos(angle), r1 * sin(angle), -width * 0.5)
            var u = r2 * cos(angle + da) - r1 * cos(angle)
            var v = r2 * sin(angle + da) - r1 * sin(angle)
            let len = sqrt(u * u + v * v)
            u /= len
            v /= len
            glNormal3f(v, -u, 0.0)
            glVertex3f(r2 * cos(angle + da), r2 * sin(angle + da), width * 0.5)
            glVertex3f(r2 * cos(angle + da), r2 * sin(angle + da), -width * 0.5)
            glNormal3f(cos(angle), sin(angle), 0.0)
            glVertex3f(r2 * cos(angle + 2 * da), r2 * sin(angle + 2 * da), width * 0.5)
            glVertex3f(r2 * cos(angle + 2 * da), r2 * sin(angle + 2 * da), -width * 0.5)
            u = r1 * cos(angle + 3 * da) - r2 * cos(angle + 2 * da)
            v = r1 * sin(angle + 3 * da) - r2 * sin(angle + 2 * da)
            glNormal3f(v, -u, 0.0)
            glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), width * 0.5)
            glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), -width * 0.5)
            glNormal3f(cos(angle), sin(angle), 0.0)
        }
        
        glVertex3f(r1 * cos(0), r1 * sin(0), width * 0.5)
        glVertex3f(r1 * cos(0), r1 * sin(0), -width * 0.5)
        
        glEnd()
    }
    
    glShadeModel(GLenum(GL_SMOOTH))
    
    /* draw inside radius cylinder */
    do {
        glBegin(GLenum(GL_QUAD_STRIP))
        for i in 0...teeth {
            let angle = GLfloat(i) * 2.0 * π / GLfloat(teeth)
            glNormal3f(-cos(angle), -sin(angle), 0.0)
            glVertex3f(r0 * cos(angle), r0 * sin(angle), -width * 0.5)
            glVertex3f(r0 * cos(angle), r0 * sin(angle), width * 0.5)
        }
        glEnd()
    }
}


func draw(_ scene: GearScene)
{
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
    
    glPushMatrix()
    glRotatef(GLfloat(scene.view_rot.x), 1.0, 0.0, 0.0)
    glRotatef(GLfloat(scene.view_rot.y), 0.0, 1.0, 0.0)
    glRotatef(GLfloat(scene.view_rot.z), 0.0, 0.0, 1.0)
    
    glPushMatrix()
    glTranslatef(-3.0, -2.0, 0.0)
    glRotatef(scene.angle, 0.0, 0.0, 1.0)
    glCallList(scene.gear1)
    glPopMatrix()
    
    glPushMatrix()
    glTranslatef(3.1, -2.0, 0.0)
    glRotatef(-2.0 * scene.angle - 9.0, 0.0, 0.0, 1.0)
    glCallList(scene.gear2)
    glPopMatrix()
    
    glPushMatrix()
    glTranslatef(-3.1, 4.2, 0.0)
    glRotatef(-2.0 * scene.angle - 25.0, 0.0, 0.0, 1.0)
    glCallList(scene.gear3)
    glPopMatrix()
    
    glPopMatrix()
}

func glfwSetAppContext(_ app: AppContext, for window: OpaquePointer?) {
    glfwSetWindowUserPointer(window, Unmanaged.passUnretained(app).toOpaque())
}

func glfwGetAppContext(for window: OpaquePointer?) -> AppContext {
    guard let p = glfwGetWindowUserPointer(window) else {
        fatalError("No AppContext set for window!?")
    }
    return Unmanaged.fromOpaque(p).takeUnretainedValue()
}


/* new window size or exposure */
func reshape(window: OpaquePointer?, to viewportSize: (width: Int32, height: Int32))
{
    let app = glfwGetAppContext(for: window)
    
    app.viewState.viewport.size = CGSize(width: CGFloat(viewportSize.width),
                                         height: CGFloat(viewportSize.height))
    let h = GLdouble(app.viewState.viewport.size.height / app.viewState.viewport.size.width)
    
    glViewport(0, 0, GLsizei(viewportSize.width), GLsizei(viewportSize.height))
    glMatrixMode(GLenum(GL_PROJECTION))
    glLoadIdentity()
    glFrustum(-1.0, 1.0, -h, h, 5.0, 60.0)
    glMatrixMode(GLenum(GL_MODELVIEW))
    glLoadIdentity()
    glTranslatef(0.0, 0.0, -40.0)
}

func keyboardKey(event: (key: Int32, scancode: Int32, action: Int32, mods: Int32), in window: OpaquePointer?) {
    let app = glfwGetAppContext(for: window)
    
    switch (event.action, event.key) {
        
    case (GLFW_PRESS,  GLFW_KEY_LEFT): fallthrough
    case (GLFW_REPEAT, GLFW_KEY_LEFT):
        app.gears.view_rot.y += 5.0
        
    case (GLFW_PRESS,  GLFW_KEY_RIGHT): fallthrough
    case (GLFW_REPEAT, GLFW_KEY_RIGHT):
        app.gears.view_rot.y -= 5.0
        
    case (GLFW_PRESS,  GLFW_KEY_UP): fallthrough
    case (GLFW_REPEAT, GLFW_KEY_UP):
        app.gears.view_rot.x += 5.0
        
    case (GLFW_PRESS,  GLFW_KEY_DOWN): fallthrough
    case (GLFW_REPEAT, GLFW_KEY_DOWN):
        app.gears.view_rot.x -= 5.0
        
    case (GLFW_PRESS, GLFW_KEY_ESCAPE):
        glfwSetWindowShouldClose(window, GL_TRUE)
        
    default:
        ()
    }
}


func initGears() -> GearScene
{
    let pos: [GLfloat] = [ 5.0, 5.0, 10.0, 0.0 ]
    let red: [GLfloat] = [ 0.8, 0.1, 0.0, 1.0 ]
    let green: [GLfloat] = [ 0.0, 0.8, 0.2, 1.0 ]
    let blue: [GLfloat] = [ 0.2, 0.2, 1.0, 1.0 ]
    
    glLightfv(GLenum(GL_LIGHT0), GLenum(GL_POSITION), pos)
    glEnable(GLenum(GL_CULL_FACE))
    glEnable(GLenum(GL_LIGHTING))
    glEnable(GLenum(GL_LIGHT0))
    glEnable(GLenum(GL_DEPTH_TEST))
    
    /* make the gears */
    let gear1 = glGenLists(1)
    glNewList(gear1, GLenum(GL_COMPILE))
    glMaterialfv(GLenum(GL_FRONT), GLenum(GL_AMBIENT_AND_DIFFUSE), red)
    gear(inner_radius: 1.0, outer_radius: 4.0, width: 1.0, teeth: 20, tooth_depth: 0.7)
    glEndList()
    
    let gear2 = glGenLists(1)
    glNewList(gear2, GLenum(GL_COMPILE))
    glMaterialfv(GLenum(GL_FRONT), GLenum(GL_AMBIENT_AND_DIFFUSE), green)
    gear(inner_radius: 0.5, outer_radius: 2.0, width: 2.0, teeth: 10, tooth_depth: 0.7)
    glEndList()
    
    let gear3 = glGenLists(1)
    glNewList(gear3, GLenum(GL_COMPILE))
    glMaterialfv(GLenum(GL_FRONT), GLenum(GL_AMBIENT_AND_DIFFUSE), blue)
    gear(inner_radius: 1.3, outer_radius: 2.0, width: 0.5, teeth: 10, tooth_depth: 0.7)
    glEndList()
    
    glEnable(GLenum(GL_NORMALIZE))
    
    return GearScene(gear1: gear1, gear2: gear2, gear3: gear3)
}


func main() {
    
    let app = AppContext()
    
    do {
        let fm = FileManager.default
        
        let taDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Total Annihilation", isDirectory: true)
        print("Total Annihilation directory: \(taDir)")
        
        let state = try GameState.loadStuff(from: taDir, mapName: "Coast to Coast")
        
    }
    catch {
        print("Failed to load GameState: \(error)")
        exit(EXIT_FAILURE)
    }
    
    glfwSetErrorCallback() { (error, description) in
        fputs(description, stderr)
    }
    
    if glfwInit() == 0 {
        exit(EXIT_FAILURE)
    }
    
    let initialWindowSize: (width: Int32, height: Int32) = (640, 480)
    guard let window = glfwCreateWindow(
        initialWindowSize.width,
        initialWindowSize.height,
        "SwiftTA", nil, nil)
        else {
            glfwTerminate()
            exit(EXIT_FAILURE)
    }
    
    glfwSetAppContext(app, for: window)
    
    glfwMakeContextCurrent(window)
    glfwSetKeyCallback(window) {
        (win, key, scancode, action, mods) in
        keyboardKey(event: (key, scancode, action, mods), in: win)
    }
    glfwSetWindowSizeCallback(window) {
        (win, width, height) in
        reshape(window: win, to: (width, height))
    }
    
    reshape(window: window, to: initialWindowSize)
    app.gears = initGears()
    var frameRate = FrameRate()
    
    while glfwWindowShouldClose(window) == 0 {
        
        let dt = frameRate.sample(current_time())
        
        /* next frame */
        app.gears.angle += GLfloat(70.0 * dt)
        if app.gears.angle > 3600.0 {
            app.gears.angle -= 3600.0
        }
        
        draw(app.gears)
        
        glfwSwapBuffers(window)
        glfwPollEvents()
    }
    
    glfwDestroyWindow(window)
    glfwTerminate()
    exit(EXIT_SUCCESS)
}


main()
