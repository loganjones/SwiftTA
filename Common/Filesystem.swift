//
//  Filesystem.swift
//  TAassets
//
//  Created by Logan Jones on 6/4/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

class FileSystem {
    
    let root: Directory
    
    static let weightedArchiveExtensions = ["ufo", "gp3", "ccx", "gpf", "hpi"]
    
    init(from searchDirectory: URL, extensions: [String] = FileSystem.weightedArchiveExtensions) throws {
        
        let isDirectory: (URL) -> Bool = { (url) in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory ?? false
        }
        
        let weighArchives: (URL, URL) -> Bool = { (a,b) in
            let weightA = extensions.index(of: a.pathExtension) ?? -1
            let weightB = extensions.index(of: b.pathExtension) ?? -1
            return weightA < weightB
        }

        let allowedExtensions = Set<String>(extensions)
        
        let fm = FileManager.default
        let archives = try fm.contentsOfDirectory(at: searchDirectory,
                                                  includingPropertiesForKeys: [.isDirectoryKey],
                                                  options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants])
            .filter { !isDirectory($0) }
            .filter { allowedExtensions.contains($0.pathExtension) }
            .sorted { weighArchives($0, $1) }
            .map { FileSystem.Directory(from: try HpiItem.loadFromArchive(contentsOf: $0), in: $0) }
            .reduce(FileSystem.Directory()) { $0.adding(directory: $1) }
            .sorted()
        
        root = archives
    }
    
    /// Empty `FileSystem`. No files or directories.
    init() { root = Directory() }
    
}

// MARK:- Item (File & Directory)

extension FileSystem {
    
    enum Item {
        
        /// A file contained in a `FileSystem`.
        case file(File)
        
        /// A (sub)directory listing in a `FileSystem`.
        case directory(Directory)
        
    }
    
    /**
     Metadata for a specific `File` contained in a `FileSystem`.
     The `File` entry can be used to fully `extract()` the file's data from its archive.
     */
    struct File {
        var info: HpiItem.File
        var archiveURL: URL
    }
    
    /**
     A listing of contained `Item`.
     These may be Files or more Directories.
     */
    struct Directory {
        var name: String
        var items: [Item]
    }
    
}

extension FileSystem {
    
    static func compareNames(_ a: String, _ b: String) -> Bool {
        return a.caseInsensitiveCompare(b) == .orderedSame
    }
    
    static func sortNames(_ a: String, _ b: String) -> Bool {
        return a.caseInsensitiveCompare(b) == .orderedAscending
    }
    
}

extension FileSystem.Item {
    
    var name: String {
        switch self {
        case .file(let f): return f.name
        case .directory(let d): return d.name
        }
    }
    
    init(from item: HpiItem, in hpiURL: URL) {
        switch item {
        case .file(let f):
            self = .file(FileSystem.File(from: f, in: hpiURL))
        case .directory(let d):
            self = .directory(FileSystem.Directory(from: d, in: hpiURL))
        }
    }
    
    func sorted() -> FileSystem.Item {
        switch self {
        case .file:
            return self
        case .directory(let directory):
            return .directory(directory.sorted())
        }
    }
    
}

extension FileSystem.File {
    
    var name: String { return info.name }
    
    init(from file: HpiItem.File, in hpiURL: URL) {
        info = file
        archiveURL = hpiURL
    }
    
}

extension FileSystem.Directory {
    
    init(from hpiDirectory: HpiItem.Directory, in hpiURL: URL) {
        name = hpiDirectory.name
        items = hpiDirectory.items.map { FileSystem.Item(from: $0, in: hpiURL) }
    }
    
    init() {
        name = ""
        items = []
    }
    
    subscript(name: String) -> FileSystem.Item? {
        guard let index = items.index(where: { FileSystem.compareNames($0.name, name) })
            else { return nil }
        return items[index]
    }
    
    subscript(directory name: String) -> FileSystem.Directory? {
        guard let item = self[name]
            else { return nil }
        return item.asDirectory()
    }
    
    subscript(file name: String) -> FileSystem.File? {
        guard let item = self[name]
            else { return nil }
        return item.asFile()
    }
    
