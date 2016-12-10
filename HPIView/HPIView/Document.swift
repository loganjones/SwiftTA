//
//  Document.swift
//  HPIView
//
//  Created by Logan Jones on 9/12/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import Quartz
import QuickLook
import CoreGraphics


class Document: NSDocument {
    
    var root: HPIItem.Directory?

    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }
    
    override func makeWindowControllers() {
        let controller = HPIBrowserWindowController(windowNibName: "Document")
        addWindowController(controller)
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        
        do {
            let loaded = try HPIItem(withContentsOf: url).sorted()
            switch loaded {
            case .file(let file): throw LoadError.rootIsFile(file)
            case .directory(let directory): root = directory
            }
        }
        catch {
            Swift.print("ERROR: \(error)")
            throw NSError(domain: NSOSStatusErrorDomain, code: readErr, userInfo: nil)
        }
        
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        //throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    enum LoadError: Error {
        case rootIsFile(HPIItem.File)
    }
}

// MARK:- Browser Window

class HPIBrowserWindowController: NSWindowController {
    
    @IBOutlet weak var finder: FinderView!
    
    let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    
    var hpiDocument: Document {
        guard let doc = self.document as? Document
            else { fatalError("No HPI Document associated with this window!?") }
        return doc
    }
    
    override func awakeFromNib() {
        finder.register(NSNib(nibNamed: "HPIFinderRow", bundle: nil), forIdentifier: "HPIItem")
        finder.delegate = self
        if let root = hpiDocument.root {
            finder.setRoot(directory: root)
        }
    }
    
}

extension HPIItem: FinderViewItem {
    
    func isExpandable(in finder: FinderView, path: [FinderViewDirectory]) -> Bool {
        switch self {
        case .file(let file):
            let ext = file.fileExtension
            if ext.caseInsensitiveCompare("gaf") == .orderedSame {
                return true
            }
            else {
                return false
            }
        case .directory:
            return true
        }
    }
    
    func expand(in finder: FinderView, path: [FinderViewDirectory]) -> FinderViewDirectory? {
        switch self {
        case .file(let file):
            let ext = file.fileExtension
            if ext.caseInsensitiveCompare("gaf") == .orderedSame {
                guard let hpic = finder.window?.windowController as? HPIBrowserWindowController
                    else { return nil }
                
                let pathString = path.map({ $0.name }).joined(separator: "/") + "/" + file.name
                print("Selected Path: \(pathString)")
                do {
                    let gafURL = try hpic.extractFileForPreview(file, hpiPath: pathString)
                    return try GafListing(withContentsOf: gafURL)
                }
                catch {
                    return nil
                }
            }
            else {
                return nil
            }
        case .directory(let directory): return directory
        }
    }
    
}

extension HPIItem.Directory: FinderViewDirectory {
    
    var numberOfItems: Int {
        return items.count
    }
    
    func item(at index: Int) -> FinderViewItem {
        return items[index]
    }
    
    func index(of item: FinderViewItem) -> Int? {
        guard let other = item as? HPIItem else { return nil }
        let i = items.index(where: { $0.name == other.name })
        return i
    }
    
}

extension GafItem: FinderViewItem {
    
    func isExpandable(in finder: FinderView, path: [FinderViewDirectory]) -> Bool {
        return false
    }
    
    func expand(in: FinderView, path: [FinderViewDirectory]) -> FinderViewDirectory? {
        return nil
    }
    
}

extension GafListing: FinderViewDirectory {
    
    var numberOfItems: Int {
        return items.count
    }
    
    func item(at index: Int) -> FinderViewItem {
        return items[index]
    }
    
    func index(of item: FinderViewItem) -> Int? {
        guard let other = item as? GafItem else { return nil }
        let i = items.index(where: { $0.name == other.name })
        return i
    }
    
}

extension HPIBrowserWindowController: FinderViewDelegate {
    
    func rowView(for item: FinderViewItem, in tableView: NSTableView, of finder: FinderView) -> NSView? {
        switch item {
        case let item as HPIItem:
            return rowView(for: item, in: tableView, of: finder)
        case let item as GafItem:
            return rowView(for: item, in: tableView, of: finder)
        default:
            print("Unknown item type for: \(item)")
            return nil
        }
    }
    
