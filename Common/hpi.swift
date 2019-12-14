//
//  HPI.swift
//  HPIView
//
//  Created by Logan Jones on 9/12/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation
#if canImport(Ctypes)
import Ctypes
#endif
#if canImport(Czlib)
import Czlib
#endif

public enum HpiFormat {
    
    public enum HpiVersion: UInt32 {
        
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
    
    struct EntryFlags: OptionSet {
        let rawValue: UInt8
        static let directory = EntryFlags(rawValue: 1 << 0)
    }
    
    enum FileEntryCompression: UInt8 {
        
        /// Compression flag indicating that the file data is not compressed.
        case none = 0
        
        /// Compression flag indicating that the file data is compressed using LZ77 compression.
        case lz77 = 1
        
        /// Compression flag indicating that the file data is compressed using ZLIB compression.
        case zlib = 2
    }
    
    enum ChunckCompression: UInt8 {
        
        /// Compression flag indicating that the chunk data is not compressed.
        case none = 0
        
        /// Compression flag indicating that the chunk data is compressed using LZ77 compression.
        case lz77 = 1
        
        /// Compression flag indicating that the chunk data is compressed using ZLIB compression.
        case zlib = 2
    }
    
}

/**
 An HPI archive can be represented as a recursive collection of `HpiItem`.
 A single item can be either a `File` or a `Directory`.
 - A `File` is a leaf item and can be extracted from the archive.
 - A `Directory` is a listing of more `HpiItem`.
 */
enum HpiItem {
    
    /// A file contained in an HPI archive.
    case file(File)
    
    /// A (sub)directory listing in an HPI archive.
    case directory(Directory)
    
    /**
     Metadata for a specific `File` contained in an HPI archive.
     The `File` entry can be used to fully `extract()` the file's data from the archive.
     */
    struct File {
        var name: String
        var size: Int
        fileprivate var offset: Int
        fileprivate var compression: HpiFormat.FileEntryCompression
        fileprivate var compressedSize: Int
    }
    
    /**
     A listing of contained HpiItems.
     These may be Files or more Directories.
     */
    struct Directory {
        var name: String
        var items: [HpiItem]
    }
}

extension HpiItem {

    /**
     Every `HpiItem` has a name.
     This name uniquely identifies the item in its containing `Directory`.
     */
    var name: String {
        switch self {
        case .file(let file): return file.name
        case .directory(let directory): return directory.name
        }
    }
    
}

extension HpiItem {
    
    /**
     Parse & load an HPI archive into a heirarchical set of HPIItems.
     - parameter hpiURL: Location of the HPI file to read.
                         After a successful load, you will need this URL again
                         to extract individual files from the HPI archive.
     - returns: The root directory loaded from the HPI archive.
     */
    public static func loadFromArchive(contentsOf hpiURL: URL) throws -> HpiItem.Directory {
        
        let hpiFile = try FileHandle(forReadingFrom: hpiURL)
        let header = hpiFile.readValue(ofType: TA_HPI_HEADER.self)
        
        guard header.marker == TA_HPI_MARKER
            else { throw LoadError.badHpiMarker(Int(header.marker)) }
        guard let hpiType = HpiFormat.HpiVersion(rawValue: header.version)
            else { throw LoadError.badHpiType(Int(header.version)) }
        
        switch hpiType {
        case .ta: return try loadFromTaArchive(file: hpiFile)
        case .tak: return try loadFromTakArchive(file: hpiFile)
        case .savegame: throw LoadError.unsupportedHpiType(Int(header.version))
        }
        
    }
    
