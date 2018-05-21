//
//  geometry.swift
//  ModelView
//
//  Created by Logan Jones on 11/5/16.
//

import Foundation
import OpenGL


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

extension Vertex3 {
    static var zero: Vertex3 { return Vertex3(x: 0, y: 0, z: 0) }
}
extension Vector3 {
    static var zero: Vector3 { return Vector3(x: 0, y: 0, z: 0) }
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

func glBufferData<T>(_ target: GLenum, _ data: [T], _ usage: GLenum) {
    var d = data
    glBufferData(target, MemoryLayout<T>.stride * data.count, &d, usage)
}
