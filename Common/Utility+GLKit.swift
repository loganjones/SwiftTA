//
//  Utility+GLKit.swift
//  TAassets
//
//  Created by Logan Jones on 5/14/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation
#if canImport(GLKit)
import GLKit
#else
import Cgl
#endif


#if canImport(GLKit)

extension GLKVector3 {
    
    init(_ v: Vertex3) {
        self.init(v: (Float(v.x), Float(v.y), Float(v.z)))
    }
    init(_ v: Vector3) {
        self.init(v: (Float(v.x), Float(v.y), Float(v.z)))
    }
    
}

func ×(lhs: GLKVector3, rhs: GLKVector3) -> GLKVector3 {
    return GLKVector3CrossProduct(lhs, rhs)
}
func *(lhs: GLKMatrix4, rhs: GLKVector3) -> GLKVector3 {
    return GLKMatrix4MultiplyVector3(lhs, rhs)
}
func *(lhs: GLKMatrix4, rhs: GLKVector4) -> GLKVector4 {
    return GLKMatrix4MultiplyVector4(lhs, rhs)
}
func *(lhs: GLKMatrix4, rhs: GLKMatrix4) -> GLKMatrix4 {
    return GLKMatrix4Multiply(lhs, rhs)
}

func glUniformGLKVector3(_ location: GLint, _ value: GLKVector3) {
    var shadow = value
    glUniform3fv(location, 1, &shadow.__Anonymous_field0.x)
}
func glUniformGLKVector4(_ location: GLint, _ value: GLKVector4) {
    var shadow = value
    glUniform4fv(location, 1, &shadow.__Anonymous_field0.x)
}

func glUniformGLKMatrix4(_ location: GLint, transpose: Bool = false, _ value: GLKMatrix4) {
    var shadow = value
    glUniformMatrix4fv(location, 1, transpose ? 1 : 0, &shadow.__Anonymous_field0.m00)
}

func glUniformGLKMatrix4(_ location: GLint, transpose: Bool = false, _ values: [GLKMatrix4]) {
    values.withUnsafeBytes {
        let p = $0.baseAddress!
        glUniformMatrix4fv(location, GLsizei(values.count), transpose ? 1 : 0, p.assumingMemoryBound(to: GLfloat.self))
    }
}

#else

struct GLKMatrix4 {
    var v: (Float, Float, Float, Float,
    Float, Float, Float, Float,
    Float, Float, Float, Float,
    Float, Float, Float, Float)
    
    static let identity = GLKMatrix4(v: (1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         0, 0, 0, 1))
}

let GLKMatrix4Identity = GLKMatrix4.identity

func GLKMatrix4MakeTranslation(_ x: Float, _ y: Float, _ z: Float) -> GLKMatrix4 {
    return GLKMatrix4(v: (1, 0, 0, 0,
                          0, 1, 0, 0,
                          0, 0, 1, 0,
                          x, y, z, 1))
}

func GLKMatrix4MakeOrtho(_ left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ nearZ: Float, _ farZ: Float) -> GLKMatrix4 {
    
    let ral = right + left
    let rsl = right - left
    let tab = top + bottom
    let tsb = top - bottom
    let fan = farZ + nearZ
    let fsn = farZ - nearZ
    
    return GLKMatrix4(v: (2.0 / rsl, 0.0, 0.0, 0.0,
                          0.0, 2.0 / tsb, 0.0, 0.0,
                          0.0, 0.0, -2.0 / fsn, 0.0,
                          -ral / rsl, -tab / tsb, -fan / fsn, 1.0))
}

func *(lhs: GLKMatrix4, rhs: GLKMatrix4) -> GLKMatrix4 {
    
    var m = GLKMatrix4.identity
    
    m.v.0  = lhs.v.0 * rhs.v.0  + lhs.v.4 * rhs.v.1  + lhs.v.8 * rhs.v.2   + lhs.v.12 * rhs.v.3
    m.v.4  = lhs.v.0 * rhs.v.4  + lhs.v.4 * rhs.v.5  + lhs.v.8 * rhs.v.6   + lhs.v.12 * rhs.v.7
    m.v.8  = lhs.v.0 * rhs.v.8  + lhs.v.4 * rhs.v.9  + lhs.v.8 * rhs.v.10  + lhs.v.12 * rhs.v.11
    m.v.12 = lhs.v.0 * rhs.v.12 + lhs.v.4 * rhs.v.13 + lhs.v.8 * rhs.v.14  + lhs.v.12 * rhs.v.15
    
    m.v.1  = lhs.v.1 * rhs.v.0  + lhs.v.5 * rhs.v.1  + lhs.v.9 * rhs.v.2   + lhs.v.13 * rhs.v.3
    m.v.5  = lhs.v.1 * rhs.v.4  + lhs.v.5 * rhs.v.5  + lhs.v.9 * rhs.v.6   + lhs.v.13 * rhs.v.7
    m.v.9  = lhs.v.1 * rhs.v.8  + lhs.v.5 * rhs.v.9  + lhs.v.9 * rhs.v.10  + lhs.v.13 * rhs.v.11
    m.v.13 = lhs.v.1 * rhs.v.12 + lhs.v.5 * rhs.v.13 + lhs.v.9 * rhs.v.14  + lhs.v.13 * rhs.v.15
    
    m.v.2  = lhs.v.2 * rhs.v.0  + lhs.v.6 * rhs.v.1  + lhs.v.10 * rhs.v.2  + lhs.v.14 * rhs.v.3
    m.v.6  = lhs.v.2 * rhs.v.4  + lhs.v.6 * rhs.v.5  + lhs.v.10 * rhs.v.6  + lhs.v.14 * rhs.v.7
    m.v.10 = lhs.v.2 * rhs.v.8  + lhs.v.6 * rhs.v.9  + lhs.v.10 * rhs.v.10 + lhs.v.14 * rhs.v.11
    m.v.14 = lhs.v.2 * rhs.v.12 + lhs.v.6 * rhs.v.13 + lhs.v.10 * rhs.v.14 + lhs.v.14 * rhs.v.15
    
    m.v.3  = lhs.v.3 * rhs.v.0  + lhs.v.7 * rhs.v.1  + lhs.v.11 * rhs.v.2  + lhs.v.15 * rhs.v.3
    m.v.7  = lhs.v.3 * rhs.v.4  + lhs.v.7 * rhs.v.5  + lhs.v.11 * rhs.v.6  + lhs.v.15 * rhs.v.7
    m.v.11 = lhs.v.3 * rhs.v.8  + lhs.v.7 * rhs.v.9  + lhs.v.11 * rhs.v.10 + lhs.v.15 * rhs.v.11
    m.v.15 = lhs.v.3 * rhs.v.12 + lhs.v.7 * rhs.v.13 + lhs.v.11 * rhs.v.14 + lhs.v.15 * rhs.v.15
    
    return m
}

func glUniformGLKMatrix4(_ location: GLint, transpose: Bool = false, _ value: GLKMatrix4) {
    var shadow = value
    glUniformMatrix4fv(location, 1, transpose ? 1 : 0, &shadow.v.0)
}

func glUniformGLKMatrix4(_ location: GLint, transpose: Bool = false, _ values: [GLKMatrix4]) {
    values.withUnsafeBytes {
        let p = $0.baseAddress!
        glUniformMatrix4fv(location, GLsizei(values.count), transpose ? 1 : 0, p.assumingMemoryBound(to: GLfloat.self))
    }
}

#endif