    /**
     Extracts a single file from an HPI archive and returns its contents.
     - parameter fileInfo: Metadata of the specific file to extract.
                           This should have been obtained via the result of a `loadFromArchive()` call.
     - parameter hpiURL: Location of the HPI archive's file to read and extract from.
     - returns: The data contents of the extracted file.
     */
    public static func extract(file fileInfo: File, fromHPI hpiURL: URL) throws -> Data {
        
        let hpiFile = try FileHandle(forReadingFrom: hpiURL)
        let header = hpiFile.readValue(ofType: TA_HPI_HEADER.self)
        
        guard header.marker == TA_HPI_MARKER
            else { throw LoadError.badHpiMarker(Int(header.marker)) }
        guard let hpiType = HpiFormat.HpiVersion(rawValue: header.version)
            else { throw LoadError.badHpiType(Int(header.version)) }
        
        switch hpiType {
        case .ta: return try extract(taFile: fileInfo, fromHpi: hpiFile)
        case .tak: return try extract(takFile: fileInfo, fromHpi: hpiFile)
        default: throw LoadError.unsupportedHpiType(Int(header.version))
        }
        
    }
    
    enum LoadError: Error {
        case badHpiMarker(Int)
        case badHpiType(Int)
        case unsupportedHpiType(Int)
    }
    enum ExtractError: Error {
        case badChunkMarker(Int)
        case badCompressionType(Int)
    }
}

extension HpiItem.File {
    
    func hasExtension(_ ext: String) -> Bool {
        return (name as NSString).pathExtension.caseInsensitiveCompare(ext) == .orderedSame
    }
    
    var baseName: String {
        return (name as NSString).deletingPathExtension
    }
    
}

// MARK: - Total Annihilation

extension HpiItem {
    
    /**
     Parse & load a Total Annihilation HPI filesystem into a heirarchical set of HPIItems.
     */
    fileprivate static func loadFromTaArchive(file: FileHandle) throws -> HpiItem.Directory {
        
        let ext = file.readValue(ofType: TA_HPI_EXT_HEADER.self)
        
        // The headerKey is non-zero then this entire HPI file (other than the header, of course)
        // is enctrypted with a simple key. This keyiteslf must be decoded with some simple bit shifting.
        let archiveKey = ext.headerKey != 0 ? ~( (ext.headerKey * 4) | (ext.headerKey >> 6) ) : 0
        
        // Read the entire filesystem directory into memory.
        // Every bit of metadata about the filesystem should be within this data blob;
        // everyting remaining in the HPI file is chunked (and optionally compressed) file conetent.
        let fsData = file.readAndDecryptData(ofLength: Int(ext.directorySize),
                                             offset: ext.offsetToDirectory,
                                             key: archiveKey)
        
        // Parse the contents of the filesystem directory by recursively iterating
        // over its contents with `loadDirectory()`. We start with the root directory
        // which should be the first item at to beginning of the filesystem directory.
        return try fsData.withUnsafeBytes { (buffer) throws -> HpiItem.Directory in
            let fileSystem = OffsetBuffer(buffer: buffer, offset: Int(ext.offsetToDirectory))
            let rootItems = try HpiItem.loadDirectoryItems(atOffset: ext.offsetToDirectory, in: fileSystem)
            return Directory(name: "", items: rootItems)
        }
    }
    
    /**
     A convenience structure that represents the filesystem directory in memory.
     `loadDirectory()` uses this to seek around the filesystem directory and bind
     various HPI structures.
     
     We could just use a `UnsafeRawBufferPointer` but every offset needs to be
     subtracted by `offsetToDirectory`. This struct is a wrapper that does
     just that.
     */
    private struct OffsetBuffer {
        var buffer: UnsafeRawBufferPointer
        var offset: Int
        
        @inlinable func load<T>(fromByteOffset offset: UInt32, as type: T.Type) -> T {
            return buffer.load(fromByteOffset: Int(offset) - self.offset, as: type)
        }
        
        @inlinable func bindMemory<T>(atByteOffset offset: UInt32, count: UInt32, to type: T.Type) -> UnsafeBufferPointer<T> {
            return buffer.bindMemory(atByteOffset: Int(offset) - self.offset, count: Int(count), to: type)
        }
        
        @inlinable func loadCString(fromByteOffset offset: UInt32) -> String {
            return buffer.loadCString(fromByteOffset: Int(offset) - self.offset)
        }
    }
    
