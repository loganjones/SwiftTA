// ta_TNT.h //                                     \author Logan Jones
/////////////                                         \date 2/22/2001
/// \file
/// \brief ...
/////////////////////////////////////////////////////////////////////
#ifndef _TA_TNT_H_
#define _TA_TNT_H_
#pragma pack(1)
/////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////
// NOTE: Some of the content in this file was derived from the document
//       ta-tnt-fmt.txt by Saruman & Bobban.


// TODO: Prototype TNT utility functions


/////////////////////////////////////////////////////////////////////
/// Every TNT begins with this header
typedef struct TA_TNT_HEADER
{
    /// Specifies the TNT version of this map
	int32_t         version;

    /// The width and height of this map in map-units.
    /// A map-unit is 16x16 pixels, so to find the pixel width or height,
    /// PixelWidth = Width*16; PixelHeight = Height*16;
	uint32_t		width;
	uint32_t		height;

} *LPTA_TNT_HEADER;

/// This indicates that this is a Total Annihilation TNT file.
/// The remaining potion of the header should use the TA_TNT_EXT_HEADER type
#define TA_TNT_TOTAL_ANNIHILATION			( 0x00002000 )

/// This indicates that this is a Kingdoms TNT file.
/// The remaining potion of the header should use the TAK_TNT_EXT_HEADER type
#define TA_TNT_KINGDOMS						( 0x00004000 )


/////////////////////////////////////////////////////////////////////
/// The remaing portion of the header uses this strucure if this
/// is a Total Annihilation TNT file
typedef struct TA_TNT_EXT_HEADER
{
    /// Specifies the location of an array that contains indicies into the
    /// tile array. This array consists of uint16_t[ (Width/2)*(Height/2) ].
    /// This array specifies the arrangement of the tiles on the map.
	uint32_t		offsetToTileIndexArray;

    /// Specifies the location of an array that contains information on each
    /// map-unit in the map. This array consists of uint32_t[ Width*Height ].
	uint32_t		offsetToMapInfoArray;

    /// Specifies the location of an array that contains the garphic tiles
    /// used for drawing the map. Each tile is 32x32 bytes. The total size
    /// of this array is (32x32)*NumberOfTiles.
	uint32_t		offsetToTileArray;

    /// Specifies the amount of unique tiles in the tile array
	uint32_t		numberOfTiles;

    /// Specifies the amount of unique features in the feature array
	uint32_t		numberOfFeatures;

    /// Offset to the location in the file at which the array of feature
    /// entries resides. This array consists of
    /// TA_TNT_FEATURE_ENTRY[ NumberOfFeatures ]
	uint32_t		offsetToFeatureEntryArray;

    /// Specifies the level at which a height-map point can be considered
    /// above or below water.
	uint32_t		seaLevel;

    /// Specifies the location in the file of the minimap for the TNT.
    /// At this location there are two uint32_t entries coresponding to the
    /// width and height of the mini-map. After these is the pixels for the
    /// graphic consisting of width*height bytes.
	uint32_t		offsetToMiniMap;

    /// Usually 0x00000001
	uint32_t		unknown_1;

    /// 16 bytes of what seems like padding. Always 0
	uint8_t         padding[16];

} *LPTA_TNT_EXT_HEADER;


/////////////////////////////////////////////////////////////////////
/// This structurte identifies a feature with this index used in the TNT
typedef struct TA_TNT_MAP_ENTRY
{
	/// The elevation of this point in the map
	uint8_t		elevation;

	/// Contains some extra information about this point.
	/// If this value is in the range of [0,NumberOfFeatures), then this
	/// is the index of the feature that is loacted at this point.
	/// If this value is less than 0 then there is nothing special
	/// at this point.
	uint16_t		special;

	/// Unknown
	uint8_t		unknown;

} *LPTA_TNT_MAP_ENTRY;


/////////////////////////////////////////////////////////////////////
/// The remaing portion of the header uses this strucure if this
/// is a Kingdoms TNT file
typedef struct TAK_TNT_EXT_HEADER
{
    /// Specifies the level at which a height-map point can be considered
    /// above or below water.
	uint32_t		seaLevel;

    /// Specifies the location of an array that contains height information of
    /// each map-unit in the map. This array consists of BYTE[ Width*Height ].
	uint32_t		offsetToHeightMap;

    /// Specifies the location of an array that contains feature information of
    /// each map-unit in the map. This array consists of uint32_t[ Width*Height ].
	uint32_t		offsetToFeatureSpotArray;
    
    /// Offset to the location in the file at which the array of feature
    /// entries resides. This array consists of
    /// TA_TNT_FEATURE_ENTRY[ NumberOfFeatures ]
	uint32_t		offsetToFeatureEntryArray;
    
    /// Specifies the amount of unique features in the feature array
	uint32_t		numberOfFeatures;

    /// The arrays at these offsets combine to specify the arrangement of
    /// garphical tiles on the map. For each tile, a uint32_t value is used from
    /// each array at the tile's index. These three values are the tile name,
    /// row number and column number. A tile anme is a 32-bit unique value used
    /// to identify a JPG for the graphical image.
    /// The row and column numbers are offsets into the JPG. At this offset a 32x32
    /// section is removed and that is the tile for this map point.
    /// So simply  -     Load JPG TileNameArray[index]
    ///                  Remove tile from JPG at ColumnIndexArray[index]*32 , RowIndexArray[index]*32
    ///                  Place on the map at index
    /// Each of the arrays is uint32_t[ (Width/2)*(Height/2) ]
	uint32_t		offsetToTileNameArray;
	uint32_t		offsetToColumnIndexArray;
	uint32_t		offsetToRowIndexArray;

    /// Specifies the location in the file of the minimaps for the TNT.
    /// At these locations there are two uint32_t entries coresponding to the
    /// width and height of the mini-map. After these is the pixels for the
    /// graphic consisting of width*height bytes.
	uint32_t		offsetToSmallMiniMap;
	uint32_t		offsetToLargeMiniMap;

} *LPTAK_TNT_EXT_HEADER;


/////////////////////////////////////////////////////////////////////
/// This structurte identifies a feature with this index used in the TNT
typedef struct TA_TNT_FEATURE_ENTRY
{
	uint32_t		index;
	uint8_t		name[128];
} *LPTA_TNT_FEATURE_ENTRY;


/////////////////////////////////////////////////////////////////////
#pragma pack()
#endif // !defined(_TA_TNT_H_)
