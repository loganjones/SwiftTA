//
//  OpenGL+Extensions.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL


func glVertex(_ v: Vertex3) {
    glVertex3d(v.x, v.y, v.z)
}
func glNormal(_ v: Vector3) {
    glNormal3d(v.x, v.y, v.z)
}
func glTexCoord(_ v: Vertex2) {
    glTexCoord2d(v.x, v.y)
}
func glTranslate(_ v: Vector3) {
    glTranslated(v.x, v.y, v.z)
}

func glBufferData<T>(_ target: GLenum, _ data: [T], _ usage: GLenum) {
    var d = data
    glBufferData(target, MemoryLayout<T>.stride * data.count, &d, usage)
}

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
