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
#import "ModelViewRenderer+MetalShaderTypes.h"

using namespace metal;

#pragma mark - Model

typedef struct
{
    float4 position [[position]];
    float3 positionM;
    float3 normal;
    float2 texCoord;
} FragmentIn;

vertex FragmentIn vertexShader(ModelMetalRenderer_ModelVertex in [[stage_in]],
                               constant ModelMetalRenderer_ModelUniforms & uniforms [[ buffer(ModelMetalRenderer_BufferIndexUniforms) ]])
{
    FragmentIn out;

    float4 position = uniforms.modelMatrix * float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * position;
    out.positionM = float3(position);
    out.normal = uniforms.normalMatrix * in.normal;
    out.texCoord = in.texCoord;

    return out;
}

fragment float4 fragmentShader(FragmentIn in [[stage_in]],
                               constant ModelMetalRenderer_ModelUniforms & uniforms [[ buffer(ModelMetalRenderer_BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(ModelMetalRenderer_TextureIndexColor) ]])
{
//    constexpr sampler colorSampler(mip_filter::linear,
//                                   mag_filter::linear,
//                                   min_filter::linear);
//
//    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);

//    return float4(0,0,1,1);
    
    float3 lightColor = float3(1.0, 1.0, 1.0);
    
    // ambient
    float ambientStrength = 0.6;
    float3 ambient = ambientStrength * lightColor;
    
    // diffuse
    float diffuseStrength = 0.4;
    float3 norm = normalize(in.normal);
    float3 lightDir = normalize(uniforms.lightPosition - in.positionM);
    float diff = max(dot(norm, lightDir), 0.0);
    float3 diffuse = diffuseStrength * diff * lightColor;
    
    // specular
    float specularStrength = 0.1;
    float3 viewDir = normalize(uniforms.viewPosition - in.positionM);
    float3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    float3 specular = specularStrength * spec * lightColor;
    
    // all together now
    float4 lightContribution = float4(ambient + diffuse + specular, 1.0);
    
    float4 out_color;
//    if (objectColor.a == 0.0) {
//        out_color = lightContribution * texture(colorTexture, fragment_texture);
//    }
//    else {
        out_color = lightContribution * uniforms.objectColor;
//    }
    return out_color;
}

#pragma mark - Grid

typedef struct
{
    float4 position [[position]];
} GridFragmentIn;

vertex GridFragmentIn gridVertexShader(ModelMetalRenderer_GridVertex in [[stage_in]],
                                       constant ModelMetalRenderer_GridUniforms & uniforms [[ buffer(ModelMetalRenderer_BufferIndexUniforms) ]])
{
    GridFragmentIn out;
    out.position = uniforms.gridMvpMatrix * float4(in.position, 1.0);
    return out;
}

fragment float4 gridFragmentShader(GridFragmentIn in [[stage_in]],
                                   constant ModelMetalRenderer_GridUniforms & uniforms [[ buffer(ModelMetalRenderer_BufferIndexUniforms) ]],
                                   texture2d<half> colorMap     [[ texture(ModelMetalRenderer_TextureIndexColor) ]])
{
    return uniforms.gridColor;
}
