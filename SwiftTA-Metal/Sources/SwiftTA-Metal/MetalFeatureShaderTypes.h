//
//  MapViewRenderer+MetalShaderTypes.h
//  Metal Template macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef MapViewRendererShaderTypes_h
#define MapViewRendererShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#define ATTR(_name) [[attribute(_name)]]
#else
#import <Foundation/Foundation.h>
#define ATTR(_name)
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, MetalMapViewRenderer_BufferIndex)
{
    MetalMapViewRenderer_BufferIndexUniforms     = 3,
    MetalMapViewRenderer_BufferIndexVertices     = 4,
};

typedef NS_ENUM(NSInteger, MetalMapViewRenderer_FeatureQuadVertexAttribute)
{
    MetalMapViewRenderer_FeatureQuadVertexAttributePosition = 0,
    MetalMapViewRenderer_FeatureQuadVertexAttributeTexcoord = 1,
};

typedef NS_ENUM(NSInteger, MetalMapViewRenderer_TextureIndex)
{
    MetalMapViewRenderer_TextureIndexColor              = 0,
};

#pragma pack(push, 1)

typedef struct
{
    vector_float3 position ATTR(MetalMapViewRenderer_FeatureQuadVertexAttributePosition);
    vector_float2 texCoord ATTR(MetalMapViewRenderer_FeatureQuadVertexAttributeTexcoord);
} MetalMapViewRenderer_FeatureQuadVertex;

typedef struct
{
    matrix_float4x4 mvpMatrix;
} MetalMapViewRenderer_FeatureUniforms;

#pragma pack(pop)

#endif /* MapViewRendererShaderTypes_h */

