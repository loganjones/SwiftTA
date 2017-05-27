// ta_3DO.h //                                     \author Logan Jones
/////////////                                         \date 2/22/2001
/// \file
/// \brief ...
/////////////////////////////////////////////////////////////////////
#ifndef _TA_3DO_H_
#define _TA_3DO_H_
#pragma pack(1)
/////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////
// NOTE: Most of the content in this file was derived from the document
//       ta-3DO-fmt.txt by Dan Melchione.


// TODO: Prototype 3DO utility functions


/////////////////////////////////////////////////////////////////////
/// A 3DO contains a tree of 3D objects used in the composition of
/// a model. Each object uses this structure to collect its data. The
/// parent object is at the head of the file, every other object can
/// be obtained from the parent.
typedef struct TA_3DO_OBJECT
{
    /// Version of the 3DO file. Should always be 0x00000001
    uint32_t		version;

    /// Specifies the number of unique vertecies for this object
    uint32_t		numberOfVertexes;

    /// Specifies the number of unique primitives for this object
    uint32_t		numberOfPrimitives;

    /// The primitive index for the model's ground plate.
    /// If this is -1, there is no ground plate primitive in this object
    int32_t		groundPlateIndex;

    /// The translation offset of this object from its parent
    int32_t		xFromParent;
    int32_t		yFromParent;
    int32_t		zFromParent;

    /// The offset in the file at which this object's name resides
    /// The name is a NULL terminated character string
    uint32_t		offsetToObjectName;

    /// This is always 0x00000000
    uint32_t		Unknown_1;

    /// The offset in the file at which this object's vertex array resides
    /// This array consists of TA_3DO_VERTEX[ NumberOfVertexes ]
    uint32_t		offsetToVertexArray;

    /// The offset in the file at which this object's primitive array resides
    /// This array consists of TA_3DO_PRIMITIVE[ NumberOfPrimitives ]
    uint32_t		offsetToPrimitiveArray;

    /// The offset in the file to an object that shares its parent with this one.
    /// If this is 0, there is no sibling.
    uint32_t		offsetToSiblingObject;

    /// The offset in the file to an object that has this object as its parent.
    /// If this is 0, there is no child.
    uint32_t		offsetToChildObject;

} *LPTA_3DO_OBJECT;

// The standard version for all 3DO files
static const uint32_t TA_3DO_VERSION_STANDARD   = 1;


/////////////////////////////////////////////////////////////////////
/// The stucture of each vertex used by the objects
typedef struct TA_3DO_VERTEX
{
    /// The respective coordinates for the vertex
	int32_t		x;
	int32_t		y;
	int32_t		z;

} *LPTA_3DO_VERTEX;


/////////////////////////////////////////////////////////////////////
// The stucture of each vertex used by the objects
typedef struct TA_3DO_PRIMITIVE
{
    /// If there is no texture, this specifies the primitive's color.
    uint32_t		color;

    /// Specifies the number of vertecies used by the primitive
    uint32_t		numberOfVertexIndexes;

    /// This is always 0
    int32_t		unknown_1;

    /// The offset in the file at which this primitive's vertex index array resides.
    /// This array consists of WORD[ NumberOfVertexIndexes ]
    uint32_t		offsetToVertexIndexArray;

    /// The offset in the file at which this primitive's texture name resides
    /// The name is a NULL terminated character string
    /// If this is 0, there is no texture, there is a color value in Color
    uint32_t		offsetToTextureName;

    /// "Cavedog(tm) specific data used for their editor", Dan Melchione.
    int32_t		cavedogSpecific_1;
    int32_t		cavedogSpecific_2;
    int32_t		cavedogSpecific_3;

} *LPTA_3DO_PRIMITIVE_3DO;


/////////////////////////////////////////////////////////////////////
#pragma pack()
#endif // !defined(_TA_3DO_H_)
