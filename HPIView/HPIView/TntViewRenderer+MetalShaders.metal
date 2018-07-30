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
#import "TntViewRenderer+MetalShaderTypes.h"

using namespace metal;

#pragma mark - Quad

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} QuadFragmentIn;

vertex QuadFragmentIn mapQuadVertexShader(MetalTntViewRenderer_MapQuadVertex in [[stage_in]],
                                       constant MetalTntViewRenderer_MapUniforms & uniforms [[ buffer(MetalTntViewRenderer_BufferIndexUniforms) ]])
{
    QuadFragmentIn out;
    out.position = uniforms.mvpMatrix * float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 mapQuadFragmentShader(QuadFragmentIn in [[stage_in]],
                                   constant MetalTntViewRenderer_MapUniforms & uniforms [[ buffer(MetalTntViewRenderer_BufferIndexUniforms) ]],
                                   texture2d<half> colorMap     [[ texture(MetalTntViewRenderer_TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::nearest,
                                   mag_filter::nearest,
                                   min_filter::nearest);
    half4 colorSample = colorMap.sample(colorSampler, in.texCoord.xy);

    return float4(colorSample);
}

#pragma mark - Array

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
    int slice;
} TileFragmentIn;

vertex TileFragmentIn mapTileVertexShader(MetalTntViewRenderer_MapTileVertex in [[stage_in]],
                                          constant MetalTntViewRenderer_MapUniforms & uniforms [[ buffer(MetalTntViewRenderer_BufferIndexUniforms) ]])
{
    TileFragmentIn out;
    out.position = uniforms.mvpMatrix * float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    out.slice = in.slice;
    return out;
}

fragment float4 mapTileFragmentShader(TileFragmentIn in [[stage_in]],
                                      constant MetalTntViewRenderer_MapUniforms & uniforms [[ buffer(MetalTntViewRenderer_BufferIndexUniforms) ]],
                                      texture2d_array<half> colorMap     [[ texture(MetalTntViewRenderer_TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::nearest,
                                   mag_filter::nearest,
                                   min_filter::nearest);
    half4 colorSample = colorMap.sample(colorSampler, in.texCoord.xy, in.slice);
    
    return float4(colorSample);
}
