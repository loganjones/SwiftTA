//
//  TdfParser.swift
//  TAassets
//
//  Created by Logan Jones on 3/21/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation

// TODO: Support Unicode for TDF parsing.
// I tried using Character as the base type but the resulting code ran an order of magnitude slower than the withUnsafeBytes+UInt8 solution.


public class TdfParser {
    
    public init<File>(_ file: File) where File: FileReadHandle {
        self.data = file.readDataToEndOfFile()
    }
    public init(_ data: Data) {
        self.data = data
    }
    
    public enum Token: Equatable {
        case objectBegin(String)
        case objectEnd(String)
        case property(String, String)
    }
    
    fileprivate var data: Data
    fileprivate var scanPosition: Int = 0
    fileprivate var state: State = .seekingSection
    fileprivate var context = Context()
}

public extension TdfParser {
    
    var isAtEnd: Bool { return scanPosition >= data.count }
    
    var depth: Int { return context.parents.count }
    
    var currentObject: String? { return context.parents.last }
    var currentObjects: [String] { return context.parents }
    
    func nextToken() -> Token? {
        
        let count = data.count
        var token: Token?
        
        data.withUnsafeBytes() {
            while scanPosition < count && token == nil {
                (state, token) = TdfParser.transition(state, consuming: $0[scanPosition], context: &context)
                scanPosition += 1
            }
        }
        
        return token
    }
    
    @discardableResult
    func skipToObject(named: String) -> Bool {
        
        let startDepth = depth
        
        while let token = nextToken() {
            switch token {
            case .objectBegin(let section):
                if depth-1 == startDepth && section == named {
                    return true
                }
            case .objectEnd:
                if depth < startDepth {
                    return false
                }
            case .property: ()
            }
        }
        
        return false
    }
    
    @discardableResult
    func skipToNextObject() -> String? {
        
        let startDepth = depth
        
        while let token = nextToken() {
            switch token {
            case .objectBegin(let section):
                if depth-1 == startDepth {
                    return section
                }
            case .objectEnd:
                if depth < startDepth {
                    return nil
                }
            case .property: ()
            }
        }
        
        return nil
    }
    
    func skipObject() {
        guard depth > 0 else { return }
        
        let startDepth = depth
        while let token = nextToken() {
            switch token {
            case .objectBegin: ()
            case .objectEnd:
                if depth == startDepth-1 {
                    return
                }
            case .property: ()
            }
        }
    }
    
}

public extension TdfParser {
    
    func forEachProperty(perform: (_ key: String, _ value: String) -> ()) {
        
        let startDepth = depth
        let count = data.count
        var token: Token?
        
        data.withUnsafeBytes() {
            while scanPosition < count {
                (state, token) = TdfParser.transition(state, consuming: $0[scanPosition], context: &context)
                scanPosition += 1
                switch token {
                case let .property(key, value)? where depth == startDepth:
                    perform(key, value)
                case .objectEnd? where depth == startDepth-1:
                    return
                default:
                    () // ignore
                }
            }
        }
        
    }
    
    static func parse<File>(_ file: File, tokenHandler: (Token) -> () ) where File: FileReadHandle {
        let data = file.readDataToEndOfFile()
        parse(data, tokenHandler: tokenHandler)
    }
    
    static func parse(_ data: Data, tokenHandler: (Token) -> () ) {
        let count = data.count
        data.withUnsafeBytes() {
            var state = State.seekingSection
            var context = Context()
            var token: Token?
            for i in 0..<count {
                (state, token) = transition(state, consuming: $0[i], context: &context)
                if let token = token { tokenHandler(token) }
            }
        }
    }
    
}

// MARK:- Dictionary Extract

public extension TdfParser {
    
    public struct Object {
        public var properties: Dictionary<String, String>
        public var subobjects: Dictionary<String, Object>
    }
    
    func extractAll() -> Dictionary<String, Object> {
        
        let count = data.count
        var token: Token?
        
        var level = 0
        var levels: [Object] = [Object()]
        
        data.withUnsafeBytes() {
            while scanPosition < count {
                (state, token) = TdfParser.transition(state, consuming: $0[scanPosition], context: &context)
                scanPosition += 1
                guard let token = token else { continue }
                switch token {
                case .objectBegin:
                    level += 1
                    levels.append(Object())
                case let .objectEnd(name):
                    level -= 1
                    levels[level].subobjects[name] = levels.popLast() ?? Object()
                case let .property(key, value):
                    levels[level].properties[key] = value
                }
            }
        }
        
        return levels[0].subobjects
    }
    
    static func extractAll<File>(from file: File) -> Dictionary<String, Object>
        where File: FileReadHandle
    {
        let data = file.readDataToEndOfFile()
        let parser = TdfParser(data)
        return parser.extractAll()
    }
    
    static func extractAll(from data: Data) -> Dictionary<String, Object> {
        let parser = TdfParser(data)
        return parser.extractAll()
    }
    
    func extractObject(normalizeKeys: Bool = false) -> Object {
        
        let count = data.count
        var token: Token?
        
        var level = 0
        var levels: [Object] = [Object()]
        
        data.withUnsafeBytes() {
            while scanPosition < count {
                (state, token) = TdfParser.transition(state, consuming: $0[scanPosition], context: &context)
                scanPosition += 1
                guard let token = token else { continue }
                switch token {
                case .objectBegin:
                    level += 1
                    levels.append(Object())
                case let .objectEnd(name):
                    guard level > 0 else { return }
                    level -= 1
                    levels[level].subobjects[name] = levels.popLast() ?? Object()
                case let .property(key, value):
                    let key = normalizeKeys ? key.lowercased() : key
                    levels[level].properties[key] = value
                }
            }
        }
        
        return levels[0]
    }
    
}

