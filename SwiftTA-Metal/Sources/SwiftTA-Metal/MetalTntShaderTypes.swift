//
//  TntViewRenderer+MetalShaderTypes.h
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import simd

enum MetalTntViewRenderer_BufferIndex: Int {
    case vertices     = 0
    case uniforms     = 1
    case vertexTextureSlice  = 2
}

enum MetalTntViewRenderer_MapQuadVertexAttribute: Int {
    case position = 0
    case texcoord = 1
}

enum MetalTntViewRenderer_MapTileVertexAttribute: Int {
    case position = 0
    case texcoord = 1
//    case slice = 2
}

enum MetalTntViewRenderer_TextureIndex: Int {
    case color              = 0
}



struct MetalTntViewRenderer_MapQuadVertex {
    var position: vector_float3
    var texCoord: vector_float2
}

struct MetalTntViewRenderer_MapTileVertex {
    var position: vector_float3
    var texCoord: vector_float2
//    var slice: Int32
}

struct MetalTntViewRenderer_MapUniforms {
    var mvpMatrix: matrix_float4x4
}
