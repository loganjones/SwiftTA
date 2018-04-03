// ta_GAF.h //                                     \author Logan Jones
/////////////                                         \date 2/22/2001
/// \file
/// \brief ...
/////////////////////////////////////////////////////////////////////
#ifndef _TA_GAF_H_
#define _TA_GAF_H_
#pragma pack(1)
/////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////
// NOTE: Most of the content in this file was derived from the document
//       ta-gaf-fmt.txt by Joe D.


/// The header at the beginning of ever GAF or TAF
typedef struct TA_GAF_HEADER
{
    /// Version is always 0x00010100 for both TA and Kingdoms
	uint32_t		version;

    /// Specifies the number of entries contained in this file
	uint32_t		numberOfEntries;

    /// Presumably padding, its always 0x00000000
	uint32_t		unknown_1;

    // Immediately following this header is an array of pointers to each
    // entry in this file.
    //uint32_t     EntryPointers[ NumberOfEntries ];

} *LPTA_GAF_HEADER;

/// The standard version for all GAFs and TAFs
static const uint32_t TA_GAF_VERSION_STANDARD                   = 0x00010100;


/// Each entry pointer points to a structure of this type.
typedef struct TA_GAF_ENTRY
{
    /// Scecifies the number of graphical frames for this entry item
	uint16_t		numberOfFrames;

    /// This is always 0x0001
	uint16_t		unknown_1;

    /// This is always 0x0000
	uint32_t		unknown_2;

    /// The unique name of this entry, always padded to 32 characters long with 0
	uint8_t         nameBuffer[32];

    // Immediately following an entry is an array of frame entries
    //TA_GAF_FRAME_ENTRY    FrameEntries[ NumberOfFrames ];

} *LPTA_GAF_ENTRY;

static const uint8_t TA_GAF_ENTRY_NAME_FIELD_SIZE               = 32;


/// This structure provides an offset to the frame data
typedef struct TA_GAF_FRAME_ENTRY
{
    /// The offset into the file at which the frame's data resides
	uint32_t		offsetToFrameData;

    /// This value seems to vary by a huge margin, perhaps it contains
    /// bit flags used by CAVEDOG.
	uint32_t		unknown_1;

} *LPTA_GAF_FRAME_ENTRY;


typedef struct TA_GAF_FRAME_DATA
{
    /// The final width and height of the frame in pixels
	uint16_t		width;
	uint16_t		height;

    /// The X and Y offset of the frame when displayed. Used for centering the
    /// frame or other various purposes. Sometimes just ignored.
	int16_t		xOffset;
	int16_t		yOffset;

    /// This is always 0x09
	uint8_t		unknown_1;

    /// The encoding flag for this frame
	uint8_t		encoding;

    /// Specifies the amount of subframes associated with this frame
	uint16_t		numberOfSubFrames;

    /// This is always 0x00000000
	uint32_t		unknown_2;

    /// If there are no sub frames, this points to the pixel data.
    /// If there are sub frames, this points to an array of offsets to
    /// the sb frame data structures.
	uint32_t		offsetToFrameData;

    /// This seems to be another value that holds bit flags
	uint32_t		unknown_3;

} *LPTA_GAF_FRAME_DATA;

/// The data at `offsetToFrameData` is a raw collection of `width` x `height` bytes.
/// Once read, the result is an 8-bit per pixel paletted image.
static const uint8_t TA_GAF_FRAME_NOT_COMPRESSED					= 0;

/// The data at `offsetToFrameData` is a RLE collection of bytes.
/// When decoded, the result is an 8-bit per pixel paletted image.
static const uint8_t TA_GAF_FRAME_COMPRESSED_TA						= 1;

/// The data at `offsetToFrameData` is a raw collection of `width` x `height` x 2 bytes.
/// Once read, the result is a 16-bit per pixel image with a pixel format of 4444 (4 bits per component).
static const uint8_t TA_GAF_FRAME_NOT_COMPRESSED_TAK_4444			= 4;

/// The data at `offsetToFrameData` is a raw collection of `width` x `height` x 2 bytes.
/// Once read, the result is a 16-bit per pixel image with a pixel format of 1555 (5 bits per RGB component, 1 bit alpha).
static const uint8_t TA_GAF_FRAME_NOT_COMPRESSED_TAK_1555			= 5;


/////////////////////////////////////////////////////////////////////
#pragma pack()
#endif // !defined(_TA_GAF_H_)
