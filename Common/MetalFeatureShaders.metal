//
//  MapViewRenderer+MetalShaders.metal
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "MetalFeatureShaderTypes.h"

using namespace metal;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} QuadFragmentIn;

vertex QuadFragmentIn featureQuadVertexShader(MetalMapViewRenderer_FeatureQuadVertex in [[stage_in]],
                                              constant MetalMapViewRenderer_FeatureUniforms & uniforms [[ buffer(MetalMapViewRenderer_BufferIndexUniforms) ]])
{
    QuadFragmentIn out;
    out.position = uniforms.mvpMatrix * float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 featureQuadFragmentShader(QuadFragmentIn in [[stage_in]],
                                      constant MetalMapViewRenderer_FeatureUniforms & uniforms [[ buffer(MetalMapViewRenderer_BufferIndexUniforms) ]],
                                      texture2d<half> colorMap     [[ texture(MetalMapViewRenderer_TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::nearest,
                                   mag_filter::nearest,
                                   min_filter::nearest);
    half4 colorSample = colorMap.sample(colorSampler, in.texCoord.xy);
    
    if (colorSample.a < 0.2)
        discard_fragment();
    
    return float4(colorSample);
}
