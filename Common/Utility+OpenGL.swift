//
//  OpenGL+Extensions.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

#if canImport(Cocoa)
import Cocoa
import OpenGL.GL
#elseif canImport(Cgl)
import Foundation
import Cgl
#endif


let GL_GAMEFLOAT: Int32 = {
    switch MemoryLayout<GameFloat>.size {
    case MemoryLayout<Float>.size: return GL_FLOAT
    case MemoryLayout<Double>.size: return GL_DOUBLE
    default: fatalError("Unsupported float size for OpenGL")
    }
}()

func glVertex(_ v: Vertex3<Float>) {
    glVertex3f(v.x, v.y, v.z)
}
func glNormal(_ v: Vertex3<Float>) {
    glNormal3f(v.x, v.y, v.z)
}
func glTexCoord(_ v: Vertex2<Float>) {
    glTexCoord2f(v.x, v.y)
}
func glTranslate(_ v: Vertex3<Float>) {
    glTranslatef(v.x, v.y, v.z)
}

func glVertex(_ v: Vertex3<Double>) {
    glVertex3d(v.x, v.y, v.z)
}
func glNormal(_ v: Vertex3<Double>) {
    glNormal3d(v.x, v.y, v.z)
}
func glTexCoord(_ v: Vertex2<Double>) {
    glTexCoord2d(v.x, v.y)
}
func glTranslate(_ v: Vertex3<Double>) {
    glTranslated(v.x, v.y, v.z)
}

func glBufferData<T>(_ target: GLenum, _ data: [T], _ usage: GLenum) {
    var d = data
    glBufferData(target, MemoryLayout<T>.stride * data.count, &d, usage)
}
func glBufferSubData<T>(_ target: GLenum, _ offset: Int, _ data: [T]) {
    var d = data
    glBufferSubData(target, offset, MemoryLayout<T>.stride * data.count, &d)
}

func glUniform3(_ location: GLint, _ value: Vector3<Float>) {
    glUniform3f(location, value.x, value.y, value.z)
}
func glUniform4(_ location: GLint, _ value: Vector4<Float>) {
    glUniform4f(location, value.x, value.y, value.z, value.w)
}
func glUniform3x3(_ location: GLint, transpose: Bool = false, _ value: Matrix3x3<Float>) {
    withUnsafeBytes(of: value) {
        glUniformMatrix3fv(location, 1, transpose ? 1 : 0, $0.baseAddress?.assumingMemoryBound(to: Float.self))
    }
}
func glUniform4x4(_ location: GLint, transpose: Bool = false, _ value: Matrix4x4<Float>) {
    withUnsafeBytes(of: value) {
        glUniformMatrix4fv(location, 1, transpose ? 1 : 0, $0.baseAddress?.assumingMemoryBound(to: Float.self))
    }
}
func glUniform4x4(_ location: GLint, transpose: Bool = false, _ values: [Matrix4x4<Float>]) {
    values.withUnsafeBytes {
        glUniformMatrix4fv(location, GLsizei(values.count), transpose ? 1 : 0, $0.baseAddress?.assumingMemoryBound(to: Float.self))
    }
}

#if !os(Linux)
// glUniform3d, glUniform4d, glUniformMatrix3dv, and glUniformMatrix4dv are part of OpenGL 4.0 (at least according to the glext.h on my system).
// My current Linux test system (Ubuntu 16.04 on VMWare) does not expose an OpenGL 4 driver.
/// TODO: Reform the OpenGL renderer(s) to deal with OpenGL versions and extension loading.

func glUniform3(_ location: GLint, _ value: Vector3<Double>) {
    glUniform3d(location, value.x, value.y, value.z)
}
func glUniform4(_ location: GLint, _ value: Vector4<Double>) {
    glUniform4d(location, value.x, value.y, value.z, value.w)
}
func glUniform3x3(_ location: GLint, transpose: Bool = false, _ value: Matrix3x3<Double>) {
    withUnsafeBytes(of: value) {
        glUniformMatrix3dv(location, 1, transpose ? 1 : 0, $0.baseAddress?.assumingMemoryBound(to: Double.self))
    }
}
func glUniform4x4(_ location: GLint, transpose: Bool = false, _ value: Matrix4x4<Double>) {
    withUnsafeBytes(of: value) {
        glUniformMatrix4dv(location, 1, transpose ? 1 : 0, $0.baseAddress?.assumingMemoryBound(to: Double.self))
    }
}
func glUniform4x4(_ location: GLint, transpose: Bool = false, _ values: [Matrix4x4<Double>]) {
    values.withUnsafeBytes {
        glUniformMatrix4dv(location, GLsizei(values.count), transpose ? 1 : 0, $0.baseAddress?.assumingMemoryBound(to: Double.self))
    }
}
#endif


// MARK:- Shader Utility

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

class OpenglTextureResource {
    var id: GLuint
    init() {
        var textureId: GLuint = 0
        glGenTextures(1, &textureId)
        id = textureId
    }
    init(id: GLuint) {
        self.id = id
    }
    deinit {
        var textureId = id
        glDeleteTextures(1, &textureId)
    }
}

class OpenglVertexBufferResource {
    let vao: GLuint
    let vbo: [GLuint]
    
    init(bufferCount: Int = 1) {
        
        var vao: GLuint = 0
        glGenVertexArrays(1, &vao)
        
        var vbo = [GLuint](repeating: 0, count: bufferCount)
        glGenBuffers(GLsizei(vbo.count), &vbo)
        
        self.vao = vao
        self.vbo = vbo
    }
    
    deinit {
        var vbo = self.vbo
        glDeleteBuffers(GLsizei(vbo.count), &vbo)
        var vao = self.vao
        glDeleteVertexArrays(1, &vao)
    }
}

// MARK:- I am Error

func printGlErrors(prefix: String = "") {
    var err = GL_NO_ERROR
    repeat {
        err = Int32(glGetError())
        if (err != GL_NO_ERROR) {
            Swift.print(prefix + "OpenGL Error: \(err)")
        }
    } while (err != GL_NO_ERROR)
}
