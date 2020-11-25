//
//  ModelViewRenderer+MetalShaders.metal
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "MetalUnitShaderTypes.h"

using namespace metal;

#pragma mark - Model

typedef struct
{
    float4 position [[position]];
    float3 positionM;
    float3 normal;
    float2 texCoord;
} FragmentIn;

vertex FragmentIn unitVertexShader(UnitMetalRenderer_ModelVertex in [[stage_in]],
                                   constant UnitMetalRenderer_ModelUniforms & uniforms [[ buffer(UnitMetalRenderer_BufferIndexUniforms) ]])
{
    FragmentIn out;

    float4 position = uniforms.pieces[in.pieceIndex] * float4(in.position, 1.0);
    out.position = uniforms.vpMatrix * position;
    out.positionM = float3(position);
    out.normal = uniforms.normalMatrix * in.normal;
    out.texCoord = in.texCoord;

    return out;
}

fragment float4 unitFragmentShader(FragmentIn in [[stage_in]],
                                   constant UnitMetalRenderer_ModelUniforms & uniforms [[ buffer(UnitMetalRenderer_BufferIndexUniforms) ]],
                                   texture2d<half> colorMap     [[ texture(UnitMetalRenderer_TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::nearest,
                                   mag_filter::nearest,
                                   min_filter::nearest);
    half4 colorSample = colorMap.sample(colorSampler, in.texCoord.xy);
    
    return float4(colorSample);
}
