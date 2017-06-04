//
//  Document.swift
//  TAassets
//
//  Created by Logan Jones on 1/15/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa

class TaassetsDocument: NSDocument {
    
    static let weightedArchiveExtensions = ["ufo", "gp3", "ccx", "gpf", "hpi"]
    var assets: Asset.Directory!
    

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
        let viewController = windowController.contentViewController as! TaassetsViewController
        viewController.filesystem = TaassetsFileSystem(rootDirectory: assets)
        self.addWindowController(windowController)
    }
    
    override func read(from directoryURL: URL, ofType typeName: String) throws {
        
        let fm = FileManager.default
        var dirCheck: ObjCBool = false
        guard directoryURL.isFileURL, fm.fileExists(atPath: directoryURL.path, isDirectory: &dirCheck), dirCheck.boolValue
            else { throw NSError(domain: NSOSStatusErrorDomain, code: readErr, userInfo: nil) }
        
        let allowedExtensions = Set<String>(TaassetsDocument.weightedArchiveExtensions)
        
        let archives = try fm.contentsOfDirectory(at: directoryURL,
                                                  includingPropertiesForKeys: [.isDirectoryKey],
                                                  options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants])
            .filter { !$0.isDirectory }
            .filter { allowedExtensions.contains($0.pathExtension) }
            .sorted { weighArchives($0, $1) }
            .map { Asset.Directory(from: try HpiItem.loadFromArchive(contentsOf: $0), in: $0) }
            .reduce(Asset.Directory()) { $0.adding(directory: $1) }
            .sorted()
        
        assets = archives
        
    }

}

class TaassetsDocumentController: NSDocumentController {
    
    override func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { result in
            guard result == NSFileHandlingPanelOKButton else { return }
            guard let selectedURL = panel.urls.first else { return }
            self.openDocument(withContentsOf: selectedURL, display: true) { (document, wasOpened, error) in
                if let document = document {
                    print("opened document: \(document)")
                }
                else if let error = error {
                    print("error opening document: \(error)")
                }
            }
        }
    }
    
}

private extension URL {
    var isDirectory: Bool {
        let values = try? resourceValues(forKeys:  [.isDirectoryKey])
        return values?.isDirectory ?? false
    }
}

private func weighArchives(_ a: URL, _ b: URL) -> Bool {
    let weightA = TaassetsDocument.weightedArchiveExtensions.index(of: a.pathExtension) ?? -1
    let weightB = TaassetsDocument.weightedArchiveExtensions.index(of: b.pathExtension) ?? -1
    return weightA < weightB
}

private struct TaassetsArchive {
    var fileURL: URL
    var directory: HpiItem.Directory
}

// MARK: - Asset

enum Asset {
    
    /// A file contained in the `Asset` filesystem.
    case file(File)
    
    /// A (sub)directory listing in the `Asset` filesystem.
    case directory(Directory)
    
    /**
     Metadata for a specific `File` contained in the `Asset` filesystem.
     The `File` entry can be used to fully `extract()` the file's data from its archive.
     */
    struct File {
        var info: HpiItem.File
        var archiveURL: URL
    }
    
    /**
     A listing of contained Assets.
     These may be Files or more Directories.
     */
    struct Directory {
        var name: String
        var items: [Asset]
    }
    
}

extension Asset {
    
    var name: String {
        switch self {
        case .file(let f): return f.name
        case .directory(let d): return d.name
        }
    }
    
    init(from item: HpiItem, in hpiURL: URL) {
        switch item {
        case .file(let f):
            self = .file(Asset.File(from: f, in: hpiURL))
        case .directory(let d):
            self = .directory(Asset.Directory(from: d, in: hpiURL))
        }
    }
    
    func sorted() -> Asset {
        switch self {
        case .file:
            return self
        case .directory(let directory):
            return .directory(directory.sorted())
        }
    }
    
}

extension Asset.File {
    
    var name: String { return info.name }
    
    init(from file: HpiItem.File, in hpiURL: URL) {
        info = file
        archiveURL = hpiURL
    }
    
}

