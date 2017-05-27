// ta_COB.h //                                     \author Logan Jones
/////////////                                         \date 2/22/2001
/// \file
/// \brief ...
/////////////////////////////////////////////////////////////////////
#ifndef _TA_COB_H_
#define _TA_COB_H_
#pragma pack(1)
/////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////
/// Every COB begins with this header
typedef struct TA_COB_HEADER
{
    /// Specifies the COB version
	uint32_t		version;

    /// The number of script modules in this COB file
	uint32_t		numberOfModules;

    /// The number of pieces declared in this COB file
	uint32_t		numberOfPieces;

    /// The size in bytes of all the script modules
	uint32_t		lengthOfAllModules;

    /// The number of static variables declared in this COB
	uint32_t		numberOfStaticVars;

    /// This is always 0
	int32_t         alwaysZero;

    /// Offset to an array of indecies. These indecies point to the script
    /// modules of the COB. The array consists of uint32_t[ NumberOfScripts ]
	uint32_t		offsetToModulePointerArray;

    /// Offset to an array of indecies. These indecies point to the names of
    /// the script modules in the name array. The array consists of uint32_t[ NumberOfScripts ]
	uint32_t		offsetToModuleNameOffsetArray;

    /// Offset to an array of indecies. These indecies point to the names of
    /// the pieces in the name array. The array consists of uint32_t[ NumberOfPieces ]
	uint32_t		offsetToPieceNameOffsetArray;

    /// Offset to the first module in the COB
	uint32_t		offsetToFirstModule;

    /// Offset to the name array
	uint32_t		offsetToNameArray;

    /// Offset to an array of indecies. These indecies point to the names of
    /// the sounds in the name array. The array consists of uint32_t[ NumberOfSounds ]
	uint32_t		offsetToSoundNameArray;

    /// The number of sounds used in the script
	uint32_t		numberOfSounds;

} *LPTA_COB_HEADER;

/// Indicates that the COB is form Total Annihilation
#define TA_COB_TOTAL_ANNIHILATION			( 0x00000004 )

/// Indicates that the COB is form Kingdoms
#define TA_COB_KINGDOMS						( 0x00000006 )


/////////////////////////////////////////////////////////////////////
#pragma pack()
#endif // !defined(_TA_COB_H_)