    /**
     This is the recursive workhorse of the loading code.
     `loadDirectoryItems()` is called repeatedly for each directory in the HPI's filesystem.
     */
    private static func loadDirectoryItems(atOffset offset: UInt32, in fileSystem: OffsetBuffer) throws -> [HpiItem] {
        
        let header = fileSystem.load(fromByteOffset: offset, as: TA_HPI_DIR_HEADER.self)
        let entries = fileSystem.bindMemory(atByteOffset: header.offsetToEntryArray, count: header.numberOfEntries, to: TA_HPI_ENTRY.self)
        
        // Map each header entry of this directory into an HPIItem.
        return try entries.map({ (entry) throws -> HpiItem in
            
            let name = fileSystem.loadCString(fromByteOffset: entry.offsetToName)
            let flags = HpiFormat.EntryFlags(rawValue: entry.entryFlag)
            
            // An entry is either a subdirectory or a file.
            if flags.contains(.directory) {
                // A subdirectory recursively loads its children with loadDirectory()
                let children = try loadDirectoryItems(atOffset: entry.offsetToEntryData, in: fileSystem)
                return .directory(Directory(name: name, items: children))
            }
            else {
                // A file is just a collection of properties; and can be returned immediately.
                let file = fileSystem.load(fromByteOffset: entry.offsetToEntryData, as: TA_HPI_FILE_ENTRY.self)
                return .file(File(
                    name: name,
                    size: Int(file.fileSize),
                    offset: Int(file.offsetToFileData),
                    compression: HpiFormat.FileEntryCompression(rawValue: file.compressionType) ?? .none,
                    compressedSize: 0
                ))
            }
            
        })
    }
    
    fileprivate static func extract(taFile fileInfo: File, fromHpi hpiFile: FileHandle) throws -> Data {
        
        let ext = hpiFile.readValue(ofType: TA_HPI_EXT_HEADER.self)
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
            
            let chunkCount = (fileInfo.size / Int(TA_HPI_CHUNK_DEFAULT_SIZE)) +
                ( (fileInfo.size % Int(TA_HPI_CHUNK_DEFAULT_SIZE)) != 0 ? 1:0 )
            
            let chunkSizeData = hpiFile.readAndDecryptData(ofLength: MemoryLayout<UInt32>.size * chunkCount,
                                                           offset: UInt32(fileInfo.offset),
                                                           key: key)
            
            var chunkOffset = UInt32(fileInfo.offset + chunkSizeData.count)
            
            try chunkSizeData.withUnsafeBytes { (buffer) in
                let chunkSizes = buffer.bindMemory(to: UInt32.self)
                for chunkSize in chunkSizes {
                    let chunkData = hpiFile.readAndDecryptData(ofLength: Int(chunkSize),
                                                               offset: chunkOffset,
                                                               key: key)
                    let decompressed = try deSqsh(chunk: chunkData)
                    data.append(decompressed)
                    chunkOffset += chunkSize
                }
            }
            
            return data
        }
    }
    
}

private extension FileHandle {
    
    func readAndDecryptData(ofLength size: Int, offset: UInt32, key: Int32) -> Data {
        seek(toFileOffset: offset)
        var data = readData(ofLength: size)
        if data.count < size { print("read less data than requested! (wanted \(size) bytes, read \(data.count) bytes)") }
        let koffset = Int32(offset)
        if key != 0 {
            for index in 0..<data.count {
                let tkey = (koffset &+ Int32(index)) ^ key
                let inv = Int32(~data[index])
                data[index] = UInt8(truncatingIfNeeded: tkey ^ inv)
            }
        }
        return data
    }
    
    func readAndDecryptValue<T>(ofType type: T.Type, offset: UInt32, key: Int32) -> T {
        let data = readAndDecryptData(ofLength: MemoryLayout<T>.size, offset: offset, key: key)
        return data.withUnsafeBytes { (buffer) -> T in buffer.load(as: type) }
    }
    
}

// MARK: - Total Annihilation: Kingdoms

extension HpiItem {
    
