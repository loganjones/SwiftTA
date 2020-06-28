//
//  UnitViewRenderer+MetalShaderTypes.h
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import simd

enum UnitMetalRenderer_BufferIndex: Int {
    case modelVertices     = 5
    case uniforms          = 6
}

enum UnitMetalRenderer_ModelVertexAttribute: Int {
    case position = 0
    case normal   = 1
    case texcoord = 2
    case pieceIndex = 3
}

enum UnitMetalRenderer_TextureIndex: Int {
    case color            = 0
}



struct UnitMetalRenderer_ModelVertex {
    var position: vector_float3
    var normal: vector_float3
    var texCoord: vector_float2
    var pieceIndex: Int32
}

struct UnitMetalRenderer_ModelUniforms {
    var vpMatrix: matrix_float4x4
    var normalMatrix: matrix_float3x3
    var pieces: (
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4,
        matrix_float4x4, matrix_float4x4, matrix_float4x4, matrix_float4x4
    )
}
