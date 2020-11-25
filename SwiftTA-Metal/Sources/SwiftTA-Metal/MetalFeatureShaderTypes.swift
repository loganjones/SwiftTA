//
//  MapViewRenderer+MetalShaderTypes.h
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import simd

enum MetalMapViewRenderer_BufferIndex: Int {
    case uniforms     = 3
    case vertices     = 4
}

enum MetalMapViewRenderer_FeatureQuadVertexAttribute: Int {
    case position = 0
    case texcoord = 1
}

enum MetalMapViewRenderer_TextureIndex: Int {
    case color              = 0
}



struct MetalMapViewRenderer_FeatureQuadVertex {
    var position: vector_float3
    var texCoord: vector_float2
}

struct MetalMapViewRenderer_FeatureUniforms{
    var mvpMatrix: matrix_float4x4
}