    func rowView(for item: HPIItem, in tableView: NSTableView, of finder: FinderView) -> NSView? {
    
        guard let view = tableView.make(withIdentifier: "HPIItem", owner: finder) as? NSTableCellView
            else { return nil }
        
        view.textField?.stringValue = item.name
        
        switch item {
            
        case .file:
            let ext = URL(fileURLWithPath: item.name, isDirectory: false).pathExtension.lowercased()
            let icon = NSWorkspace.shared().icon(forFileType: ext)
            view.imageView?.image = icon
            
        case .directory:
            view.imageView?.image = NSImage(named: NSImageNameFolder)
        }
        
        return view
    }
    
    func rowView(for item: GafItem, in tableView: NSTableView, of finder: FinderView) -> NSView? {
        
        guard let view = tableView.make(withIdentifier: "HPIItem", owner: finder) as? NSTableCellView
            else { return nil }
        
        view.textField?.stringValue = item.name
        
        let icon = NSWorkspace.shared().icon(forFileType: "pcx")
        view.imageView?.image = icon
        
        return view
    }
    
    func preview(for item: FinderViewItem, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
        switch item {
        case let item as HPIItem:
            return preview(for: item, at: pathDirectories, of: finder)
        case let item as GafItem:
            return preview(for: item, at: pathDirectories, of: finder)
        default:
            print("Unknown item type for: \(item)")
            return nil
        }
    }
    
    func preview(for item: HPIItem, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
    
        guard case .file(let file) = item else { return nil }
        
        let pathString = pathDirectories.map({ $0.name }).joined(separator: "/") + "/" + item.name
        print("Selected Path: \(pathString)")
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = file.name
        preview.size = file.size
        
        // TEMP
        do {
            let fileURL = try extractFileForPreview(file, hpiPath: pathString)
            let fileExtension = fileURL.pathExtension
            let contentView = preview.contentView
            let subview: NSView
            if fileExtension.caseInsensitiveCompare("pcx") == .orderedSame {
                let pcx = PCXView(frame: contentView.bounds)
                pcx.image = NSImage(pcxContentsOf: fileURL)
                subview = pcx
            }
            else if fileExtension.caseInsensitiveCompare("3do") == .orderedSame {
                let model = Model3DOView(frame: contentView.bounds)
                try! model.loadModel(contentsOf: fileURL)
                subview = model
            }
            else {
                let qlv = QLPreviewView(frame: contentView.bounds, style: .compact)!
                qlv.previewItem = fileURL as NSURL
                qlv.refreshPreviewItem()
                subview = qlv
            }
            subview.translatesAutoresizingMaskIntoConstraints = false
            preview.contentView.addSubview(subview)
            NSLayoutConstraint.activate([
                subview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                subview.topAnchor.constraint(equalTo: contentView.topAnchor),
                subview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
                ])
        }
        catch {
            
        }
        // END TEMP
        
        return preview
    }
    
    func preview(for item: GafItem, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
        
        // MORE TEMP
        guard let listing = pathDirectories.last as? GafListing,
            let parent = pathDirectories[pathDirectories.endIndex-2] as? HPIItem.Directory,
            let i = parent.items.index(where: { $0.name == listing.name }),
            case .file(let file) = parent.items[i]
            else { return nil }
        
        let pathString = pathDirectories.map({ $0.name }).joined(separator: "/")
        print("Selected Path: \(pathString)")
        
        guard case .image(let image) = item
            else { return nil }
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = item.name
        preview.size = 13
        
        // TEMP
        do {
            let fileURL = try extractFileForPreview(file, hpiPath: pathString)
            let contentView = preview.contentView
            let subview: NSView

                let gaf = GafView(frame: contentView.bounds)
                try gaf.load(image: image, from: fileURL)
                subview = gaf

            subview.translatesAutoresizingMaskIntoConstraints = false
            preview.contentView.addSubview(subview)
            NSLayoutConstraint.activate([
                subview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                subview.topAnchor.constraint(equalTo: contentView.topAnchor),
                subview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
                ])
        }
        catch {
            
        }
        // END TEMP
        
        return preview
    }
    
    // TEMP
    
