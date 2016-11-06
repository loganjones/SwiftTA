//
//  HPI.swift
//  HPIView
//
//  Created by Logan Jones on 9/12/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation

public enum HPIFormat {
    
    public struct FileHeader {
        
        /// This marks this file as an HPI file, should be 'HAPI'.
        var marker: UInt32
        
        /// The file type version of this HPI file.
        var version: UInt32
    }
    
    /// Every valid hpi should have its marker set to this 'HAPI'
    public static let FileHeaderMarker: UInt32 = 0x49504148
    
    public enum FileHeaderVersion: UInt32 {
        
        /// This indicates that this HPI is a Total Annihilation HPI file.
        // Following the HPI.FileHeader is the HPI.TAExtendedHeader.
        case ta = 0x00010000
        
        /// This indicates that this HPI is a Kingdoms HPI file.
        // Following the HPI.FileHeader is the HPI.TAKExtendedHeader.
        case tak = 0x00020000
        
        /// This indicates that this HPI is a Savegame file.
        /// 'BANK'
        case savegame = 0x4B4E4142
    }
    
    public struct TAExtendedHeader {
        
        /// The sizee in bytes of the directory tree.
        var directorySize: UInt32

        /// This is the decrytion key for the rest of the file.
        /// If it is zero, the file is not encrypted.
        var headerKey: Int32

        /// Specifies the offset in the file where the directory tree resides.
        var directoryOffset: UInt32
    }
    
    public struct DirectoryHeader {
        
        /// Specifies the number of entries in this directory.
        var numberOfEntries: UInt32

        /// Offset into the file where the array of entries is located.
        /// This array consists of TA_HPI_ENTRY[ NumberOfEntries ].
        var entryArrayOffset: UInt32
    }
    
    public struct EntryHeader {
        
        /// Offset into the file where a NULL terminated name string resides.
        var nameOffset: UInt32
        
        /// Offset into the file where the data of this entry resides.
        var dataOffset: UInt32
        
        /// Specifies the type of entry this is.
        var flags: UInt8
    }
    
    struct EntryFlags: OptionSet {
        let rawValue: UInt8
        static let directory = EntryFlags(rawValue: 1 << 0)
    }
    
    public struct FileEntry {
        
        /// Offset in the file where the file's data resides.
        var offsetToFileData: UInt32
        
        /// The decompressed size of file in bytes.
        var fileSize: UInt32
        
        /// Specifies the compression method used on the file data, if any.
        var compressionType: UInt8
    }
    
    enum FileEntryCompression: UInt8 {
        
        /// Compression flag indicating that the file data is not compressed.
        case none = 0
        
        /// Compression flag indicating that the file data is compressed using LZ77 compression.
        case lz77 = 1
        
        /// Compression flag indicating that the file data is compressed using ZLIB compression.
        case zlib = 2
    }
    
    public struct ChunkHeader {
        
        /// This marks this as a data chunk.
        var marker: UInt32

        /// This is always 0x02.
        var unknown_1: UInt8

        /// Specifies the compression method used on the chunk.
        var compressionType: UInt8

        /// Specifies if the chunk is encrypted.
        /// If 0, no encryption is used.
        var encryptionFlag: UInt8

        /// The compressed size of the chunk in bytes.
        var compressedSize: UInt32

        /// The decompressed size of the chunk in bytes.
        var decompressedSize: UInt32

        /// This is the checksum value calculated as the sum of the encrypted,
        /// compressed data.
        var checksum: UInt32
    }
    
    /// Check for the marker to make sure the chunk is valid. Should be 'SQSH'
    public static let ChunkHeaderMarker: UInt32 = 0x48535153
    
    enum ChunckCompression: UInt8 {
        
        /// Compression flag indicating that the chunk data is not compressed.
        case none = 0
        
        /// Compression flag indicating that the chunk data is compressed using LZ77 compression.
        case lz77 = 1
        
        /// Compression flag indicating that the chunk data is compressed using ZLIB compression.
        case zlib = 2
    }
    
    /// The default chunk size for when a Total Annihilation file is split up
    /// into many chunks.
    public static let ChunkMaximumSize: UInt32 = 65536
    
}

extension FileHandle {
    
    func readAndDecryptData(ofLength size: Int, offset: UInt32, key: Int32) -> Data {
        seek(toFileOffset: UInt64(offset))
        var data = readData(ofLength: size)
        if data.count < size { print("read less data than requested! (wanted \(size) bytes, read \(data.count) bytes)") }
        let koffset = Int32(offset)
        if key != 0 {
            for index in 0..<data.count {
                let tkey = (koffset &+ Int32(index)) ^ key
                let inv = Int32(~data[index])
                data[index] = UInt8(truncatingBitPattern: tkey ^ inv)
            }
        }
        return data
    }
    
}

enum HPIItem {
    case file(name: String, size: Int, offset: Int, compression: HPIFormat.FileEntryCompression)
    indirect case directory(name: String, items: [HPIItem])
}

extension HPIItem {
    
    var name: String {
        switch self {
        case .file(let properties): return properties.name
        case .directory(let properties): return properties.name
        }
    }
    
}

