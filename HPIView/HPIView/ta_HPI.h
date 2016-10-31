// ta_HPI.h //                                     \author Logan Jones
/////////////                                         \date 2/22/2001
/// \file
/// \brief ...
/////////////////////////////////////////////////////////////////////
#ifndef _TA_HPI_H_
#define _TA_HPI_H_
#include <stdint.h>
#pragma pack(1)
/////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////
// NOTE: Some of the content in this file was derived from the document
//       ta-hpi-fmt.txt by Joe D.


/////////////////////////////////////////////////////////////////////
// Every HPI begins with this header
typedef struct TA_HPI_HEADER
{
    // This marks this file as an HPI file, should be 'HAPI'
	uint32_t		marker;

    // The file type version of this HPI file
	uint32_t		version;

} *LPTA_HPI_HEADER;

// Every valid hpi should have its marker set to this 'HAPI'
static const uint32_t TA_HPI_MARKER						= 0x49504148;

// This indicates that this HPI is a Total Annihilation HPI file.
// Following the TA_HPI_HEADER is the TA_HPI_EXT_HEADER
static const uint32_t TA_HPI_TOTAL_ANNIHILATION			= 0x00010000;

// This indicates that this HPI is a Kingdoms HPI file.
// Following the TA_HPI_HEADER is the TAK_HPI_EXT_HEADER
static const uint32_t TA_HPI_KINGDOMS					= 0x00020000;

// This indicates that this HPI is a Savegame file.
static const uint32_t TA_HPI_SAVEGAME					= 0x4B4E4142;


/////////////////////////////////////////////////////////////////////
// This structure follows the TA_HPI_HEADER
typedef struct TA_HPI_EXT_HEADER
{
    // The sizee in bytes of the directory tree.
	uint32_t		directorySize;

    // This is the decrytion key for the rest of the file.
    // If it is zero, the file is not encrypted.
	uint32_t		headerKey;

    // Specifies the offset in the file where the directory tree resides
	uint32_t		offsetToDirectory;

} *LPTA_HPI_EXT_HEADER;


/////////////////////////////////////////////////////////////////////
// This structure follows the TA_HPI_HEADER
typedef struct TAK_HPI_EXT_HEADER
{
    // Specifies the location in the file of the directory tree
    // data chunk
	uint32_t		offsetToDirectory;

    // The size of the directory tree data chunk
	uint32_t		directorySize;

    // Specifies the offset in the file where an array of NULL terminated
    // name strings reside.
	uint32_t		offsetToFileNames;

    // The size of the name array in bytes.
	uint32_t		fileNameSize;

    // The offset to the first data chunk in this HPI
	uint32_t		offsetToStartOfData;

    // Specifies the offset in the file that holds an array of bytes
    // that is used to verify the HPI as CAVEDOG(tm) or third-party
	uint32_t		offsetToCavedogVerification;

} *LPTAK_HPI_EXT_HEADER;


/////////////////////////////////////////////////////////////////////
// This structure is the header of every directory encountered in the tree
typedef struct TA_HPI_DIR_HEADER
{
    // Specifies the number of entries in this directory
	uint32_t		numberOfEntries;

    // Offset into the file where the array of entries is located.
    // This array consists of TA_HPI_ENTRY[ NumberOfEntries ]
	uint32_t		offsetToEntryArray;

} *LPTA_HPI_DIR_HEADER;


/////////////////////////////////////////////////////////////////////
// This structure is an entry for an item in a directory
typedef struct TA_HPI_ENTRY
{
    // Offset into the file where a NULL terminated name string resides.
	uint32_t		offsetToName;

    // Offset into the file where the data of this entry resides
	uint32_t		offsetToEntryData;

    // Specifies the type of entry this is
	uint8_t		entryFlag;
} *LPTA_HPI_ENTRY;

// Indicates that the entry is a file
static const uint8_t TA_HPI_ENTRY_FILE						= 0;

// Indicates that the entry is a directory
static const uint8_t TA_HPI_ENTRY_DIRECTORY					= 1;


