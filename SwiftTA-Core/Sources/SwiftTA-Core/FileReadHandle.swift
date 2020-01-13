//
//  FileReadHandle.swift
//  HPIView
//
//  Created by Logan Jones on 6/10/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

public protocol FileReadHandle {
    
    func readDataToEndOfFile() -> Data
    
    func readData(ofLength length: Int) -> Data
    
    func readData(verifyingLength length: Int) throws -> Data
    
    //func seekToEndOfFile() -> Int
    
    func seek(toFileOffset offset: Int)
    
    var fileName: String { get }
    
    var fileSize: Int { get }
    
    var fileOffset: Int { get }
    
}

extension FileReadHandle {
    
    func readData(verifyingLength length: Int) throws -> Data {
        let data = readData(ofLength: length)
        guard data.count == length else {
            print("ERROR: Expected to read \(length) bytes; got \(data.count) bytes. [\(fileName)]")
            throw FileReadError.unexpectedEOF
        }
        return data
    }
    
    func readData<T>(ofType type: T.Type) throws -> Data {
        return try readData(verifyingLength: MemoryLayout<T>.size)
    }
    
    func readData<T>(ofType type: T.Type, count: Int) throws -> Data {
        return try readData(verifyingLength: MemoryLayout<T>.stride * count)
    }
    
    func readValue<T>(ofType type: T.Type) throws -> T {
        let data = try readData(verifyingLength: MemoryLayout<T>.size)
        return data.withUnsafeBytes { $0.load(as: type) }
    }
    
    func readArray<T>(ofType type: T.Type, count: Int) throws -> [T] {
        let data = try readData(verifyingLength: MemoryLayout<T>.stride * count)
        return data.withUnsafeBytes { Array($0.bindMemory(to: type)) }
    }
    
    func readData(ofLength length: UInt32) -> Data {
        return readData(ofLength: Int(length))
    }
    
    func readData(verifyingLength length: UInt32) throws -> Data {
        return try readData(verifyingLength: Int(length))
    }
    
    func seek(toFileOffset offset: UInt32) {
        seek(toFileOffset: Int(offset))
    }
    
}

enum FileReadError: Swift.Error {
    case unexpectedEOF
}
