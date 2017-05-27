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
    
    var model: GLInstancePieces?
    var displayLink: CVDisplayLink?
    var scriptContext: UnitScript.Context?
    var loadTime: Double = 0
    var shouldStartMoving = false
    
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
    
    deinit {
        CVDisplayLinkStop(displayLink!)
    }
    
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        guard let context = openGLContext
            else { return }
        
        var swapInt: GLint = 1
        context.setValues(&swapInt, for: NSOpenGLCPSwapInterval)
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!, Model3DOViewDisplayLinkCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        CVDisplayLinkStart(displayLink!)
    }
    
//    override func draw(_ dirtyRect: NSRect) {
//        drawScene()
//        glFlush()
//    }
    
    func drawFrame(_ currentTime: Double, _ deltaTime: Double) {
        
        if let script = scriptContext {
            if shouldStartMoving && getTime() > loadTime + 1 {
                script.startScript("StartMoving")
                shouldStartMoving = false
            }
            script.run(for: model!.instance, on: self)
            model?.animate(script, for: deltaTime)
        }
        
        guard let context = openGLContext
            else { return }
        context.makeCurrentContext()
        CGLLockContext(context.cglContextObj!)
        
        drawScene()
        glFlush()
        
        CGLFlushDrawable(context.cglContextObj!)
        CGLUnlockContext(context.cglContextObj!)
    }
    
    func drawScene() {
        
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
    
    func draw<T: Drawable>(_ model: T) {
        switch drawMode {
        case .solid:
            glEnable(GLenum(GL_LIGHTING))
            model.drawFilled()
        case .wireframe:
            glDisable(GLenum(GL_LIGHTING))
            glColor3dv([0.3, 0.3, 0.3, 1])
            model.drawWireframe()
        case .outlined:
            glEnable(GLenum(GL_LIGHTING))
            glMaterialfv(GLenum(GL_FRONT), GLenum(GL_AMBIENT), [0.50, 0.40, 0.35, 1])
            glMaterialfv(GLenum(GL_FRONT), GLenum(GL_DIFFUSE), [0.45, 0.45, 0.45, 1])
            glEnable(GLenum(GL_POLYGON_OFFSET_FILL))
            glPolygonOffset(1.0, 1.0)
            model.drawFilled()
            glDisable(GLenum(GL_POLYGON_OFFSET_FILL))
            
            glDisable(GLenum(GL_LIGHTING))
            glColor3dv([0.3, 0.3, 0.3, 1])
            model.drawWireframe()
        }
    }
    
    func load(_ model: UnitModel, _ script: UnitScript) {
        openGLContext?.makeCurrentContext()
        
        let instance = UnitModel.Instance(for: model)
        self.model = GLInstancePieces(instance, of: model)
        
        let context = UnitScript.Context(script, model)
        context.startScript("Create")
        self.scriptContext = context
        
        loadTime = getTime()
        shouldStartMoving = true
        
        //self.model = GLInstanceModel(instance, of: model)
        //self.model = GLWholeModel(model)
        setNeedsDisplay(bounds)
    }
    
    func loadModel(contentsOf modelURL: URL) throws {
        openGLContext?.makeCurrentContext()
        let model = try UnitModel(contentsOf: modelURL)
        let instance = UnitModel.Instance(for: model)
        self.model = GLInstancePieces(instance, of: model)
        //self.model = try? GLWholeModel(contentsOf: modelURL)
        setNeedsDisplay(bounds)
    }
    
//    func loadModel_old(contentsOf modelURL: URL) throws {
//        openGLContext?.makeCurrentContext()
//        self.model = try? GLRawModel(contentsOf: modelURL)
//        setNeedsDisplay(bounds)
//    }
    
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

extension Model3DOView: ScriptMachine {
    
    func getTime() -> Double {
        return Date.timeIntervalSinceReferenceDate
    }
    
}

// MARK:- Display Link Callback

private func Model3DOViewDisplayLinkCallback(displayLink: CVDisplayLink,
                                             now: UnsafePointer<CVTimeStamp>,
                                             outputTime: UnsafePointer<CVTimeStamp>,
                                             flagsIn: CVOptionFlags,
                                             flagsOut: UnsafeMutablePointer<CVOptionFlags>,
                                             displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
    
    let currentTime = Double(now.pointee.videoTime) / Double(now.pointee.videoTimeScale)
    let deltaTime = 1.0 / (outputTime.pointee.rateScalar * Double(outputTime.pointee.videoTimeScale) / Double(outputTime.pointee.videoRefreshPeriod))
    
    let view = unsafeBitCast(displayLinkContext, to: Model3DOView.self)
    view.drawFrame(currentTime, deltaTime)
    
    return kCVReturnSuccess
}

// MARK:- Drawables

protocol Drawable {
    func drawFilled()
    func drawWireframe()
}

// MARK:- Draw Model (Memory)

struct GLRawModel: Drawable {
    
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

// MARK:- Draw Model (UnitModel)

struct GLWholeModel: Drawable {
    
    private var filledList: GLuint
    private var wireframeList: GLuint
    
    init(contentsOf modelURL: URL) throws {
        let model = try UnitModel(contentsOf: modelURL)
        self.init(model)
    }
    
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
    
    static func drawPiece(at pieceIndex: Int, in model: UnitModel, level: Int, draw: ([Vertex3]) -> Void) {
        
        let piece = model.pieces[pieceIndex]
        
        glPushMatrix()
        glTranslate(piece.offset)
        
        for primitiveIndex in piece.primitives.reversed() {
            guard primitiveIndex != model.groundPlate else { continue }
            let primitive = model.primitives[primitiveIndex]
            let indices = primitive.indices
            draw( indices.map({ model.vertices[$0] }) )
        }
        
        for childIndex in piece.children {
            drawPiece(at: childIndex, in: model, level: level+1, draw: draw)
        }
        
        glPopMatrix()
        
    }
    
}

// MARK:- Draw Instance (UnitModel.Instance)

struct GLInstanceModel: Drawable {
    
    private var filledList: GLuint
    private var wireframeList: GLuint
    
    init(_ instance: UnitModel.Instance, of model: UnitModel) {
        let lists = glGenLists(2)
        filledList = lists + 0
        wireframeList = lists + 1
        
        glNewList(filledList, GLenum(GL_COMPILE))
        GLInstanceModel.drawFillModel(from: instance, of: model)
        glEndList()
        
        glNewList(wireframeList, GLenum(GL_COMPILE))
        GLInstanceModel.drawWireModel(from: instance, of: model)
        glEndList()
    }
    
    func drawFilled() {
        glCallList(filledList)
    }
    
    func drawWireframe() {
        glCallList(wireframeList)
    }
    
    static func drawWireModel(from instance: UnitModel.Instance, of model: UnitModel) {
        drawPiece(at: model.root, instance: instance, model: model, level: 0, draw: ModelGL.drawWireShape)
    }
    
    static func drawFillModel(from instance: UnitModel.Instance, of model: UnitModel) {
        drawPiece(at: model.root, instance: instance, model: model, level: 0, draw: ModelGL.drawFilledPrimitive)
    }
    
    static func drawPiece(at pieceIndex: Int, instance: UnitModel.Instance, model: UnitModel, level: Int, draw: ([Vertex3]) -> Void) {
        
        let state = instance.pieces[pieceIndex]
        let piece = model.pieces[pieceIndex]
        
        glPushMatrix()
        glMultMatrixd(state.transform(with: piece.offset))
        
        if !state.hidden {
            for primitiveIndex in piece.primitives.reversed() {
                guard primitiveIndex != model.groundPlate else { continue }
                let primitive = model.primitives[primitiveIndex]
                let indices = primitive.indices
                draw( indices.map({ model.vertices[$0] }) )
            }
        }
        
        for childIndex in piece.children {
            drawPiece(at: childIndex, instance: instance, model: model, level: level+1, draw: draw)
        }
        
        glPopMatrix()
        
    }
    
}

// MARK:- Draw Instance (UnitModel.Instance)

struct GLInstancePieces: Drawable {
    
    private var filled: [GLuint]
    private var wireframe: [GLuint]
    fileprivate var model: UnitModel
    fileprivate var instance: UnitModel.Instance
    
    init(_ instance: UnitModel.Instance, of model: UnitModel) {
        let pieceCount = model.pieces.count
        let lists = glGenLists(GLsizei(pieceCount * 2))
        filled = Array(lists ..< (lists + GLuint(pieceCount)))
        wireframe = Array((lists + GLuint(pieceCount)) ..< (lists + GLuint(pieceCount * 2)))
        
        GLInstancePieces.initPieces(filled, model: model, draw: ModelGL.drawFilledPrimitive)
        GLInstancePieces.initPieces(wireframe, model: model, draw: ModelGL.drawWireShape)
        
        self.model = model
        self.instance = instance
    }
    
    func drawFilled() {
        GLInstancePieces.drawPiece(at: model.root, instance: instance, model: model, displayLists: filled)
    }
    
    func drawWireframe() {
        GLInstancePieces.drawPiece(at: model.root, instance: instance, model: model, displayLists: wireframe)
    }
    
    static func initPieces(_ displayLists: [GLuint], model: UnitModel, draw: ([Vertex3]) -> Void) {
        for i in 0 ..< displayLists.count {
            let displayList = displayLists[i]
            let piece = model.pieces[i]
            glNewList(displayList, GLenum(GL_COMPILE))
            for primitiveIndex in piece.primitives.reversed() {
                guard primitiveIndex != model.groundPlate else { continue }
                let primitive = model.primitives[primitiveIndex]
                let indices = primitive.indices
                draw( indices.map({ model.vertices[$0] }) )
            }
            glEndList()
        }
    }
    
    static func drawPiece(at pieceIndex: Int, instance: UnitModel.Instance, model: UnitModel, displayLists: [GLuint]) {
        
        let state = instance.pieces[pieceIndex]
        let piece = model.pieces[pieceIndex]
        
        glPushMatrix()
        glMultMatrixd(state.transform(with: piece.offset))
        
        if !state.hidden {
            glCallList(displayLists[pieceIndex])
        }
        
        for childIndex in piece.children {
            drawPiece(at: childIndex, instance: instance, model: model, displayLists: displayLists)
        }
        
        glPopMatrix()
        
    }
    
    mutating func animate(_ script: UnitScript.Context, for deltaTime: Double) {
        script.applyAnimations(to: &instance, for: deltaTime)
    }
    
}


// MARK:- Draw Piece Vertices

enum ModelGL { }

extension ModelGL {
    
    static func drawWireShape(vertices: [Vertex3]) {
        glBegin(GLenum(GL_LINE_LOOP))
        vertices.forEach { glVertex($0) }
        glEnd()
    }
    
    static func drawFilledPrimitive(vertices: [Vertex3]) {
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
        case 6: // Pentagon, split into four triangles
            glBegin(GLenum(GL_TRIANGLES))
            glModelNormal(2,1,0)
            glModelTriangle(2,1,0)
            glModelTriangle(3,2,0)
            glModelTriangle(4,3,0)
            glModelTriangle(5,4,0)
            glEnd()
        default: ()
        }
    }
    
}

extension UnitModel.PieceState {
    
    func transform(with offset: Vector3) -> [Double] {
        
        var M: [Double] = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1]
        
        let rad2deg = Double.pi / 180
        let sin = turn.map { Darwin.sin($0 * rad2deg) }
        let cos = turn.map { Darwin.cos($0 * rad2deg) }
        
        M[12] = offset.x - move.x
        M[13] = offset.y - move.z
        M[14] = offset.z + move.y
        
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
    
}


// MARK:- Geometry OpenGL Functions

func glVertex(_ v: Vertex3) {
    glVertex3d(v.x, v.y, v.z)
}
func glNormal(_ v: Vector3) {
    glNormal3d(v.x, v.y, v.z)
}
func glTranslate(_ v: Vector3) {
    glTranslated(v.x, v.y, v.z)
}
