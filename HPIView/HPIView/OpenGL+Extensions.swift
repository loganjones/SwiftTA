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
