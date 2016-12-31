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
        seek(toFileOffset: offset)
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
    
    func readAndDecryptValue<T>(ofType type: T.Type, offset: UInt32, key: Int32) -> T {
        let data = readAndDecryptData(ofLength: MemoryLayout<T>.size, offset: offset, key: key)
        return data.withUnsafeBytes { $0.pointee }
    }
    
}

/// An HPI archive can be represented as a recursive collection of HPIItems.
/// A single item can be either a File or a Directory.
/// A File is a leaf item and can be extracted from the archive.
/// A Directory is a listing of more HPIItems.
enum HPIItem {
    
    /// A file contained in an HPI archive.
    case file(File)
    
    /// A (sub)directory listing in an HPI archive.
    indirect case directory(Directory)
    
    /// Metadata for a specific File contained in an HPI archive.
    /// The File entry can be used to fully extract the file's data from the archive.
    struct File {
        var name: String
        var size: Int
        var offset: Int
        var compression: HPIFormat.FileEntryCompression
    }
    
    /// A listing of contained HPIItems.
    /// These may be Files or more Directories.
    struct Directory {
        var name: String
        var items: [HPIItem]
    }
}

extension HPIItem {
    
    /// Every HPIItem has a name.
    /// This name uniquely identifies the item in its containing Directory.
    var name: String {
        switch self {
        case .file(let file): return file.name
        case .directory(let directory): return directory.name
        }
    }
    
}

extension HPIItem {
    