public extension TdfParser.Object {
    
    init() {
        properties = [:]
        properties.reserveCapacity(8)
        subobjects = [:]
    }
    
    var count: Int { return properties.count + subobjects.count }
    
    subscript(propertyName: String) -> String? {
        get { return properties[propertyName] }
        set(new) { properties[propertyName] = new }
    }
    
    subscript(property name: String) -> String? {
        get { return properties[name] }
        set(new) { properties[name] = new }
    }
    
    subscript(object name: String) -> TdfParser.Object? {
        get { return subobjects[name] }
        set(new) { subobjects[name] = new }
    }
    
}

public extension TdfParser.Object {
    
    enum LoadError: Error {
        case requiredPropertyNotFound(String)
    }
    
    func requiredStringProperty(_ name: String) throws -> String {
        guard let value = properties[name]
            else { throw LoadError.requiredPropertyNotFound(name) }
        return value
    }
    
    func stringProperty(_ name: String, default: String = "") -> String {
        return properties[name] ?? `default`
    }
    
    func boolProperty(_ name: String, default: Bool = false) -> Bool {
        guard let value = properties[name] else { return `default` }
        if let number = Int(value) { return number != 0 }
        // TODO: Maybe handle 'TRUE', 'FALSE', etc. as accepted TDF Boolean values.
        return `default`
    }
    
    func numericProperty<T: Numeric & LosslessStringConvertible>(_ name: String, default: T = 0) -> T {
        guard let value = properties[name] else { return `default` }
        if let number = T(value) { return number }
        return `default`
    }
    
}

// MARK:- Core State Machine

fileprivate extension TdfParser {
    
    enum State {
        case seekingSection
        case readingSectionName
        case seekingSectionStart
        case seekingKeyValue
        case readingKey
        case readingValue
    }
    
    struct Context {
        var parents: [String]
        var section: [UInt8]
        var key: [UInt8]
        var value: [UInt8]
        var whitespace: [UInt8]
        
        init() {
            parents = []
            parents.reserveCapacity(1)
            section = []
            section.reserveCapacity(16)
            key = []
            key.reserveCapacity(16)
            value = []
            value.reserveCapacity(32)
            whitespace = []
        }
    }
    
    static let sectionNameStart: UInt8 = 91 // "["
    static let sectionNameStop: UInt8 = 93 // "]"
    static let sectionBodyStart: UInt8 = 123 // "{"
    static let sectionBodyStop: UInt8 = 125 // "}"
    static let whitespaceToIgnore: Set<UInt8> = [32, 10, 13, 9] //[" ", "\r\n", "\r", "\n", "\t"]
    static let keyValueSeparator: UInt8 = 61 // "="
    static let keyValueStop: UInt8 = 59 // ";"
    
    static func transition(_ state: State, consuming character: UInt8, context: inout Context) -> (State, Token?) {
        switch state {
            
        case .seekingSection:
            if character == sectionNameStart {
                context.section.removeAll()
                return (.readingSectionName, nil)
            }
            else {
                return (state, nil)
            }
            
        case .readingSectionName:
            if character == sectionNameStop {
                return (.seekingSectionStart, nil)
            }
            else {
                context.section.append(character)
                return (.readingSectionName, nil)
            }
            
        case .seekingSectionStart:
            if character == sectionBodyStart {
                let name = String(bytes: context.section, encoding: .ascii) ?? ""
                context.parents.append(name)
                return (.seekingKeyValue, .objectBegin(name))
            }
            else if character == sectionBodyStop {
                let name = context.parents.popLast() ?? ""
                return (context.parents.isEmpty ? .seekingSection : .seekingKeyValue, .objectEnd(name))
            }
            else {
                return (state, nil)
            }
            
        case .seekingKeyValue:
            if whitespaceToIgnore.contains(character) {
                return (state, nil)
            }
            else if character == sectionNameStart {
                context.section.removeAll()
                return (.readingSectionName, nil)
            }
            else if character == sectionBodyStop {
                let name = context.parents.popLast() ?? ""
                return (context.parents.isEmpty ? .seekingSection : .seekingKeyValue, .objectEnd(name))
            }
            else {
                context.key.removeAll()
                context.key.append(character)
                context.whitespace.removeAll()
                return (.readingKey, nil)
            }
            
        case .readingKey:
            if character == keyValueSeparator {
                context.value.removeAll()
                context.whitespace.removeAll()
                return (.readingValue, nil)
            }
            else if whitespaceToIgnore.contains(character) {
                context.whitespace.append(character)
                return (.readingKey, nil)
            }
            else {
                if !context.whitespace.isEmpty {
                    context.key.append(contentsOf: context.whitespace)
                    context.whitespace.removeAll()
                }
                context.key.append(character)
                return (.readingKey, nil)
            }
            
        case .readingValue:
            if character == keyValueStop {
                let key = String(bytes: context.key, encoding: .ascii) ?? ""
                let value = String(bytes: context.value, encoding: .ascii) ?? ""
                return (.seekingKeyValue, .property(key, value))
            }
            else if whitespaceToIgnore.contains(character) {
                if !context.value.isEmpty {
                    context.whitespace.append(character)
                }
                return (.readingValue, nil)
            }
            else {
                if !context.whitespace.isEmpty {
                    context.value.append(contentsOf: context.whitespace)
                    context.whitespace.removeAll()
                }
                context.value.append(character)
                return (.readingValue, nil)
            }
        }
    }
    
}