    func extractFileForPreview(_ file: HPIItem.File, hpiPath: String) throws -> URL {
        
        guard let archiveURL = hpiDocument.fileURL
            else { throw PreviewExtractError.badDocument }
        let archiveIdentifier = String(format: "%08X", archiveURL.hashValue)
        
        guard let cachesURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            else { throw PreviewExtractError.badCachesURL }
        
        let archiveContainerURL = cachesURL
            .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
            .appendingPathComponent(archiveIdentifier, isDirectory: true)
        try FileManager.default.createDirectory(at: archiveContainerURL, withIntermediateDirectories: true)
        Swift.print("archiveContainer: \(archiveContainerURL)")
        
        let fileURL = archiveContainerURL.appendingPathComponent(hpiPath, isDirectory: false)
        let fileDirectoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: fileDirectoryURL, withIntermediateDirectories: true)
        let data = try HPIItem.extract(file: file, fromHPI: hpiDocument.fileURL!)
        try data.write(to: fileURL, options: [.atomic])
        
        return fileURL
    }
    
    enum PreviewExtractError: Error {
        case badItem
        case badDocument
        case badCachesURL
    }
    
}

extension HPIBrowserWindowController {
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(extract) {
            return finder.selectedItems.count > 0
        }
        return true
    }
    
    @IBAction func extract(sender: Any?) {
        
        let items = finder.selectedItems.flatMap({ $0 as? HPIItem })
        guard items.count > 0
            else { Swift.print("No selected items to extract."); return }
        
        guard let window = hpiDocument.windowForSheet
            else { Swift.print("Document has no windowForSheet."); return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.beginSheetModal(for: window) {
            switch $0 {
            case NSFileHandlingPanelOKButton:
                if let url = panel.url { self.extractItems(items, to: url) }
            default:
                ()
            }
        }
    }
    
    @IBAction func extractAll(sender: Any?) {
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        
    }
    
    func extractItems(_ items: [HPIItem], to rootDirectory: URL) {
        
        for item in items {
            
            switch item {
            case .file(let file):
                do {
                    let fileURL = rootDirectory.appendingPathComponent(file.name)
                    let data = try HPIItem.extract(file: file, fromHPI: hpiDocument.fileURL!)
                    try data.write(to: fileURL, options: [.atomic])
                }
                catch {
                    Swift.print("Failed to write \(file.name) to file: \(error)")
                }
                
            case .directory(let directory):
                do {
                    let directoryURL = rootDirectory.appendingPathComponent(directory.name)
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                    extractItems(directory.items, to: directoryURL)
                }
                catch {
                    Swift.print("Failed to create directory \(directory.name): \(error)")
                }
            }
            
        }
        
    }
}

fileprivate extension HPIItem {
    
    func sorted() -> HPIItem {
        
        let comp = { (a: HPIItem, b: HPIItem) -> Bool in
            a.name.caseInsensitiveCompare(b.name) == .orderedAscending
        }
        
        switch self {
        case .file: return self
        case .directory(let directory):
            let items = directory.items
                .sorted(by: comp)
                .map({ $0.sorted() })
            return .directory(HPIItem.Directory(name: directory.name, items: items))
        }
        
    }
    
}

fileprivate extension HPIItem.File {
    
    var fileExtension: String {
        let n = name as NSString
        return n.pathExtension
    }
    
}

class PCXView: NSImageView {
    
}

class PreviewContainerView: NSView {
    
    private unowned let titleLabel: NSTextField
    private unowned let sizeLabel: NSTextField
    unowned let contentView: NSView

    override init(frame frameRect: NSRect) {
        let titleLabel = NSTextField(labelWithString: "Title")
        titleLabel.font = NSFont.systemFont(ofSize: 18)
        titleLabel.textColor = NSColor.labelColor
        let sizeLabel = NSTextField(labelWithString: "Empty")
        sizeLabel.font = NSFont.systemFont(ofSize: 12)
        sizeLabel.textColor = NSColor.secondaryLabelColor
        let contentBox = NSView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        
        self.titleLabel = titleLabel
        self.sizeLabel = sizeLabel
        self.contentView = contentBox
        super.init(frame: frameRect)
        
        addSubview(contentBox)
        addSubview(titleLabel)
        addSubview(sizeLabel)
        
        contentBox.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentBox.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            contentBox.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
            contentBox.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            contentBox.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.61803398875),
            
            titleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: 8),
            
            sizeLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            sizeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
            ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var title: String {
        get { return titleLabel.stringValue }
        set(new) { titleLabel.stringValue = new }
    }
    
    var size: Int {
        get { return sizeValue }
        set(new) { sizeValue = new }
    }
    
    private var sizeValue: Int = 0 {
        didSet {
            sizeLabel.stringValue = sizeFormatter.string(fromByteCount: Int64(sizeValue))
        }
    }
    
    private let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    
}