    /// Parse & load an HPI archive into a heirarchical set of HPIItems.
    init(withContentsOf url: URL) throws {
        
        guard let file = try? FileHandle(forReadingFrom: url)
            else { throw LoadError.failedToOpenHPI }
        
        let header = file.readValue(ofType: HPIFormat.FileHeader.self)
        
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
    
    /// Parse & load a Total Annihilation HPI file-system into a heirarchical set of HPIItems.
    private init(withTAFile file: FileHandle) throws {
        
        let ext = file.readValue(ofType: HPIFormat.TAExtendedHeader.self)
        
        // The headerKey is non-zero then this entire HPI file (other than the header, of course)
        // is enctrypted with a simple key. This keyiteslf must be decoded with some simple bit shifting.
        let archiveKey = ext.headerKey != 0 ? ~( (ext.headerKey * 4) | (ext.headerKey >> 6) ) : 0
        
        // Read the entire file-system directory into memory.
        // Every bit of meta-data about the filesystem should be within this data blob;
        // everyting remaining in the HPI file is chunked (and optionally compressed) file conetent.
        let fsData = file.readAndDecryptData(ofLength: Int(ext.directorySize),
                                             offset: ext.directoryOffset,
                                             key: archiveKey)
        
        // Parse the contents of the file-system directory by recursively iterating
        // over its contents with loadDirectory(). We start with the root directory
        // which should be the first item at to beginning of the file-system directory.
        self = try fsData.withUnsafeBytes { (p: UnsafePointer<UInt8>) throws -> HPIItem in
            let fileSystem = FileSystem(memory: p, offset: ext.directoryOffset)
            let rootItems = try HPIItem.loadDirectoryItems(atOffset: ext.directoryOffset, in: fileSystem)
            return .directory(Directory(name: "", items: rootItems))
        }
    }
    
    /// A convenience structure that represents the file-system directory in memory.
    /// loadDirectory() uses this to seek around the file-system directory and bind
    /// various HPI structures.
    private struct FileSystem {
        var memory: UnsafePointer<UInt8>
        var offset: UInt32
        func at(_ offset: UInt32) -> UnsafePointer<UInt8> {
            return memory + (Int(offset) - Int(self.offset))
        }
        func rawMemory(at offset: UInt32) -> UnsafeRawPointer {
            return UnsafeRawPointer(memory + (Int(offset) - Int(self.offset)))
        }
        /// Bind a single instance of T structure in memory.
        func bindMemory<T>(to type: T.Type, at offset: UInt32) -> UnsafePointer<T> {
            return UnsafeRawPointer(memory + (Int(offset) - Int(self.offset))).bindMemory(to: type, capacity: 1)
        }
        /// Bind a sequence of T structures in memory.
        public func bindMemoryBuffer<T>(to type: T.Type, capacity count: UInt32, at offset: UInt32) -> UnsafeBufferPointer<T> {
            let raw = UnsafeRawPointer(memory + (Int(offset) - Int(self.offset)))
            let p = raw.bindMemory(to: type, capacity: Int(count))
            return UnsafeBufferPointer<T>(start: p, count: Int(count))
        }
    }
    
    private static func loadDirectoryItems(atOffset offset: UInt32, in fileSystem: FileSystem) throws -> [HPIItem] {
        
        let header = fileSystem.bindMemory(to: HPIFormat.DirectoryHeader.self, at: offset).pointee
        let entries = fileSystem.bindMemoryBuffer(to: TA_HPI_ENTRY.self,
                                                  capacity: header.numberOfEntries,
                                                  at: header.entryArrayOffset)
        
        // Map each header entry of this directory into an HPIItem.
        return try entries.map({ (entry) throws -> HPIItem in
            
            let name = String(cString: fileSystem.at(entry.offsetToName))
            let flags = HPIFormat.EntryFlags(rawValue: entry.entryFlag)
            
            // An entry is either a subdirectory or a file.
            if flags.contains(.directory) {
                // A subdirectory recursively loads its children with loadDirectory()
                let children = try loadDirectoryItems(atOffset: entry.offsetToEntryData, in: fileSystem)
                return .directory(Directory(name: name, items: children))
            }
            else {
                // A file is just a collection of properties; and can be returned immediately.
                let file = fileSystem.bindMemory(to: HPIFormat.FileEntry.self, at: entry.offsetToEntryData).pointee
                return .file(File(
                    name: name,
                    size: Int(file.fileSize),
                    offset: Int(file.offsetToFileData),
                    compression: HPIFormat.FileEntryCompression(rawValue: file.compressionType) ?? .none
                ))
            }
            
        })
    }
    
    enum LoadError: Error {
        case failedToOpenHPI
        case badHPIMarker(Int)
        case badHPIType(Int)
        case unsupportedHPIType(Int)
        case cantExtractDirectory
    }
    enum ExtractError: Error {
        case badChunkMarker(Int)
        case badCompressionType(Int)
    }
    
    public static func extract(file fileInfo: File, fromHPI hpiURL: URL) throws -> Data {
        
        guard let hpiFile = try? FileHandle(forReadingFrom: hpiURL)
            else { throw LoadError.failedToOpenHPI }
        
        let header = hpiFile.readValue(ofType: HPIFormat.FileHeader.self)
        
        guard header.marker == HPIFormat.FileHeaderMarker
            else { throw LoadError.badHPIMarker(Int(header.marker)) }
        guard let hpiType = HPIFormat.FileHeaderVersion(rawValue: header.version)
            else { throw LoadError.badHPIType(Int(header.version)) }
        
        guard hpiType == .ta
            else { throw LoadError.unsupportedHPIType(Int(header.version)) }
        
        let ext = hpiFile.readValue(ofType: HPIFormat.TAExtendedHeader.self)
        let key = ext.headerKey != 0 ? ~( (ext.headerKey * 4) | (ext.headerKey >> 6) ) : 0
        
        switch fileInfo.compression {
            
        case .none:
            let data = hpiFile.readAndDecryptData(ofLength: fileInfo.size,
                                                  offset: UInt32(fileInfo.offset),
                                                  key: key)
            return data
            
        case .lz77: fallthrough
        case .zlib:
            var data = Data()
            
            let chunkCount = (fileInfo.size / Int(HPIFormat.ChunkMaximumSize)) +
                ( (fileInfo.size % Int(HPIFormat.ChunkMaximumSize)) != 0 ? 1:0 )
            
            let chunkSizeData = hpiFile.readAndDecryptData(ofLength: MemoryLayout<UInt32>.size * chunkCount,
                                                           offset: UInt32(fileInfo.offset),
                                                           key: key)
            let chunkSizes = chunkSizeData.withUnsafeBytes {
                Array(UnsafeBufferPointer<UInt32>(start: $0, count: chunkCount))
            }
            var chunkOffset = UInt32(fileInfo.offset + chunkSizeData.count)
            for chunkSize in chunkSizes {
                let chunkHeader = hpiFile.readAndDecryptValue(ofType: TA_HPI_CHUNK.self,
                                                              offset: chunkOffset,
                                                              key: key)
                guard chunkHeader.marker == HPIFormat.ChunkHeaderMarker
                    else { throw ExtractError.badChunkMarker(Int(chunkHeader.marker)) }
                
                let chunkHeaderSize = UInt32(MemoryLayout.size(ofValue: chunkHeader))
                var chunkData = hpiFile.readAndDecryptData(ofLength: Int(chunkSize - chunkHeaderSize),
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
                        data.append(chunkData)
                    case .lz77:
                        data.append(chunkData.decompressLZ77(decompressedSize: Int(chunkHeader.decompressedSize)))
                    case .zlib:
                        data.append(chunkData.decompressZLib(decompressedSize: Int(chunkHeader.decompressedSize)))
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
    
    func decompressLZ77(decompressedSize: Int? = nil) -> Data {
        
        var out = Data(capacity: decompressedSize ?? self.count)
        let DBuff = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        self.withUnsafeBytes { (_in: UnsafePointer<UInt8>) -> Void in
        
            var work1 = 1
            var work2 = 1
            var work3 = Int(_in[0])
            var inptr = 1
            
            loop: while true {
                if (work2 & work3) == 0 {
                    out.append(_in[inptr])
                    DBuff[work1] = _in[inptr]
                    work1 = (work1 + 1) & 0xFFF
                    inptr += 1
                }
                else {
                    var count = (_in + inptr).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }
                    inptr += 2
                    var DPtr = Int(count >> 4)
                    if DPtr == 0 {
                        break loop
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
                    work3 = Int(_in[inptr])
                    inptr += 1
                }
            }
        
        }
        
        return out
    }
    
    func decompressZLib(decompressedSize: Int) -> Data {
        
        let out = UnsafeMutablePointer<UInt8>.allocate(capacity: decompressedSize)
        defer { out.deallocate(capacity: decompressedSize) }
        
        let outBytesWritten = self.withUnsafeBytes { (_in: UnsafePointer<UInt8>) -> Int in
            var zs = z_stream(
                next_in: UnsafeMutablePointer(mutating: _in),
                avail_in: uInt(self.count),
                total_in: 0,
                next_out: out,
                avail_out: uInt(decompressedSize),
                total_out: 0,
                msg: nil,
                state: nil,
                zalloc: nil,
                zfree: nil,
                opaque: nil,
                data_type: Z_BINARY,
                adler: 0,
                reserved: 0)
            
            if inflateInit_(&zs, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) != Z_OK {
                return 0
            }
            
            if inflate(&zs, Z_FINISH) != Z_STREAM_END {
                zs.total_out = 0
            }
            
            if inflateEnd(&zs) != Z_OK {
                return 0
            }
            
            return Int(zs.total_out)
        }
        
        return Data(bytes: out, count: outBytesWritten)
    }
    
}
