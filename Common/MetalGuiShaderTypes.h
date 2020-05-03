//
//  MetalGuiShaderTypes.h
//  SwiftTA
//
//  Created by Logan Jones on 4/4/20.
//  Copyright © 2020 Logan Jones. All rights reserved.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef GuiShaderTypes_h
#define GuiShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#define ATTR(_name) [[attribute(_name)]]
#else
#import <Foundation/Foundation.h>
#define ATTR(_name)
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, MetalGui_BufferIndex)
{
    MetalGui_BufferIndexVertices     = 7,
    MetalGui_BufferIndexUniforms     = 8,
};

typedef NS_ENUM(NSInteger, MetalGui_QuadVertexAttribute)
{
    MetalGui_QuadVertexAttributePosition = 0,
    MetalGui_QuadVertexAttributeTexcoord = 1,
};

typedef NS_ENUM(NSInteger, MetalGui_TextureIndex)
{
    MetalGui_TextureIndexColor              = 0,
};

#pragma pack(push, 1)

typedef struct
{
    vector_float3 position ATTR(MetalGui_QuadVertexAttributePosition);
    vector_float2 texCoord ATTR(MetalGui_QuadVertexAttributeTexcoord);
} MetalGui_QuadVertex;

typedef struct
{
    matrix_float4x4 mvpMatrix;
} MetalGui_Uniforms;

#pragma pack(pop)

#endif /* GuiShaderTypes_h */

