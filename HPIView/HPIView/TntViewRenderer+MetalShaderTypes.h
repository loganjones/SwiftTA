//
//  TntViewRenderer+MetalShaderTypes.h
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef TntShaderTypes_h
#define TntShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#define ATTR(_name) [[attribute(_name)]]
#else
#import <Foundation/Foundation.h>
#define ATTR(_name)
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, MetalTntViewRenderer_BufferIndex)
{
    MetalTntViewRenderer_BufferIndexVertices     = 0,
    MetalTntViewRenderer_BufferIndexUniforms     = 1,
    MetalTntViewRenderer_BufferIndexVertexTextureSlice  = 2,
};

typedef NS_ENUM(NSInteger, MetalTntViewRenderer_MapQuadVertexAttribute)
{
    MetalTntViewRenderer_MapQuadVertexAttributePosition = 0,
    MetalTntViewRenderer_MapQuadVertexAttributeTexcoord = 1,
};

typedef NS_ENUM(NSInteger, MetalTntViewRenderer_MapTileVertexAttribute)
{
    MetalTntViewRenderer_MapTileVertexAttributePosition = 0,
    MetalTntViewRenderer_MapTileVertexAttributeTexcoord = 1,
//    MetalTntViewRenderer_MapTileVertexAttributeSlice = 2,
};

typedef NS_ENUM(NSInteger, MetalTntViewRenderer_TextureIndex)
{
    MetalTntViewRenderer_TextureIndexColor              = 0,
};

#pragma pack(push, 1)

typedef struct
{
    vector_float3 position ATTR(MetalTntViewRenderer_MapTileVertexAttributePosition);
    vector_float2 texCoord ATTR(MetalTntViewRenderer_MapTileVertexAttributeTexcoord);
} MetalTntViewRenderer_MapQuadVertex;

typedef struct
{
    vector_float3 position ATTR(MetalTntViewRenderer_MapTileVertexAttributePosition);
    vector_float2 texCoord ATTR(MetalTntViewRenderer_MapTileVertexAttributeTexcoord);
//    int slice ATTR(MetalTntViewRenderer_MapTileVertexAttributeSlice);
} MetalTntViewRenderer_MapTileVertex;

typedef struct
{
    matrix_float4x4 mvpMatrix;
} MetalTntViewRenderer_MapUniforms;

#pragma pack(pop)

#endif /* TntShaderTypes_h */

