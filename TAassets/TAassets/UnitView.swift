//
//  UnitView.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL


class UnitView: NSOpenGLView {
    
    private var model: GLInstancePieces?
    private var modelTexture: GLuint = 0
    private var displayLink: CVDisplayLink?
    private var scriptContext: UnitScript.Context?
    private var loadTime: Double = 0
    private var shouldStartMoving = false
    
    private var viewportSize = CGSize()
    
    enum DrawMode: Int {
        case solid
        case wireframe
        case outlined
    }
    private var drawMode = DrawMode.solid
    private var textured = true
    private var lighted = false
    
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
    
    deinit {
        CVDisplayLinkStop(displayLink!)
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
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!, UnitViewDisplayLinkCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        CVDisplayLinkStart(displayLink!)
    }
    
//    override func draw(_ dirtyRect: NSRect) {
//        drawScene()
//        glFlush()
//    }
    
    fileprivate func drawFrame(_ currentTime: Double, _ deltaTime: Double) {
        
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
    
    private func drawScene() {
        
        reshape(viewport: viewportSize)
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
        glBindTexture(GLenum(GL_TEXTURE_2D), modelTexture)
        switch drawMode {
        case .solid:
            if textured { glEnable(GLenum(GL_TEXTURE_2D)) }
            else { glDisable(GLenum(GL_TEXTURE_2D)) }
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
            if textured { glEnable(GLenum(GL_TEXTURE_2D)) }
            else { glDisable(GLenum(GL_TEXTURE_2D)) }
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
    
    func load(_ model: UnitModel,
              _ script: UnitScript,
              _ texture: UnitTextureAtlas,
              _ filesystem: FileSystem,
              _ palette: Palette) throws {
        openGLContext?.makeCurrentContext()
        
        let instance = UnitModel.Instance(for: model)
        self.model = GLInstancePieces(instance, of: model, with: texture)
        
        let context = try UnitScript.Context(script, model)
        context.startScript("Create")
        self.scriptContext = context
        
        makeTexture(texture, filesystem, palette)
        
        loadTime = getTime()
        shouldStartMoving = true
        
        setNeedsDisplay(bounds)
    }
    
    private func makeTexture(_ texture: UnitTextureAtlas, _ filesystem: FileSystem, _ palette: Palette) {
        
        var textureId: GLuint = 0
        glGenTextures(1, &textureId)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureId)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT )
        
        let data = texture.build(from: filesystem, using: palette)
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
        case .some("t"):
            textured = !textured
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

extension UnitView: ScriptMachine {
    
    func getTime() -> Double {
        return Date.timeIntervalSinceReferenceDate
    }
    
}

// MARK:- Display Link Callback

private func UnitViewDisplayLinkCallback(displayLink: CVDisplayLink,
                                             now: UnsafePointer<CVTimeStamp>,
                                             outputTime: UnsafePointer<CVTimeStamp>,
                                             flagsIn: CVOptionFlags,
                                             flagsOut: UnsafeMutablePointer<CVOptionFlags>,
                                             displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
    
    let currentTime = Double(now.pointee.videoTime) / Double(now.pointee.videoTimeScale)
    let deltaTime = 1.0 / (outputTime.pointee.rateScalar * Double(outputTime.pointee.videoTimeScale) / Double(outputTime.pointee.videoRefreshPeriod))
    
    let view = unsafeBitCast(displayLinkContext, to: UnitView.self)
    view.drawFrame(currentTime, deltaTime)
    
    return kCVReturnSuccess
}

// MARK:- Drawables

private protocol Drawable {
    func drawFilled()
    func drawWireframe()
}

// MARK:- Draw Instance (UnitModel.Instance)

private struct GLInstanceModel: Drawable {
    
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
    
    static func drawPiece(at pieceIndex: Int, instance: UnitModel.Instance, model: UnitModel, level: Int, draw: ModelGL.DrawFunc) {
        
        let state = instance.pieces[pieceIndex]
        let piece = model.pieces[pieceIndex]
        
        glPushMatrix()
        glMultMatrixd(makeTransform(from: state, with: piece.offset))
        
        if !state.hidden {
            for primitiveIndex in piece.primitives.reversed() {
                guard primitiveIndex != model.groundPlate else { continue }
                let primitive = model.primitives[primitiveIndex]
                let indices = primitive.indices
                draw( indices.map({ model.vertices[$0] }), ModelGL.ZeroTexCoords )
            }
        }
        
        for childIndex in piece.children {
            drawPiece(at: childIndex, instance: instance, model: model, level: level+1, draw: draw)
        }
        
        glPopMatrix()
        
    }
    
}

// MARK:- Draw Instance (UnitModel.Instance)

private struct GLInstancePieces: Drawable {
    
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
        glMultMatrixd(makeTransform(from: state, with: piece.offset))
        
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

private func makeTransform(from piece: UnitModel.PieceState, with offset: Vector3) -> [Double] {
    
    var M: [Double] = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1]
    
    let rad2deg = Double.pi / 180
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
