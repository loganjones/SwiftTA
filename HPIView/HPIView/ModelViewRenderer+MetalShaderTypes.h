//
//  ModelViewRenderer+MetalShaderTypes.h
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#define ATTR(_name) [[attribute(_name)]]
#else
#import <Foundation/Foundation.h>
#define ATTR(_name)
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, ModelMetalRenderer_BufferIndex)
{
    ModelMetalRenderer_BufferIndexModelVertices     = 0,
    ModelMetalRenderer_BufferIndexGridVertices      = 1,
    ModelMetalRenderer_BufferIndexUniforms          = 2,
};

typedef NS_ENUM(NSInteger, ModelMetalRenderer_ModelVertexAttribute)
{
    ModelMetalRenderer_ModelVertexAttributePosition = 0,
    ModelMetalRenderer_ModelVertexAttributeNormal   = 1,
    ModelMetalRenderer_ModelVertexAttributeTexcoord = 2,
};

typedef NS_ENUM(NSInteger, ModelMetalRenderer_GridVertexAttribute)
{
    ModelMetalRenderer_GridVertexAttributePosition = 0,
};

typedef NS_ENUM(NSInteger, ModelMetalRenderer_TextureIndex)
{
    ModelMetalRenderer_TextureIndexColor            = 0,
};

#pragma pack(push, 1)

typedef struct
{
    vector_float3 position ATTR(ModelMetalRenderer_ModelVertexAttributePosition);
    vector_float3 normal ATTR(ModelMetalRenderer_ModelVertexAttributeNormal);
    vector_float2 texCoord ATTR(ModelMetalRenderer_ModelVertexAttributeTexcoord);
} ModelMetalRenderer_ModelVertex;

typedef struct
{
    vector_float3 position ATTR(ModelMetalRenderer_GridVertexAttributePosition);
} ModelMetalRenderer_GridVertex;

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 modelMatrix;
    matrix_float3x3 normalMatrix;
    vector_float4 objectColor;
    vector_float3 lightPosition;
    vector_float3 viewPosition;
} ModelMetalRenderer_ModelUniforms;

typedef struct
{
    matrix_float4x4 gridMvpMatrix;
    vector_float4 gridColor;
} ModelMetalRenderer_GridUniforms;

#pragma pack(pop)

#endif /* ShaderTypes_h */

