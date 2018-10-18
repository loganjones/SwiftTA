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
var vertexCount: GLsizei = 0

var program: GLuint = 0
var vao: GLuint = 0
var vbo = [GLuint](repeating: 0, count: 2)

var aspectRatio: Float = 1
var view_rotx: GLfloat = 20.0
var view_roty: GLfloat = 30.0
var view_rotz: GLfloat = 0.0
var angle: GLfloat = 0.0
var zPan: Float = -100.0
var uniform_model: GLint = 0
var uniform_view: GLint = 0
var uniform_projection: GLint = 0
var uniform_lightPosition: GLint = 0
var uniform_viewPosition: GLint = 0

var t0 = -1
var frames = 0

let π = GLfloat.pi

func printTimeElapsedWhenRunningCode(title:String, operation:()->()) {
    let startTime = CFAbsoluteTimeGetCurrent()
    for _ in 0..<100_000 { operation() }
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("Time elapsed for \(title): \(timeElapsed) s")
}

struct Buffers {
    var vertices: [Vertex3]
    var normals: [Vector3]
    
    init() {
        vertices = []
        normals = []
    }
    
    mutating func append(vertex: Vertex3, normal: Vector3) {
        vertices.append(vertex)
        normals.append(normal)
    }
}

func constructPiece(atOffset offset: Int, in memory: UnsafePointer<UInt8>, offsetFromParent: Vector3f = .zero, buffers: inout Buffers) {
    
    let object = UnsafeRawPointer(memory + offset).bindMemory(to: TA_3DO_OBJECT.self, capacity: 1).pointee
    //let name = String(cString: memory + object.offsetToObjectName)
    
    let offsetFromParent2 = offsetFromParent + object.offsetFromParent
    let vertices = UnsafeRawPointer(memory + object.offsetToVertexArray).bindMemoryBuffer(to: TA_3DO_VERTEX.self, capacity: Int(object.numberOfVertexes)).map({ Vertex3f($0) + offsetFromParent2 })
    /*
    let textures = UnsafeRawPointer(memory + object.offsetToPrimitiveArray).bindMemoryBuffer(to: TA_3DO_PRIMITIVE.self, capacity: Int(object.numberOfPrimitives)).map({
        primitive in
        (primitive.offsetToTextureName != 0)
            ? String(cString: memory + primitive.offsetToTextureName)
            : String(primitive.color)
    }).joined(separator: ", ")
    */
    //print(String(repeating: " ", count: level)+name+"[\(textures)]")
    
    let primitives = UnsafeRawPointer(memory + object.offsetToPrimitiveArray).bindMemoryBuffer(to: TA_3DO_PRIMITIVE.self, capacity: Int(object.numberOfPrimitives))
    primitives.forEach { (primitive) in
        let indices = UnsafeRawPointer(memory + primitive.offsetToVertexIndexArray).bindMemoryBuffer(to: UInt16.self, capacity: Int(primitive.numberOfVertexIndexes))
        switch indices.count {
        case 3: // Single Triangle
            let n = (vertices[indices[1]] - vertices[indices[0]]) × (vertices[indices[2]] - vertices[indices[0]])
            buffers.append(vertex: vertices[indices[0]], normal: n)
            buffers.append(vertex: vertices[indices[1]], normal: n)
            buffers.append(vertex: vertices[indices[2]], normal: n)
        case 4: // Single Quad, split into two triangles
            let n = (vertices[indices[1]] - vertices[indices[0]]) × (vertices[indices[2]] - vertices[indices[0]])
            buffers.append(vertex: vertices[indices[0]], normal: n)
            buffers.append(vertex: vertices[indices[1]], normal: n)
            buffers.append(vertex: vertices[indices[3]], normal: n)
            buffers.append(vertex: vertices[indices[1]], normal: n)
            buffers.append(vertex: vertices[indices[2]], normal: n)
            buffers.append(vertex: vertices[indices[3]], normal: n)
        case 5: // Pentagon, split into three triangles
            let n = (vertices[indices[1]] - vertices[indices[0]]) × (vertices[indices[2]] - vertices[indices[0]])
            buffers.append(vertex: vertices[indices[0]], normal: n)
            buffers.append(vertex: vertices[indices[1]], normal: n)
            buffers.append(vertex: vertices[indices[2]], normal: n)
            buffers.append(vertex: vertices[indices[0]], normal: n)
            buffers.append(vertex: vertices[indices[2]], normal: n)
            buffers.append(vertex: vertices[indices[3]], normal: n)
            buffers.append(vertex: vertices[indices[0]], normal: n)
            buffers.append(vertex: vertices[indices[3]], normal: n)
            buffers.append(vertex: vertices[indices[4]], normal: n)
        default: ()
        }
    }
    
    if object.offsetToChildObject != 0 {
        constructPiece(atOffset: Int(object.offsetToChildObject), in: memory, offsetFromParent: offsetFromParent2, buffers: &buffers)
    }
    
    if object.offsetToSiblingObject != 0 {
        constructPiece(atOffset: Int(object.offsetToSiblingObject), in: memory, offsetFromParent: offsetFromParent, buffers: &buffers)
    }
    
}