    func adding(directory: FileSystem.Directory, overwrite: Bool = false) -> FileSystem.Directory {
        guard !items.isEmpty else { return directory }
        
        var new = items
        for item in directory.items {
            switch item {
            case .file(let f):
                if let i = new.index(where: { FileSystem.compareNames($0.name, f.name) }) {
                    if overwrite { new[i] = item }
                }
                else {
                    new.append(item)
                }
            case .directory(let d):
                if let i = new.index(where: { FileSystem.compareNames($0.name, d.name) }) {
                    if case .directory(let dd) = new[i] {
                        new[i] = .directory(dd.adding(directory: d))
                    }
                    else if overwrite {
                        new[i] = item
                    }
                }
                else {
                    new.append(item)
                }
            }
        }
        return FileSystem.Directory(name: name, items: new)
    }
    
    func sorted() -> FileSystem.Directory {
        let items = self.items
            .sorted { FileSystem.sortNames($0.name, $1.name) }
            .map { $0.sorted() }
        return FileSystem.Directory(name: self.name, items: items)
    }
    
}

extension FileSystem.File {
    
    func hasExtension(_ ext: String) -> Bool {
        return (name as NSString).pathExtension.caseInsensitiveCompare(ext) == .orderedSame
    }
    
}

extension FileSystem.Item {
    
    func asDirectory() -> FileSystem.Directory? {
        switch self {
        case .directory(let d): return d
        case .file: return nil
        }
    }
    
    func asFile() -> FileSystem.File? {
        switch self {
        case .directory: return nil
        case .file(let f): return f
        }
    }
    
}

extension FileSystem.Directory {
    
    func resolve(path: String) throws -> FileSystem.Item {
        var pathComponenets = path.components(separatedBy: "/")
        if pathComponenets.first == "" { pathComponenets.removeFirst() }
        return try resolve(pathComponents: pathComponenets)
    }
    
    func resolve(pathComponents p: [String]) throws -> FileSystem.Item {
        return try resolve(pathComponents: p[p.startIndex..<p.endIndex])
    }
    private func resolve(pathComponents path: ArraySlice<String>) throws -> FileSystem.Item {
        guard let target = path.first else { throw ResolveError.notFound }
        guard let found = self[target] else { throw ResolveError.notFound }
        if path.count == 1 {
            return found
        }
        else if let d = found.asDirectory() {
            return try d.resolve(pathComponents: path.dropFirst())
        }
        else {
            throw ResolveError.notFound
        }
    }
    
    enum ResolveError: Error {
        case notFound
    }
    
}

extension FileSystem.Directory {
    
    subscript(path p: String) -> FileSystem.Item? {
        return try? resolve(path: p)
    }
    
    subscript(directoryPath p: String) -> FileSystem.Directory? {
        guard let item = try? resolve(path: p)
            else { return nil }
        return item.asDirectory()
    }
    
    subscript(filePath p: String) -> FileSystem.File? {
        guard let item = try? resolve(path: p)
            else { return nil }
        return item.asFile()
    }
    
}

// MARK:- FileHandle

extension FileSystem {
    
    func openFile(at path: String) throws -> FileHandle {
        
        let item = try root.resolve(path: path)
        guard case let .file(file) = item else {
            throw OpenError.pathIsNotFile
        }
        
        return FileHandle(for: file)
    }
    
    func openFile(_ file: FileSystem.File) throws -> FileHandle {
        return FileHandle(for: file)
    }
    
    class FileHandle {
        let file: FileSystem.File
        fileprivate(set) var offsetInFile: Int = 0
        fileprivate var buffer: Data? = nil
        
        fileprivate init(for file: FileSystem.File) {
            self.file = file
        }
    }
    
    enum OpenError: Swift.Error {
        case pathIsNotFile
    }
    
}

extension FileSystem.FileHandle: FileReadHandle {
    
    func readDataToEndOfFile() -> Data {
        return readData(ofLength: file.info.size - offsetInFile)
    }
    
    func readData(ofLength length: Int) -> Data {
        
        if let data = buffer {
            let start = offsetInFile
            let end = min(start + length, file.info.size)
            offsetInFile = end
            return data.subdata(in: start ..< end)
        }
        else {
            do {
                buffer = try HpiItem.extract(file: file.info, fromHPI: file.archiveURL)
                return readData(ofLength: length)
            }
            catch {
                return Data()
            }
        }
    }
    
    func seekToEndOfFile() -> Int {
        offsetInFile = file.info.size
        return offsetInFile
    }
    
    func seek(toFileOffset offset: Int) {
        offsetInFile = min(offset, file.info.size)
    }
    
    var fileName: String {
        return file.name
    }
    
}