extension Asset.Directory {
    
    init(from hpiDirectory: HpiItem.Directory, in hpiURL: URL) {
        name = hpiDirectory.name
        items = hpiDirectory.items.map { Asset(from: $0, in: hpiURL) }
    }
    
    init() {
        name = ""
        items = []
    }
    
    subscript(name: String) -> Asset? {
        guard let index = items.index(where: { $0.isSimilarlyNamed(to: name) })
            else { return nil }
        return items[index]
    }
    
    subscript(directory name: String) -> Asset.Directory? {
        guard let asset = self[name]
            else { return nil }
        return asset.asDirectory()
    }
    
    subscript(file name: String) -> Asset.File? {
        guard let asset = self[name]
            else { return nil }
        return asset.asFile()
    }
    
    func adding(directory: Asset.Directory, overwrite: Bool = false) -> Asset.Directory {
        guard !items.isEmpty else { return directory }
        
        var new = items
        for asset in directory.items {
            switch asset {
            case .file(let f):
                if let i = new.index(where: { $0.isSimilarlyNamed(to: f) }) {
                    if overwrite { new[i] = asset }
                }
                else {
                    new.append(asset)
                }
            case .directory(let d):
                if let i = new.index(where: { $0.isSimilarlyNamed(to: d.name) }) {
                    if case .directory(let dd) = new[i] {
                        new[i] = .directory(dd.adding(directory: d))
                    }
                    else if overwrite {
                        new[i] = asset
                    }
                }
                else {
                    new.append(asset)
                }
            }
        }
        return Asset.Directory(name: name, items: new)
    }
    
    func sorted() -> Asset.Directory {
        let comp = { (a: Asset, b: Asset) -> Bool in
            a.name.caseInsensitiveCompare(b.name) == .orderedAscending
        }
        let items = self.items
            .sorted(by: comp)
            .map({ $0.sorted() })
        return Asset.Directory(name: self.name, items: items)
    }
    
}

func AssetNameCompare(_ a: String, _ b: String) -> Bool {
    return a.caseInsensitiveCompare(b) == .orderedSame
}

protocol NamedAsset {
    var name: String { get }
    func isSimilarlyNamed<T: NamedAsset>(to other: T) -> Bool
    func isSimilarlyNamed(to string: String) -> Bool
}
extension NamedAsset {
    func isSimilarlyNamed<T: NamedAsset>(to other: T) -> Bool {
        return AssetNameCompare(name, other.name)
    }
    func isSimilarlyNamed(to string: String) -> Bool {
        return AssetNameCompare(name, string)
    }
}
extension Asset: NamedAsset { }
extension Asset.File: NamedAsset { }

extension Asset.File {
    
    func hasExtension(_ ext: String) -> Bool {
        return (name as NSString).pathExtension.caseInsensitiveCompare(ext) == .orderedSame
    }
    
}

extension Asset {
    
    func asDirectory() -> Asset.Directory? {
        switch self {
        case .directory(let d): return d
        case .file: return nil
        }
    }
    
    func asFile() -> Asset.File? {
        switch self {
        case .directory: return nil
        case .file(let f): return f
        }
    }
    
}

extension Asset.Directory {
    
    func resolve(path: String) throws -> Asset {
        var pathComponenets = path.components(separatedBy: "/")
        if pathComponenets.first == "" { pathComponenets.removeFirst() }
        return try resolve(pathComponents: pathComponenets)
    }
    
    func resolve(pathComponents p: [String]) throws -> Asset {
        return try resolve(pathComponents: p[p.startIndex..<p.endIndex])
    }
    private func resolve(pathComponents path: ArraySlice<String>) throws -> Asset {
        guard let target = path.first else { throw ResolveError.assetNotFound }
        guard let found = self[target] else { throw ResolveError.assetNotFound }
        if path.count == 1 {
            return found
        }
        else if let d = found.asDirectory() {
            return try d.resolve(pathComponents: path.dropFirst())
        }
        else {
            throw ResolveError.assetNotFound
        }
    }
    