/* return current time (in seconds) */
func current_time() -> Int {
    var tv = timeval()
    var tz = timezone()
    gettimeofday(&tv, &tz)
    return tv.tv_sec
}

func compileShader(_ type: GLenum, source: String) throws -> GLuint {
    
    let shader = glCreateShader(type)
    source.withCString() {
        var pp: UnsafePointer<GLchar>? = $0
        glShaderSource(shader, 1, &pp, nil)
        glCompileShader(shader)
    }
    
    var status: GLint = 0
    glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
    guard status == GL_TRUE else {
        throw ShaderError(for: shader)
    }
    
    return shader
}

struct ShaderError: Error, CustomStringConvertible {
    var description: String
    
    init(for shader: GLuint) {
        description = glGetShaderInfoLog(shader) ?? "Shader Error"
    }
}

func glGetShaderInfoLog(_ shader: GLuint) -> String? {
    var logLength: GLint = 0
    glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
    guard logLength > 0 else { return nil }
    
    var data = Data(count: Int(logLength))
    data.withUnsafeMutableBytes() {
        glGetShaderInfoLog(shader, GLsizei(logLength), nil, $0)
    }
    
    return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
}

func linkShaders(_ shaders: GLuint...) throws -> GLuint {
    
    let program = glCreateProgram()
    shaders.forEach { glAttachShader(program, $0) }
    glLinkProgram(program)
    
    var status: GLint = 0
    glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
    guard status == GL_TRUE else {
        throw ProgramError(for: program)
    }
    
    return program
}

struct ProgramError: Error, CustomStringConvertible {
    var description: String
    
    init(for program: GLuint) {
        description = glGetProgramInfoLog(program) ?? "Program Error"
    }
}

func glGetProgramInfoLog(_ program: GLuint) -> String? {
    var logLength: GLint = 0
    glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
    guard logLength > 0 else { return nil }
    
    var data = Data(count: Int(logLength))
    data.withUnsafeMutableBytes() {
        glGetProgramInfoLog(program, GLsizei(logLength), nil, $0)
    }
    
    return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
}

func draw() {
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
    
    var projection = Matrix4x4fMakeFrustum(-1.0, 1.0, -aspectRatio, aspectRatio, 5.0, 1024)
    var view = Matrix4x4fMakeTranslation(0, -10, zPan)
    var model = Matrix4x4fRotate(Matrix4x4fIdentity, view_roty * (π / 180.0), 0, 1, 0);
    var lightPosition = GLKVector3Make(5, 5, 10)
    var viewPosition = GLKVector3Make(0, 10, -zPan)
    
    glUseProgram(program)
    glUniformMatrix4fv(uniform_model, 1, GLboolean(GL_FALSE), &model.__Anonymous_field0.m00)
    glUniformMatrix4fv(uniform_view, 1, GLboolean(GL_FALSE), &view.__Anonymous_field0.m00)
    glUniformMatrix4fv(uniform_projection, 1, GLboolean(GL_FALSE), &projection.__Anonymous_field0.m00)
    glUniform3fv(uniform_lightPosition, 1, &lightPosition.__Anonymous_field0.x)
    glUniform3fv(uniform_viewPosition, 1, &viewPosition.__Anonymous_field0.x)
    glBindVertexArray(vao)
    glDrawArrays(GLenum(GL_TRIANGLES), 0, vertexCount)
    
    glBindVertexArray(0)
    glUseProgram(0)
}

/* new window size or exposure */
func reshape(width: Int, height: Int) {
    aspectRatio = Float(height) / Float(width)
    glViewport(0, 0, GLsizei(width), GLsizei(height))
}

func initScene() {
    glEnable(GLenum(GL_CULL_FACE))
    glEnable(GLenum(GL_DEPTH_TEST))
}


print("Hello 3DO!")

