//
//  data.swift
//  ModelView
//
//  Created by Logan Jones on 11/5/16.
//

import Foundation


extension Data {
    
    func subdata(at offset: Int) -> Data {
        return self.subdata(in: offset..<self.count)
    }
    
    func subdata(at offset: Int, length: Int) -> Data {
        return self.subdata(in: offset..<(offset+length))
    }
    
    
    func copyValue<ValueType>() -> ValueType {
        return self.withUnsafeBytes { $0.pointee }
    }
    
    func copyValue<ValueType>(of type: ValueType.Type) -> ValueType {
        return self.withUnsafeBytes { $0.pointee }
    }
    
    func copyValue<ValueType>(of type: ValueType.Type, atOffset offset: Int) -> ValueType {
        return self.withUnsafeBytes { (p0: UnsafePointer<UInt8>) -> ValueType in
            (p0 + offset).withMemoryRebound(to: type, capacity: 1) { $0.pointee }
        }
    }
    
    
    func copyCString(atOffset offset: Int) -> String {
        return self.withUnsafeBytes { (p0: UnsafePointer<UInt8>) -> String in
            String(cString: p0 + offset)
        }
    }
    
    
    func copyArray<ElementType>(of type: ElementType.Type) -> [ElementType] {
        let count = self.count / MemoryLayout<ElementType>.size
        return self.withUnsafeBytes { (p0: UnsafePointer<ElementType>) -> [ElementType] in
            Array( UnsafeBufferPointer<ElementType>(start: p0, count: count) )
        }
    }
    
    func copyArray<ElementType>(of type: ElementType.Type, count: Int) -> [ElementType] {
        return self.withUnsafeBytes { (p0: UnsafePointer<ElementType>) -> [ElementType] in
            Array( UnsafeBufferPointer<ElementType>(start: p0, count: count) )
        }
    }
    
    func copyArray<ElementType>(of type: ElementType.Type, count: Int, atOffset offset: Int) -> [ElementType] {
        return self.withUnsafeBytes { (p0: UnsafePointer<UInt8>) -> [ElementType] in
            (p0 + offset).withMemoryRebound(to: type, capacity: count) {
                Array( UnsafeBufferPointer<ElementType>(start: $0, count: count) )
            }
        }
    }
    
    
    func withUnsafeBuffer<ResultType, ElementType>(of type: ElementType.Type, count: Int, _ body: (UnsafeBufferPointer<ElementType>) throws -> ResultType) rethrows -> ResultType {
        return try self.withUnsafeBytes { (p0: UnsafePointer<ElementType>) -> ResultType in
            try body( UnsafeBufferPointer<ElementType>(start: p0, count: count) )
        }
    }
    
    func withUnsafeBuffer<ResultType, ElementType>(of type: ElementType.Type, count: Int, atOffset offset: Int, _ body: (UnsafeBufferPointer<ElementType>) throws -> ResultType) rethrows -> ResultType {
        return try self.withUnsafeBytes { (p0: UnsafePointer<UInt8>) -> ResultType in
            try (p0 + offset).withMemoryRebound(to: type, capacity: count) {
                let b = UnsafeBufferPointer<ElementType>(start: $0, count: count)
                return try body(b)
            }
        }
    }
    
    //func withUnsafeBytes<ResultType, ContentType>(_ body: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType
}


public func +<Pointee>(lhs: UnsafePointer<Pointee>, rhs: Int32) -> UnsafePointer<Pointee> {
    return lhs + Int(rhs)
}
public func +<Pointee>(lhs: UnsafePointer<Pointee>, rhs: UInt32) -> UnsafePointer<Pointee> {
    return lhs + Int(rhs)
}


extension UnsafeRawPointer {
    public func bindMemoryBuffer<T>(to type: T.Type, capacity count: Int) -> UnsafeBufferPointer<T> {
        let p = self.bindMemory(to: type, capacity: count)
        return UnsafeBufferPointer<T>(start: p, count: count)
    }
}


extension Array {
    public subscript(index: UInt16) -> Element { return self[Int(index)] }
}
