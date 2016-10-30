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
        var marker: Int32

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
    
    struct ChunckCompressionTypes: OptionSet {
        let rawValue: UInt8
        
        /// Compression flag indicating that the chunk data is compressed using
        /// LZ77 compression.
        static let lz77 = ChunckCompressionTypes(rawValue: 1 << 0)
        
        /// Compression flag indicating that the chunk data is compressed using
        /// ZLIB compression.
        static let zlib = ChunckCompressionTypes(rawValue: 1 << 1)
    }
    
    /// The default chunk size for when a Total Annihilation file is split up
    /// into many chunks.
    public static let ChunkMaximumSize: UInt32 = 65536
    
    static func testRead(url: URL) {
        
        guard let file = try? FileHandle(forReadingFrom: url)
            else { return }
        
        let headerData = file.readData(ofLength: MemoryLayout<FileHeader>.size)
        let header: FileHeader = headerData.withUnsafeBytes { $0.pointee }
        
        let extData = file.readData(ofLength: MemoryLayout<TAExtendedHeader>.size)
        let ext: TAExtendedHeader = extData.withUnsafeBytes { $0.pointee }
        print("header: \(header)")
        print("ext:    \(ext)")
        
        let key = ~( (ext.headerKey * 4) | (ext.headerKey >> 6) )

        let rootData = file.readAndDecryptData(ofLength: MemoryLayout<DirectoryHeader>.size,
                                               offset: ext.directoryOffset,
                                               key: key)
        let rootHeader: DirectoryHeader = rootData.withUnsafeBytes { $0.pointee }
        print("root:   \(rootHeader)")

        let entrySize = MemoryLayout<EntryHeader>.size
        for entryIndex in 0..<rootHeader.numberOfEntries {
            
            let entryData = file.readAndDecryptData(ofLength: entrySize,
                                                    offset: rootHeader.entryArrayOffset + (entryIndex * UInt32(entrySize)),
                                                    key: key)
            let entry: EntryHeader = entryData.withUnsafeBytes { $0.pointee }
            
            var charOffset = entry.nameOffset
            var name = String()
            string_read: while(true) {
                let charData = file.readAndDecryptData(ofLength: 1, offset: charOffset, key: key)
                let byte: UInt8 = charData.withUnsafeBytes { $0.pointee }
                let char = UnicodeScalar(byte)
                if byte != 0 { name.append(String(char)) } else { break string_read }
                charOffset += 1
            }
            print("- \(name)")
        }
    }
    
}

extension FileHandle {
    
    func readAndDecryptData(ofLength size: Int, offset: UInt32, key: Int32) -> Data {
        seek(toFileOffset: UInt64(offset))
        var data = readData(ofLength: size)
        let koffset = Int32(offset)
        for index in 0..<size {
            let tkey = (koffset + index) ^ key
            let inv = Int32(~data[index])
            data[index] = UInt8(truncatingBitPattern: tkey ^ inv)
        }
        return data
    }
    
}

enum HPIItem {
    case file(name: String, size: Int, offset: Int, compression: HPIFormat.FileEntryCompression)
    indirect case directory(name: String, items: [HPIItem])
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
        case .tak: throw LoadError.badHPIType(Int(header.version))
        case .savegame: throw LoadError.badHPIType(Int(header.version))
        }
        
    }
    
    private init(withTAFile file: FileHandle) throws {
        let extData = file.readData(ofLength: MemoryLayout<HPIFormat.TAExtendedHeader>.size)
        let ext: HPIFormat.TAExtendedHeader = extData.withUnsafeBytes { $0.pointee }
        let key = ~( (ext.headerKey * 4) | (ext.headerKey >> 6) )
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
    }
}