    enum ResolveError: Error {
        case assetNotFound
    }
    
}

extension Asset.Directory {
    
    subscript(path p: String) -> Asset? {
        return try? resolve(path: p)
    }
    
    subscript(directoryPath p: String) -> Asset.Directory? {
        guard let asset = try? resolve(path: p)
            else { return nil }
        return asset.asDirectory()
    }
    
    subscript(filePath p: String) -> Asset.File? {
        guard let asset = try? resolve(path: p)
            else { return nil }
        return asset.asFile()
    }
    
}

class TaassetsFileSystem {
    
    var root: Asset.Directory
    var hpiCaches: Dictionary<URL, HpiFileCache> = [:]
    
    init(rootDirectory: Asset.Directory = Asset.Directory()) {
        root = rootDirectory
    }
    
    final func hpiCache(for hpiUrl: URL) throws -> HpiFileCache {
        if let cache = hpiCaches[hpiUrl] {
            return cache
        }
        else {
            let cache = try HpiFileCache(hpiURL: hpiUrl)
            hpiCaches[hpiUrl] = cache
            return cache
        }
    }
    
    final func urlForFile(_ file: Asset.File, at path: String) throws -> URL {
        let cache = try hpiCache(for: file.archiveURL)
        let fileUrl = try cache.url(for: file.info, atHpiPath: path)
        return fileUrl
    }
    
    final func urlForFile(at path: String) throws -> URL {
        guard let file = root[filePath: path]
            else { throw UrlError.fileNotFound }
        return try urlForFile(file, at: path)
    }
    
    enum UrlError: Error {
        case fileNotFound
    }
    
}

// MARK: - View

class TaassetsViewController: NSViewController {
    
    var filesystem: TaassetsFileSystem!
    
    @IBOutlet var unitsButton: NSButton!
    @IBOutlet var weaponsButton: NSButton!
    @IBOutlet var mapsButton: NSButton!
    @IBOutlet var filesButton: NSButton!
    @IBOutlet var contentView: NSView!
    
    private var selectedViewController: ContentViewController?
    private var selectedButton: NSButton?
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // There will be nothing selected the first time this view appears.
        // Select a default in this case.
        if selectedButton == nil {
            unitsButton.state = 1
            didChangeSelection(unitsButton)
        }
    }
    
    @IBAction func didChangeSelection(_ sender: NSButton) {
        
        // Disallow deselcetion (toggling).
        // A selected button can only be deselected by selecting something else.
        guard sender.state == 1, !(sender === selectedButton) else {
            sender.state = 1
            return
        }
        
        selectedButton?.state = 0
        selectedButton = sender
        showSelectedContent(for: sender)
    }
    
    func showSelectedContent(for button: NSButton) {
        switch button {
        case unitsButton:
            showSelectedContent(controller: UnitBrowserViewController())
        case weaponsButton:
            showSelectedContent(controller: EmptyContentViewController())
        case mapsButton:
            showSelectedContent(controller: MapBrowserViewController())
        case filesButton:
            showSelectedContent(controller: FileBrowserViewController())
        default:
            print("Unknown content button: \(button)")
        }
    }
    
    func showSelectedContent<T: ContentViewController>(controller: T) {
        selectedViewController?.view.removeFromSuperview()
        
        controller.filesystem = filesystem
        controller.view.frame = contentView.bounds
        controller.view.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        contentView.addSubview(controller.view)
        selectedViewController = controller
    }
    
}

protocol ContentViewController: class {
    var view: NSView { get }
    var filesystem: TaassetsFileSystem { get set }
}

class EmptyContentViewController: NSViewController, ContentViewController {
    
    var filesystem = TaassetsFileSystem()
    
    override func loadView() {
        let mainView = NSView()
        
        let label = NSTextField(labelWithString: "Empty")
        label.translatesAutoresizingMaskIntoConstraints = false
        mainView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: mainView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: mainView.centerYAnchor),
            ])
        
        self.view = mainView
    }
    
}