/////////////////////////////////////////////////////////////////////
// This structure contains the data for a file entry
typedef struct TA_HPI_FILE_ENTRY
{
    // Offset in the file where the file's data resides
	uint32_t		offsetToFileData;

    // The decompressed size of file in bytes
	uint32_t		fileSize;

    // Specifies the compression metthod used on the file data, if any
	uint8_t		compressionType;

} *LPTA_HPI_FILE_ENTRY;

// Compression flag indicating that the file data is not compressed
static const uint8_t TA_HPI_FILE_NOT_COMPRESSED				= 0;

// Compression flag indicating that the file data is compressed using
// LZ77 compression
static const uint8_t TA_HPI_FILE_LZ77						= 1;

// Compression flag indicating that the file data is compressed using
// ZLIB compression 
static const uint8_t TA_HPI_FILE_ZLIB						= 2;


/////////////////////////////////////////////////////////////////////
// This structre defines a TAK HPI directory entry
typedef struct TAK_HPI_DIR_ENTRY
{
    // Offset in the name array to a NULL terminated string that serves as
    // the directory name.
    uint32_t		offsetToDirectoryName;

    // Offset into the directory tree at which the directory entry array resides
    // This array consists of TAK_HPI_DIR_ENTRY[ NumberOfSubDirectories ]
    uint32_t		offsetToSubDirectoryArray;

    // The number of sub directories in this directory
    uint32_t		numberOfSubDirectories;

    // Offset into the directory tree at which the file entry array resides
    // This array consists of TAK_HPI_FILE_ENTRY[ NumberOfFileEntries ]
    uint32_t		offsetToFileEntryArray;

    // The number of files in this directory
    uint32_t		numberOfFileEntries;

} *LPTAK_HPI_DIR_ENTRY;


/////////////////////////////////////////////////////////////////////
// This structre defines a TAK HPI file entry
typedef struct TAK_HPI_FILE_ENTRY
{
    // Offset in the name array to a NULL terminated string that serves as
    // the file name.
    uint32_t		offsetToFileName;

    // Offset into the file at which the file's data chunk resides
    uint32_t		offsetToFileData;

    // Decompressed size of the file in bytes
    uint32_t		decompressedSize;

    // Compressed size of the file in bytes
    uint32_t		compressedSize;

    // Specifies the data of the file
    uint32_t		fileDate;

    // Specifies the checksum of the file
    uint32_t		checksum;

} *LPTAK_HPI_FILE_ENTRY;


/////////////////////////////////////////////////////////////////////
// This structure precedes a data chunk in an HPI file
typedef struct TA_HPI_CHUNK
{
    // This marks this as a data chunk
	uint32_t	marker;

    // This is always 0x02
	uint8_t		unknown_1;

    // Specifies the compression method used on the chunk
	uint8_t		compressionType;

    // Specifies if the chunk is encrypted.
    // If 0, no encryption is used.
	uint8_t		encryptionFlag;

    // The compressed size of the chunk in bytes
	uint32_t		compressedSize;

    // The decompressed size of the chunk in bytes
	uint32_t		decompressedSize;

    // This is the checksum value calculated as the sum of the encrypted,
    // compressed data
	uint32_t		checksum;

    // Following this structure is an array of bytes that form the data
    // for this chunk.
    // uint8_t     data[ CompressedSize ];

} *LPTA_HPI_CHUNK;

// Check for the marker to make sure the chunk is valid. Should be 'SQSH'
static const uint32_t TA_HPI_CHUNK_MARKER					= 0x48535153;

// Compression flag indicating that the chunk data is not compressed
static const uint8_t TA_HPI_CHUNK_NOT_COMPRESSED			= 0;

// Compression flag indicating that the chunk data is compressed using
// LZ77 compression
static const uint8_t TA_HPI_CHUNK_LZ77						= 1;

// Compression flag indicating that the chunk data is compressed using
// ZLIB compression 
static const uint8_t TA_HPI_CHUNK_ZLIB						= 2;

// The default chunk size for when a Total Annihilation file is split up
// into many chunks
static const uint32_t TA_HPI_CHUNK_DEFAULT_SIZE				= 65536;


/////////////////////////////////////////////////////////////////////
#pragma pack()
#endif // !defined(_TA_HPI_H_)