    /**
     Parse & load a Total Annihilation: Kingdoms HPI filesystem into a heirarchical set of HPIItems.
     */
    fileprivate static func loadFromTakArchive(file: FileHandle) throws -> HpiItem.Directory {
    
        let ext = file.readValue(ofType: TAK_HPI_EXT_HEADER.self)
        
        file.seek(toFileOffset: ext.offsetToDirectory)
        let rawFsData = file.readData(ofLength: ext.directorySize)
        let fsData = HpiItem.isSqsh(chunk: rawFsData) ? try HpiItem.deSqsh(chunk: rawFsData) : rawFsData
        
        file.seek(toFileOffset: ext.offsetToFileNames)
        let rawNamesData = file.readData(ofLength: ext.fileNameSize)
        let namesData = HpiItem.isSqsh(chunk: rawNamesData) ? try HpiItem.deSqsh(chunk: rawNamesData) : rawNamesData
        
        let rootItems = try fsData.withUnsafeBytes { (fs) throws -> [HpiItem] in
            return try namesData.withUnsafeBytes { (names) throws -> [HpiItem] in
                return try HpiItem.loadTakDirectoryItems(atOffset: 0, in: fs, with: names)
            }
        }
        
        return Directory(name: "", items: rootItems)
    }
    
    private static func loadTakDirectoryItems(atOffset offset: Int,
                                              in fileSystem: UnsafeRawBufferPointer,
                                              with names: UnsafeRawBufferPointer) throws -> [HpiItem] {
        
        let header = fileSystem.load(fromByteOffset: offset, as: TAK_HPI_DIR_ENTRY.self)
        
        let files: [HpiItem]
        if header.numberOfFileEntries > 0 {
            files = try fileSystem
                .bindMemory(atByteOffset: Int(header.offsetToFileEntryArray), count: Int(header.numberOfFileEntries), to: TAK_HPI_FILE_ENTRY.self)
                .map { (file: TAK_HPI_FILE_ENTRY) throws -> HpiItem in
                    .file(File(
                        name: names.loadCString(fromByteOffset: Int(file.offsetToFileName)),
                        size: Int(file.decompressedSize),
                        offset: Int(file.offsetToFileData),
                        compression: file.compressedSize == 0 ? .none : .zlib,
                        compressedSize: Int(file.compressedSize)
                    ))
            }
        }
        else {
            files = []
        }
        
        var subdirectories: [HpiItem] = []
        var subOffset = Int(header.offsetToSubDirectoryArray)
        for _ in 0..<header.numberOfSubDirectories {
            let subheader = fileSystem.load(fromByteOffset: subOffset, as: TAK_HPI_DIR_ENTRY.self)
            let name = names.loadCString(fromByteOffset: Int(subheader.offsetToDirectoryName))
            let children = try loadTakDirectoryItems(atOffset: subOffset, in: fileSystem, with: names)
            subdirectories.append(.directory(Directory(name: name, items: children)))
            subOffset += MemoryLayout<TAK_HPI_DIR_ENTRY>.stride
        }
        
        return subdirectories + files
    }
    
    fileprivate static func extract(takFile fileInfo: File, fromHpi hpiFile: FileHandle) throws -> Data {
        switch fileInfo.compression {
            
        case .none:
            hpiFile.seek(toFileOffset: fileInfo.offset)
            return hpiFile.readData(ofLength: fileInfo.size)
            
        case .lz77: fallthrough
        case .zlib:
            hpiFile.seek(toFileOffset: fileInfo.offset)
            let chunkData = hpiFile.readData(ofLength: fileInfo.compressedSize)
            return try deSqsh(chunk: chunkData)
        }
    }
    
}

// MARK: - Chunk Decompression

extension HpiItem {
    
    fileprivate static func isSqsh(chunk rawData: Data) -> Bool {
        return rawData.withUnsafeBytes { (buffer) -> Bool in
            return buffer.load(as: TA_HPI_CHUNK.self).marker == TA_HPI_CHUNK_MARKER
        }
    }
    