func main() {
    
    let url = URL(fileURLWithPath: "/Users/lojones/Dropbox/Development/SwiftTA/Files/corak.3do", isDirectory: false)
    let file = try! FileHandle(forReadingFrom: url)
    model = file.readDataToEndOfFile()
    
    var buffers = Buffers()
    model.withUnsafeBytes { (memory: UnsafePointer<UInt8>) -> Void in
        constructPiece(atOffset: 0, in: memory, buffers: &buffers)
    }
    vertexCount = GLsizei(buffers.vertices.count)
    
    glfwSetErrorCallback() { (error, description) in
        fputs(description, stderr)
    }
    
    if glfwInit() == 0 {
        exit(EXIT_FAILURE)
    }
    
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    
    let window = glfwCreateWindow(500, 500, "swiftTA - Model", nil, nil)
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
        case (GLFW_PRESS,  GLFW_KEY_EQUAL),
             (GLFW_REPEAT,  GLFW_KEY_EQUAL):
            zPan += 5.0
        case (GLFW_PRESS,  GLFW_KEY_MINUS),
             (GLFW_REPEAT,  GLFW_KEY_MINUS):
            zPan -= 5.0
        case (GLFW_PRESS, GLFW_KEY_ESCAPE):
            glfwSetWindowShouldClose(win, GL_TRUE)
        default:
            ()
        }
    }
    glfwSetFramebufferSizeCallback(window) { (win, width, height) in
        reshape(width: Int(width), height: Int(height))
    }
    
    do {
        let vertexShaderCode = """
        #version 330 core

        layout (location = 0) in vec3 in_position;
        layout (location = 1) in vec3 in_normal;

        out vec3 fragment_position;
        out vec3 fragment_normal;

        uniform mat4 model;
        uniform mat4 view;
        uniform mat4 projection;

        void main(void) {
            fragment_position = vec3(model * vec4(in_position, 1.0));
            fragment_normal = mat3(transpose(inverse(model))) * in_normal;
            gl_Position = projection * view * vec4(fragment_position, 1.0);
        }
        """
        
        let fragmentShaderCode = """
        #version 330 core
        precision highp float;

        in vec3 fragment_normal;
        in vec3 fragment_position;

        out vec4 out_color;

        uniform vec3 lightPosition;
        uniform vec3 viewPosition;

        void main(void) {

            vec3 lightColor = vec3(1.0, 1.0, 1.0);
            vec3 objectColor = vec3(1.0, 1.0, 1.0);

            // ambient
            float ambientStrength = 0.5;
            vec3 ambient = ambientStrength * lightColor;

            // diffuse
            vec3 norm = normalize(fragment_normal);
            vec3 lightDir = normalize(lightPosition - fragment_position);
            float diff = max(dot(norm, lightDir), 0.0);
            vec3 diffuse = diff * lightColor;

            // specular
            float specularStrength = 0.5;
            vec3 viewDir = normalize(viewPosition - fragment_position);
            vec3 reflectDir = reflect(-lightDir, norm);
            float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
            vec3 specular = specularStrength * spec * lightColor;

            vec3 result = (ambient + diffuse + specular) * objectColor;
            out_color = vec4(result, 1.0);
        }
        """
        
        let vertexShader = try compileShader(GLenum(GL_VERTEX_SHADER), source: vertexShaderCode)
        let fragmentShader = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderCode)
        program = try linkShaders(vertexShader, fragmentShader)
        
        glDeleteShader(fragmentShader)
        glDeleteShader(vertexShader)
    }
    catch {
        print("Shader setup failed:\n\(error)")
        glfwTerminate()
        exit(EXIT_FAILURE)
    }
    
    uniform_model = glGetUniformLocation(program, "model")
    uniform_view = glGetUniformLocation(program, "view")
    uniform_projection = glGetUniformLocation(program, "projection")
    uniform_lightPosition = glGetUniformLocation(program, "lightPosition")
    uniform_viewPosition = glGetUniformLocation(program, "viewPosition")
    
    glGenVertexArrays(1, &vao)
    glBindVertexArray(vao)
    
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
    
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
    glBindVertexArray(0)
    
    var frameWidth: Int32 = 0
    var frameHeight: Int32 = 0
    glfwGetFramebufferSize(window, &frameWidth, &frameHeight)
    reshape(width: Int(frameWidth), height: Int(frameHeight))
    
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
    
    glDeleteVertexArrays(1, &vao)
    glDeleteBuffers(GLsizei(vbo.count), &vbo)
    glDeleteProgram(program)
    
    glfwDestroyWindow(window)
    glfwTerminate()
    exit(EXIT_SUCCESS)
}


main()
