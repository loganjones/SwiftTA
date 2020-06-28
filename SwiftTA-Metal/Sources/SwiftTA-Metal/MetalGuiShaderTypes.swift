//
//  MetalGuiShaderTypes.h
//  SwiftTA
//
//  Created by Logan Jones on 4/4/20.
//  Copyright © 2020 Logan Jones. All rights reserved.
//

import simd

enum MetalGui_BufferIndex: Int {
    case vertices     = 7
    case uniforms     = 8
}

enum MetalGui_QuadVertexAttribute: Int {
    case position = 0
    case texcoord = 1
}

enum MetalGui_TextureIndex: Int {
    case color              = 0
}



struct MetalGui_QuadVertex {
    var position: vector_float3
    var texCoord: vector_float2
} ;

struct MetalGui_Uniforms {
    var mvpMatrix: matrix_float4x4
}