extension HPIItem {
    
    init(withContentsOf url: URL) throws {
        
        guard let file = try? FileHandle(forReadingFrom: url)
            else { throw LoadError.failedToOpenFile }
        
        let headerData = file.readData(ofLength: MemoryLayout<HPIFormat.FileHeader>.size)
        let header: HPIFormat.FileHeader = headerData.withUnsafeBytes { $0.pointee }
        
        guard header.marker == HPIFormat.FileHeaderMarker
            else { throw LoadError.badHPIMarker(Int(header.marker)) }
        guard let hpiType = HPIFormat.FileHeaderVersion(rawValue: header.version)
            else { throw LoadError.badHPIType(Int(header.version)) }
        
        switch hpiType {
        case .ta: self = try HPIItem(withTAFile: file)
        case .tak: throw LoadError.unsupportedHPIType(Int(header.version))
        case .savegame: throw LoadError.unsupportedHPIType(Int(header.version))
        }
        
    }
    
    private init(withTAFile file: FileHandle) throws {
        let extData = file.readData(ofLength: MemoryLayout<HPIFormat.TAExtendedHeader>.size)
        let ext: HPIFormat.TAExtendedHeader = extData.withUnsafeBytes { $0.pointee }
        let key = ext.headerKey != 0 ? ~( (ext.headerKey * 4) | (ext.headerKey >> 6) ) : 0
        let items = try HPIItem.loadItems(fromTAFile: file, atOffset: ext.directoryOffset, withKey: key)
        self = .directory(name: "", items: items)
    }
    
    private static func loadItems(fromTAFile file: FileHandle, atOffset offset: UInt32, withKey key: Int32) throws -> [HPIItem] {
    
        let rootData = file.readAndDecryptData(ofLength: MemoryLayout<HPIFormat.DirectoryHeader>.size,
                                               offset: offset,
                                               key: key)
        let rootHeader: HPIFormat.DirectoryHeader = rootData.withUnsafeBytes { $0.pointee }
        //print("root:   \(rootHeader)")
        
        var items = [HPIItem]()
        let entrySize = MemoryLayout<HPIFormat.EntryHeader>.size
        for entryIndex in 0..<rootHeader.numberOfEntries {
            
            let entryData = file.readAndDecryptData(ofLength: entrySize,
                                                    offset: rootHeader.entryArrayOffset + (entryIndex * UInt32(entrySize)),
                                                    key: key)
            let entry: HPIFormat.EntryHeader = entryData.withUnsafeBytes { $0.pointee }
            
            var charOffset = entry.nameOffset
            var name = String()
            string_read: while(true) {
                let charData = file.readAndDecryptData(ofLength: 1, offset: charOffset, key: key)
                let byte: UInt8 = charData.withUnsafeBytes { $0.pointee }
                let char = UnicodeScalar(byte)
                if byte != 0 { name.append(String(char)) } else { break string_read }
                charOffset += 1
            }
            //print("- \(name)")
            
            let entryOpts = HPIFormat.EntryFlags(rawValue: entry.flags)
            
            if entryOpts.contains(.directory) {
                let items2 = try loadItems(fromTAFile: file, atOffset: entry.dataOffset, withKey: key)
                items.append(.directory(name: name, items: items2))
            }
            else {
                let fileEntryData = file.readAndDecryptData(ofLength: MemoryLayout<HPIFormat.FileEntry>.size,
                                                        offset: entry.dataOffset,
                                                        key: key)
                let fileEntry: HPIFormat.FileEntry = fileEntryData.withUnsafeBytes { $0.pointee }
                
                items.append(.file(
                    name: name,
                    size: Int(fileEntry.fileSize),
                    offset: Int(fileEntry.offsetToFileData),
                    compression: HPIFormat.FileEntryCompression(rawValue: fileEntry.compressionType) ?? .none
                    ))
            }
        }
        return items
    }
    
    enum LoadError: Error {
        case failedToOpenFile
        case badHPIMarker(Int)
        case badHPIType(Int)
        case unsupportedHPIType(Int)
        case cantExtractDirectory
    }
    enum ExtractError: Error {
        case badChunkMarker(Int)
        case badCompressionType(Int)
    }
    
