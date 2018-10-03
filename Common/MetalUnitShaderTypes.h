//
//  UnitViewRenderer+MetalShaderTypes.h
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef UnitViewRendererShaderTypes_h
#define UnitViewRendererShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#define ATTR(_name) [[attribute(_name)]]
#else
#import <Foundation/Foundation.h>
#define ATTR(_name)
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, UnitMetalRenderer_BufferIndex)
{
    UnitMetalRenderer_BufferIndexModelVertices     = 5,
    UnitMetalRenderer_BufferIndexUniforms          = 6,
};

typedef NS_ENUM(NSInteger, UnitMetalRenderer_ModelVertexAttribute)
{
    UnitMetalRenderer_ModelVertexAttributePosition = 0,
    UnitMetalRenderer_ModelVertexAttributeNormal   = 1,
    UnitMetalRenderer_ModelVertexAttributeTexcoord = 2,
    UnitMetalRenderer_ModelVertexAttributePieceIndex = 3,
};

typedef NS_ENUM(NSInteger, UnitMetalRenderer_TextureIndex)
{
    UnitMetalRenderer_TextureIndexColor            = 0,
};

#pragma pack(push, 1)

typedef struct
{
    vector_float3 position ATTR(UnitMetalRenderer_ModelVertexAttributePosition);
    vector_float3 normal ATTR(UnitMetalRenderer_ModelVertexAttributeNormal);
    vector_float2 texCoord ATTR(UnitMetalRenderer_ModelVertexAttributeTexcoord);
    int pieceIndex ATTR(UnitMetalRenderer_ModelVertexAttributePieceIndex);
} UnitMetalRenderer_ModelVertex;

typedef struct
{
    matrix_float4x4 vpMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x4 pieces[40];
} UnitMetalRenderer_ModelUniforms;

#pragma pack(pop)

#endif /* UnitViewRendererShaderTypes_h */

