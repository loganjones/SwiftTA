//
//  Utility.swift
//  HPIView
//
//  Created by Logan Jones on 12/30/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Foundation

// MARK:- File Read Helpers

extension FileHandle {
    func readData<T>(ofType type: T.Type) -> Data {
        return readData(ofLength: MemoryLayout<T>.size)
    }
    func readData<T>(ofType type: T.Type, count: Int) -> Data {
        return readData(ofLength: MemoryLayout<T>.size * count)
    }
    func readValue<T>(ofType type: T.Type) -> T {
        let data = readData(ofLength: MemoryLayout<T>.size)
        return data.withUnsafeBytes { $0.pointee }
    }
    func readArray<T>(ofType type: T.Type, count: Int) -> [T] {
        let data = readData(ofLength: MemoryLayout<T>.size * count)
        return data.withUnsafeBytes { (p: UnsafePointer<UInt8>) -> [T] in
            let buffer = UnsafeBufferPointer<T>(rebinding: p, capacity: count)
            return Array(buffer)
        }
    }
    @nonobjc func seek(toFileOffset offset: UInt32) {
        seek(toFileOffset: UInt64(offset))
    }
    @nonobjc func seek(toFileOffset offset: Int) {
        seek(toFileOffset: UInt64(offset))
    }
}

// MARK:- Memory Extensions

extension UnsafePointer {
    init<T>(rebinding p: UnsafePointer<T>) {
        let raw = UnsafeRawPointer(p)
        self.init(raw.assumingMemoryBound(to: Pointee.self))
    }
}

extension UnsafeBufferPointer {
    init<T>(rebinding p: UnsafePointer<T>, capacity count: Int) {
        let raw = UnsafeRawPointer(p)
        let rebound = raw.assumingMemoryBound(to: Element.self)
        self.init(start: rebound, count: count)
    }
}

extension UnsafeRawPointer {
    public func bindMemoryBuffer<T>(to type: T.Type, capacity count: Int) -> UnsafeBufferPointer<T> {
        let p = self.bindMemory(to: type, capacity: count)
        return UnsafeBufferPointer<T>(start: p, count: count)
    }
}

public func +<Pointee>(lhs: UnsafePointer<Pointee>, rhs: UInt32) -> UnsafePointer<Pointee> {
    return lhs + Int(rhs)
}

// MARK:- Array Helpers

extension Array {
    public subscript(index: UInt16) -> Element { return self[Int(index)] }
}