    fileprivate static func deSqsh(chunk rawData: Data) throws -> Data {
        return try rawData.withUnsafeBytes { (buffer) throws -> Data in
            let chunkHeader = buffer.load(as: TA_HPI_CHUNK.self)
            guard chunkHeader.marker == TA_HPI_CHUNK_MARKER
                else { throw ExtractError.badChunkMarker(Int(chunkHeader.marker)) }
            guard let compression = HpiFormat.ChunckCompression(rawValue: chunkHeader.compressionType)
                else { throw ExtractError.badCompressionType(Int(chunkHeader.compressionType)) }
            
            if chunkHeader.encryptionFlag == 0 && compression == .none {
                let start = MemoryLayout<TA_HPI_CHUNK>.size
                let end = start + Int(chunkHeader.decompressedSize)
                return rawData.subdata(in: start..<end)
            }
            
            var chunkData = UnsafeRawBufferPointer(rebasing: buffer[MemoryLayout<TA_HPI_CHUNK>.size...])
            let compressedSize = Int(chunkHeader.compressedSize)
            
            var toRealease: UnsafeMutableRawBufferPointer? = nil
            defer { if let r = toRealease { r.deallocate() } }
            
            if chunkHeader.encryptionFlag != 0 {
                let enecrypted = chunkData
                let decrypted = UnsafeMutableRawBufferPointer.allocate(byteCount: compressedSize, alignment: 1)
                for index in 0..<compressedSize {
                    let x = UInt8(truncatingIfNeeded: index)
                    decrypted[index] = (enecrypted[index] &- x) ^ x
                }
                chunkData = UnsafeRawBufferPointer(decrypted)
                toRealease = decrypted
            }
            
            switch compression {
            case .none: return Data(chunkData[..<Int(chunkHeader.decompressedSize)])
            case .lz77: return decompressLZ77(bytes: chunkData, decompressedSize: Int(chunkHeader.decompressedSize))
            case .zlib: return decompressZLib(bytes: chunkData, compressedSize: compressedSize, decompressedSize: Int(chunkHeader.decompressedSize))
            }
        }
    }
    
}

/**
 Decompresses the input bytes using the LZ77 algorithm.
 
 This bit of code could use some inspection. It's been copied around and translated so many times;
 I don't even know the original source.
 */
private func decompressLZ77(bytes _in: UnsafeRawBufferPointer, decompressedSize: Int) -> Data {
    
    var outptr = 0
    let out = UnsafeMutableRawBufferPointer.allocate(byteCount: decompressedSize, alignment: 1)
    defer { out.deallocate() }
    
    let DBuff = UnsafeMutableRawBufferPointer.allocate(byteCount: 4096, alignment: 1)
    defer { DBuff.deallocate() }
        
    var work1 = 1
    var work2 = 1
    var work3 = Int(_in[0])
    var inptr = 1
    
    loop: while true {
        if (work2 & work3) == 0 {
            out[outptr] = _in[inptr]
            DBuff[work1] = _in[inptr]
            work1 = (work1 + 1) & 0xFFF
            inptr += 1
            outptr += 1
        }
        else {
            let byte1 = _in[inptr + 0]
            let byte2 = _in[inptr + 1]
            var count = (UInt16(byte2) << 8) | UInt16(byte1)
            inptr += 2
            var DPtr = Int(count >> 4)
            if DPtr == 0 {
                break loop
            }
            else {
                count = (count & 0x0F) + 2
                if count >= 0 {
                    for _ in 0..<count {
                        out[outptr] = DBuff[DPtr]
                        DBuff[work1] = DBuff[DPtr]
                        DPtr = (DPtr + 1) & 0xFFF
                        work1 = (work1 + 1) & 0xFFF
                        outptr += 1
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
    
    return Data(out[..<outptr])
}

/**
 Decompresses the input bytes using ZLib deflate.
 */
private func decompressZLib(bytes _in: UnsafeRawBufferPointer, compressedSize: Int, decompressedSize: Int) -> Data {
    
    let out = UnsafeMutablePointer<UInt8>.allocate(capacity: decompressedSize)
    defer { out.deallocate() }
    
    var zs = z_stream(
        next_in: UnsafeMutablePointer(mutating: _in.bindMemory(to: UInt8.self).baseAddress!),
        avail_in: uInt(compressedSize),
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
        return Data()
    }
    
    if inflate(&zs, Z_FINISH) != Z_STREAM_END {
        zs.total_out = 0
    }
    
    if inflateEnd(&zs) != Z_OK {
        return Data()
    }
    
    return Data(bytes: out, count: Int(zs.total_out))
}
