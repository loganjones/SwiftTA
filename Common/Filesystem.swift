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
    
    init(mergingHpisIn searchDirectory: URL, extensions: [String] = FileSystem.weightedArchiveExtensions) throws {

        let weighArchives: (URL, URL) -> Bool = { (a,b) in
            let weightA = extensions.index(of: a.pathExtension) ?? -1
            let weightB = extensions.index(of: b.pathExtension) ?? -1
            return weightA < weightB
        }
        
        let merged = try FileSystem.listArchives(in: searchDirectory, allowedExtensions: Set(extensions))
            .sorted { weighArchives($0, $1) }
            .map { FileSystem.Directory(from: try HpiItem.loadFromArchive(contentsOf: $0), in: $0) }
            .reduce(FileSystem.Directory()) { $0.adding(directory: $1) }
        
        root = merged
    }
    
    #if !os(Linux)
    private static func listArchives(in searchDirectory: URL, allowedExtensions: Set<String>) throws -> [URL] {
        let fm = FileManager.default
        
        let isDirectory: (URL) -> Bool = { (url) in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory ?? false
        }
        
        return try fm.contentsOfDirectory(at: searchDirectory,
                                          includingPropertiesForKeys: [.isDirectoryKey],
                                          options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants])
            .filter { !isDirectory($0) && allowedExtensions.contains($0.pathExtension) }
    }
    #else
    private static func listArchives(in searchDirectory: URL, allowedExtensions: Set<String>) throws -> [URL] {
        let fm = FileManager.default
        
        let fullUrl: (String) -> URL = { (filename) in
            return searchDirectory.appendingPathComponent(filename, isDirectory: false)
        }
        
        let isValidFile: (URL) -> Bool = { (url) in
            var isDirectory: ObjCBool = false
            let exists = fm.fileExists(atPath: url.path, isDirectory: &isDirectory)
            return exists && !isDirectory.boolValue
        }
        
        return try fm.contentsOfDirectory(atPath: searchDirectory.path)
            .map { fullUrl($0) }
            .filter { isValidFile($0) && allowedExtensions.contains($0.pathExtension) }
    }
    #endif
    
    /// Load a single HPI file's filesystem.
    init(hpi url: URL) throws {
        let hpi = try HpiItem.loadFromArchive(contentsOf: url)
        root = FileSystem.Directory(from: hpi, in: url)
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
        var itemMap: [Int: Item]
        var items: Dictionary<Int, Item>.Values { return itemMap.values }
    }
    
}

extension FileSystem {
    
    static func compareNames(_ a: String, _ b: String) -> Bool {
        return a.caseInsensitiveCompare(b) == .orderedSame
    }
    
    static func sortNames(_ a: String, _ b: String) -> Bool {
        return a.caseInsensitiveCompare(b) == .orderedAscending
    }
    
    static func hashName(_ name: String) -> Int {
        return name.lowercased().hashValue
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
        itemMap = hpiDirectory.items.reduce(into: [Int: FileSystem.Item]()) {
            let item = FileSystem.Item(from: $1, in: hpiURL)
            let hash = FileSystem.hashName(item.name)
            $0[hash] = item
        }
    }
    
    init() {
        name = ""
        itemMap = [:]
    }
    
    subscript(name: String) -> FileSystem.Item? {
        let hash = FileSystem.hashName(name)
        guard let item = itemMap[hash] else { return nil }
        guard FileSystem.compareNames(item.name, name) else { return nil }
        return item
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
        
        var new = itemMap
        for item in directory.itemMap {
            if let existing = new[item.key] {
                switch item.value {
                case .file:
                    if overwrite { new[item.key] = item.value }
                case .directory(let d):
                    if case .directory(let dd) = existing {
                        new[item.key] = .directory(dd.adding(directory: d, overwrite: overwrite))
                    }
                    else if overwrite {
                        new[item.key] = item.value
                    }
                }
            }
            else {
                new[item.key] = item.value
            }
        }
        return FileSystem.Directory(name: name, itemMap: new)
    }
    
}

extension FileSystem.File {
    
    func hasExtension(_ ext: String) -> Bool {
        return (name as NSString).pathExtension.caseInsensitiveCompare(ext) == .orderedSame
    }
    func hasExtension(_ extensions: Set<String>) -> Bool {
        let ext = (name as NSString).pathExtension
        return extensions.contains(where: { ext.caseInsensitiveCompare($0) == .orderedSame })
    }
    
    var baseName: String {
        return (name as NSString).deletingPathExtension
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
    
    func files(withExtension ext: String) -> [FileSystem.File] {
        return items
            .compactMap { $0.asFile() }
            .filter { $0.hasExtension(ext) }
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
    
    var fileSize: Int {
        return file.info.size
    }
    
    var fileOffset: Int {
        return offsetInFile
    }
    
}