    public static func extract(item: HPIItem, fromFile url: URL) throws -> Data {
        
        guard case .file(let fileInfo) = item
            else { throw LoadError.cantExtractDirectory }
        
        guard let file = try? FileHandle(forReadingFrom: url)
            else { throw LoadError.failedToOpenFile }
        
        let headerData = file.readData(ofLength: MemoryLayout<HPIFormat.FileHeader>.size)
        let header: HPIFormat.FileHeader = headerData.withUnsafeBytes { $0.pointee }
        
        guard header.marker == HPIFormat.FileHeaderMarker
            else { throw LoadError.badHPIMarker(Int(header.marker)) }
        guard let hpiType = HPIFormat.FileHeaderVersion(rawValue: header.version)
            else { throw LoadError.badHPIType(Int(header.version)) }
        
        guard hpiType == .ta
            else { throw LoadError.unsupportedHPIType(Int(header.version)) }
        
        let extData = file.readData(ofLength: MemoryLayout<HPIFormat.TAExtendedHeader>.size)
        let ext: HPIFormat.TAExtendedHeader = extData.withUnsafeBytes { $0.pointee }
        let key = ext.headerKey != 0 ? ~( (ext.headerKey * 4) | (ext.headerKey >> 6) ) : 0
        
        switch fileInfo.compression {
            
        case .none:
            let data = file.readAndDecryptData(ofLength: fileInfo.size,
                                               offset: UInt32(fileInfo.offset),
                                               key: key)
            return data
            
        case .lz77: fallthrough
        case .zlib:
            var data = Data()
            
            let chunkCount = (fileInfo.size / Int(HPIFormat.ChunkMaximumSize)) +
                ( (fileInfo.size % Int(HPIFormat.ChunkMaximumSize)) != 0 ? 1:0 )
            
            let chunkSizeData = file.readAndDecryptData(ofLength: MemoryLayout<UInt32>.size * chunkCount,
                                                        offset: UInt32(fileInfo.offset),
                                                        key: key)
            let chunkSizes = chunkSizeData.withUnsafeBytes {
                Array(UnsafeBufferPointer<UInt32>(start: $0, count: chunkCount))
            }
            var chunkOffset = UInt32(fileInfo.offset + chunkSizeData.count)
            for chunkSize in chunkSizes {
                let chunkHeaderSize = UInt32(MemoryLayout<TA_HPI_CHUNK>.size)
                let chunkHeaderData = file.readAndDecryptData(ofLength: Int(chunkHeaderSize),
                                                              offset: chunkOffset,
                                                              key: key)
                let chunkHeader: TA_HPI_CHUNK = chunkHeaderData.withUnsafeBytes { $0.pointee }
                guard chunkHeader.marker == HPIFormat.ChunkHeaderMarker
                    else { throw ExtractError.badChunkMarker(Int(chunkHeader.marker)) }
                
                var chunkData = file.readAndDecryptData(ofLength: Int(chunkSize - chunkHeaderSize),
                                                              offset: chunkOffset + chunkHeaderSize,
                                                              key: key)
                
                if chunkHeader.encryptionFlag != 0 {
                    for index in 0..<Int(chunkHeader.compressedSize) {
                        let x = UInt8(truncatingBitPattern: index)
                        chunkData[index] = (chunkData[index] &- x) ^ x
                    }
                }
                
                if let compression = HPIFormat.ChunckCompression(rawValue: chunkHeader.compressionType) {
                    switch compression {
                    case .none:
                        print("chunk uses no compression")
                        data.append(chunkData)
                    case .lz77:
                        print("chunk uses LZ77 compression")
                        let outBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(chunkHeader.decompressedSize))
                        let outSize = chunkData.withUnsafeBytes { hpi_decompress_LZ77($0, outBytes) }
                        data.append(outBytes, count: Int(outSize))
                        outBytes.deallocate(capacity: Int(chunkHeader.decompressedSize))
                    case .zlib:
                        print("chunk uses ZLib compression")
                        let outBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(chunkHeader.decompressedSize))
                        let outSize = chunkData.withUnsafeBytes { hpi_decompress_ZLib($0, outBytes, chunkHeader.compressedSize, chunkHeader.decompressedSize) }
                        data.append(outBytes, count: Int(outSize))
                        outBytes.deallocate(capacity: Int(chunkHeader.decompressedSize))
                    }
                }
                else {
                    throw ExtractError.badCompressionType(Int(chunkHeader.compressionType))
                }
                
                chunkOffset += chunkSize
            }
            
            return data
        }
    }
}

fileprivate extension Data {
    
    func decompressLZ77() -> Data {
        
//        int x;
//        int work1;
//        int work2;
//        int work3;
//        int inptr;
//        int outptr;
//        int count;
//        int done;
//        char DBuff[4096];
//        int DPtr;
        
        var done = false
        
        var work1 = 1
        var work2 = 1
        var work3 = Int(self[0])
        var inptr = 1
        var out = Data()
        
        var DBuff = Array<UInt8>(repeating: 0, count: 4096)
        
        while !done {
            if (work2 & work3) == 0 {
                out.append(self[inptr])
                DBuff[work1] = self[inptr]
                work1 = (work1 + 1) & 0xFFF
                inptr += 1
            }
            else {
                var count: UInt16 = self.withUnsafeBytes { ($0 + inptr).pointee }
                inptr += 2
                var DPtr = Int(count >> 4)
                if DPtr == 0 {
                    return out
                }
                else {
                    count = (count & 0x0F) + 2
                    if count >= 0 {
                        for _ in 0..<count {
                            out.append(DBuff[DPtr])
                            DBuff[work1] = DBuff[DPtr]
                            DPtr = (DPtr + 1) & 0xFFF
                            work1 = (work1 + 1) & 0xFFF
                        }
                        
                    }
                }
            }
            work2 *= 2
            if (work2 & 0x0100) != 0 {
                work2 = 1
                work3 = Int(self[inptr])
                inptr += 1
            }
        }
        
        return out
    }
    
    func decompressZLIB() -> Data {
        return self
    }
}
