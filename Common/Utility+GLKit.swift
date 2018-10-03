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

func glUniformGLKMatrix3(_ location: GLint, transpose: Bool = false, _ value: GLKMatrix3) {
    var shadow = value
    glUniformMatrix3fv(location, 1, transpose ? 1 : 0, &shadow.__Anonymous_field0.m00)
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

struct GLKVector3 {
    var v: (Float, Float, Float)
    var x: Float { return v.0 }
    var y: Float { return v.1 }
    var z: Float { return v.2 }
}
extension GLKVector3 {
    init(_ v: Vertex3) {
        self.init(v: (Float(v.x), Float(v.y), Float(v.z)))
    }
    init(_ v: Vector3) {
        self.init(v: (Float(v.x), Float(v.y), Float(v.z)))
    }
}

struct GLKMatrix3 {
    var m: (Float, Float, Float,
            Float, Float, Float,
            Float, Float, Float)
    
    static let identity = GLKMatrix3(m: (1, 0, 0,
                                         0, 1, 0,
                                         0, 0, 1))
}

let GLKMatrix3Identity = GLKMatrix3.identity

struct GLKMatrix4 {
    var m: (Float, Float, Float, Float,
            Float, Float, Float, Float,
            Float, Float, Float, Float,
            Float, Float, Float, Float)
    
    static let identity = GLKMatrix4(m: (1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         0, 0, 0, 1))
}

let GLKMatrix4Identity = GLKMatrix4.identity

func GLKMatrix4Multiply(_ lhs: GLKMatrix4, _ rhs: GLKMatrix4) -> GLKMatrix4 {
    return lhs * rhs
}

func GLKMatrix4MakeTranslation(_ x: Float, _ y: Float, _ z: Float) -> GLKMatrix4 {
    return GLKMatrix4(m: (1, 0, 0, 0,
                          0, 1, 0, 0,
                          0, 0, 1, 0,
                          x, y, z, 1))
}

func GLKMatrix4Make(_ m00: Float, _ m01: Float, _ m02: Float, _ m03: Float,
                    _ m10: Float, _ m11: Float, _ m12: Float, _ m13: Float,
                    _ m20: Float, _ m21: Float, _ m22: Float, _ m23: Float,
                    _ m30: Float, _ m31: Float, _ m32: Float, _ m33: Float) -> GLKMatrix4 {
    return GLKMatrix4(m: (m00, m01, m02, m03,
                          m10, m11, m12, m13,
                          m20, m21, m22, m23,
                          m30, m31, m32, m33))
}

func GLKMatrix4MakeOrtho(_ left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ nearZ: Float, _ farZ: Float) -> GLKMatrix4 {
    
    let ral = right + left
    let rsl = right - left
    let tab = top + bottom
    let tsb = top - bottom
    let fan = farZ + nearZ
    let fsn = farZ - nearZ
    
    return GLKMatrix4(m: (2.0 / rsl, 0.0, 0.0, 0.0,
                          0.0, 2.0 / tsb, 0.0, 0.0,
                          0.0, 0.0, -2.0 / fsn, 0.0,
                          -ral / rsl, -tab / tsb, -fan / fsn, 1.0))
}

func GLKMatrix3InvertAndTranspose(_ matrix: GLKMatrix3, _ isInvertible: UnsafeMutablePointer<Bool>!) -> GLKMatrix3 {
    let m = matrix.m
    let d =   m.0 * (m.4 * m.8 - m.7 * m.5)
            - m.1 * (m.3 * m.8 - m.5 * m.6)
            + m.2 * (m.3 * m.7 - m.4 * m.6)
    let i = 1.0 / d
    
    let r00 =  (m.4 * m.8 - m.7 * m.5) * i
    let r10 = -(m.1 * m.8 - m.2 * m.7) * i
    let r20 =  (m.1 * m.5 - m.2 * m.4) * i
    let r01 = -(m.3 * m.8 - m.5 * m.6) * i
    let r11 =  (m.0 * m.8 - m.2 * m.6) * i
    let r21 = -(m.0 * m.5 - m.3 * m.2) * i
    let r02 =  (m.3 * m.7 - m.6 * m.4) * i
    let r12 = -(m.0 * m.7 - m.6 * m.1) * i
    let r22 =  (m.0 * m.4 - m.3 * m.1) * i
    
    return GLKMatrix3(m: (r00, r01, r02,
                          r10, r11, r12,
                          r20, r21, r22))
}

func *(lhs: GLKMatrix4, rhs: GLKMatrix4) -> GLKMatrix4 {
    
    var mult = GLKMatrix4.identity
    
    mult.m.0  = lhs.m.0 * rhs.m.0  + lhs.m.4 * rhs.m.1  + lhs.m.8 * rhs.m.2   + lhs.m.12 * rhs.m.3
    mult.m.4  = lhs.m.0 * rhs.m.4  + lhs.m.4 * rhs.m.5  + lhs.m.8 * rhs.m.6   + lhs.m.12 * rhs.m.7
    mult.m.8  = lhs.m.0 * rhs.m.8  + lhs.m.4 * rhs.m.9  + lhs.m.8 * rhs.m.10  + lhs.m.12 * rhs.m.11
    mult.m.12 = lhs.m.0 * rhs.m.12 + lhs.m.4 * rhs.m.13 + lhs.m.8 * rhs.m.14  + lhs.m.12 * rhs.m.15
    
    mult.m.1  = lhs.m.1 * rhs.m.0  + lhs.m.5 * rhs.m.1  + lhs.m.9 * rhs.m.2   + lhs.m.13 * rhs.m.3
    mult.m.5  = lhs.m.1 * rhs.m.4  + lhs.m.5 * rhs.m.5  + lhs.m.9 * rhs.m.6   + lhs.m.13 * rhs.m.7
    mult.m.9  = lhs.m.1 * rhs.m.8  + lhs.m.5 * rhs.m.9  + lhs.m.9 * rhs.m.10  + lhs.m.13 * rhs.m.11
    mult.m.13 = lhs.m.1 * rhs.m.12 + lhs.m.5 * rhs.m.13 + lhs.m.9 * rhs.m.14  + lhs.m.13 * rhs.m.15
    
    mult.m.2  = lhs.m.2 * rhs.m.0  + lhs.m.6 * rhs.m.1  + lhs.m.10 * rhs.m.2  + lhs.m.14 * rhs.m.3
    mult.m.6  = lhs.m.2 * rhs.m.4  + lhs.m.6 * rhs.m.5  + lhs.m.10 * rhs.m.6  + lhs.m.14 * rhs.m.7
    mult.m.10 = lhs.m.2 * rhs.m.8  + lhs.m.6 * rhs.m.9  + lhs.m.10 * rhs.m.10 + lhs.m.14 * rhs.m.11
    mult.m.14 = lhs.m.2 * rhs.m.12 + lhs.m.6 * rhs.m.13 + lhs.m.10 * rhs.m.14 + lhs.m.14 * rhs.m.15
    
    mult.m.3  = lhs.m.3 * rhs.m.0  + lhs.m.7 * rhs.m.1  + lhs.m.11 * rhs.m.2  + lhs.m.15 * rhs.m.3
    mult.m.7  = lhs.m.3 * rhs.m.4  + lhs.m.7 * rhs.m.5  + lhs.m.11 * rhs.m.6  + lhs.m.15 * rhs.m.7
    mult.m.11 = lhs.m.3 * rhs.m.8  + lhs.m.7 * rhs.m.9  + lhs.m.11 * rhs.m.10 + lhs.m.15 * rhs.m.11
    mult.m.15 = lhs.m.3 * rhs.m.12 + lhs.m.7 * rhs.m.13 + lhs.m.11 * rhs.m.14 + lhs.m.15 * rhs.m.15
    
    return mult
}

func glUniformGLKMatrix3(_ location: GLint, transpose: Bool = false, _ value: GLKMatrix3) {
    var shadow = value
    glUniformMatrix3fv(location, 1, transpose ? 1 : 0, &shadow.m.0)
}
func glUniformGLKMatrix4(_ location: GLint, transpose: Bool = false, _ value: GLKMatrix4) {
    var shadow = value
    glUniformMatrix4fv(location, 1, transpose ? 1 : 0, &shadow.m.0)
}

func glUniformGLKMatrix4(_ location: GLint, transpose: Bool = false, _ values: [GLKMatrix4]) {
    values.withUnsafeBytes {
        let p = $0.baseAddress!
        glUniformMatrix4fv(location, GLsizei(values.count), transpose ? 1 : 0, p.assumingMemoryBound(to: GLfloat.self))
    }
}

#endif

extension GLKMatrix3 {
    
    init(topLeftOf m44: GLKMatrix4) {
        self.init(m: (m44.m.0, m44.m.1, m44.m.2,
                      m44.m.4, m44.m.5, m44.m.6,
                      m44.m.8, m44.m.9, m44.m.10))
    }
    
    var inverseTranspose: GLKMatrix3 {
        return GLKMatrix3InvertAndTranspose(self, nil)
    }
    
}

extension GLKMatrix4 {
    
    static let taPerspective = GLKMatrix4Make(
        -1,   0,   0,   0,
         0,   1,   0,   0,
         0,-0.5,   1,   0,
         0,   0,   0,   1
    )
    
}
