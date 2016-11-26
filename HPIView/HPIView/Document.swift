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
    
    var root: HPIItem?

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
            root = try HPIItem(withContentsOf: url)
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


}

// MARK:- Browser Window

class HPIBrowserWindowController: NSWindowController {
    
    @IBOutlet weak var fileTreeView: NSOutlineView?
    @IBOutlet weak var previewView: NSView!
    @IBOutlet weak var contentAttributesView: NSView!
    @IBOutlet weak var contentTitleField: NSTextField!
    @IBOutlet weak var contentSizeField: NSTextField!
    
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
    
    var isExpandable: Bool {
        switch self {
        case .file: return false
        case .directory: return true
        }
    }
    
}

extension HPIItem: FinderViewDirectory {
    
    var numberOfItems: Int {
        switch self {
        case .file: return 0
        case .directory(let dir): return dir.items.count
        }
    }
    
    func item(at index: Int) -> FinderViewItem {
        switch self {
        case .file: fatalError("Bad HPI Directory")
        case .directory(let dir): return dir.items[index]
        }
    }
    
    func index(of item: FinderViewItem) -> Int? {
        switch self {
        case .file: return nil
        case .directory(let dir):
            guard let other = item as? HPIItem else { return nil }
            let i = dir.items.index(where: { $0.name == other.name })
            return i
        }
    }
    
}

extension HPIBrowserWindowController: FinderViewDelegate {
    
    func rowView(for item: FinderViewItem, in tableView: NSTableView, of finder: FinderView) -> NSView? {
        
        guard let item = item as? HPIItem
            else { return nil }
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
    
    func preview(for item: FinderViewItem, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
        
        guard let item = item as? HPIItem
            else { return nil }
        guard case .file(let file) = item else { return nil }
        
        let pathString = pathDirectories.map({ $0.name }).joined(separator: "/") + "/" + item.name
        print("Selected Path: \(pathString)")
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = file.name
        preview.size = file.size
        
        // TEMP
        do {
            let fileURL = try extractItemForPreview(item, hpiPath: pathString)
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
    
    // TEMP
    
    func extractItemForPreview(_ file: HPIItem, hpiPath: String) throws -> URL {
        //guard case .file(let properties) = file else { throw PreviewExtractError.badItem }
        
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
        let data = try HPIItem.extract(item: file, fromFile: hpiDocument.fileURL!)
        try data.write(to: fileURL, options: [.atomic])
        
        return fileURL
    }
    
    enum PreviewExtractError: Error {
        case badItem
        case badDocument
        case badCachesURL
    }
    
}

extension HPIBrowserWindowController: NSOutlineViewDelegate {
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView
            else { return }
        outlineView.selectedRowIndexes.forEach {
            let indexPath = outlineView.indexPath(forRow: $0)
            Swift.print("Selected Path: \(outlineView.hpiPath(for: indexPath))")
        }
        let selectedRows = outlineView.selectedRowIndexes
        let selected = selectedRows.flatMap({ outlineView.item(atRow: $0) as? HPIItem })
        switch selected.count {
        case 0: clearPreview()
        case 1:
            switch selected[0] {
            case .file:
                let indexPath = outlineView.indexPath(forRow: selectedRows.first ?? 0)
                preview(file: selected[0], hpiPath: outlineView.hpiPath(for: indexPath))
            case .directory: clearPreview()
            }
        default: clearPreview()
        }
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
                    let data = try HPIItem.extract(item: item, fromFile: hpiDocument.fileURL!)
                    try data.write(to: fileURL, options: [.atomic])
                }
                catch {
                    Swift.print("Failed to write \(file.name) to file: \(error)")
                }
                
            case .directory(let name, let children):
                do {
                    let directoryURL = rootDirectory.appendingPathComponent(name)
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                    extractItems(children, to: directoryURL)
                }
                catch {
                    Swift.print("Failed to create directory \(name): \(error)")
                }
            }
            
        }
        
    }
}

extension HPIBrowserWindowController {
    
    func clearPreview() {
        contentAttributesView.isHidden = true
        previewView.isHidden = true
    }
    
    func preview(file: HPIItem, hpiPath: String) {
        guard case .file(let properties) = file else { return }
        contentAttributesView.isHidden = false
        contentTitleField.stringValue = properties.name
        contentSizeField.stringValue = sizeFormatter.string(fromByteCount: Int64(properties.size))
        
        guard let archiveURL = hpiDocument.fileURL
            else { return }
        let archiveIdentifier = String(format: "%08X", archiveURL.hashValue)
        
        guard let cachesURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            else { return }
        
        let archiveContainerURL = cachesURL
            .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
            .appendingPathComponent(archiveIdentifier, isDirectory: true)
        try? FileManager.default.createDirectory(at: archiveContainerURL, withIntermediateDirectories: true)
        Swift.print("archiveContainer: \(archiveContainerURL)")
        
        let fileURL = archiveContainerURL.appendingPathComponent(hpiPath, isDirectory: false)
        let fileDirectoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: fileDirectoryURL, withIntermediateDirectories: true)
        let data = try? HPIItem.extract(item: file, fromFile: hpiDocument.fileURL!)
        try? data?.write(to: fileURL, options: [.atomic])
        
        let fileExtension = fileURL.pathExtension
        if fileExtension.caseInsensitiveCompare("pcx") == .orderedSame {
            let pcx: PCXView = attachPreviewContentView({ PCXView(frame: $0) })
            pcx.image = NSImage(pcxContentsOf: fileURL)
        }
        else if fileExtension.caseInsensitiveCompare("3do") == .orderedSame {
            let view: Model3DOView = attachPreviewContentView({ Model3DOView(frame: $0) })
            try! view.loadModel(contentsOf: fileURL)
        }
        else {
            let qlv: QLPreviewView = attachPreviewContentView({ QLPreviewView(frame: $0, style: .compact)! })
            qlv.previewItem = fileURL as NSURL
            qlv.refreshPreviewItem()
        }
 
        previewView.isHidden = false
    }
    
    func attachPreviewContentView<VT: NSView>(_ maker: (NSRect)->VT ) -> VT {
        if let view = previewView.subviews.first as? VT {
            print("reused view")
            return view
        }
        else {
            print("new view")
            previewView.subviews.forEach({ $0.removeFromSuperview() })
            let view = maker(previewView.bounds)
            let parent = previewView!
            parent.addSubview(view)
            view.leadingAnchor.constraint(equalTo: parent.leadingAnchor).isActive = true
            view.trailingAnchor.constraint(equalTo: parent.trailingAnchor).isActive = true
            view.topAnchor.constraint(equalTo: parent.topAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: parent.bottomAnchor).isActive = true
            return view
        }
    }
    
    func path(forItem item: HPIItem) -> String {
        guard let outlineView = fileTreeView else { return "" }
        
        if let parent = outlineView.parent(forItem: item) as? HPIItem {
            return path(forItem: parent) + "/" + item.name
        }
        else {
            return "/" + item.name
        }
    }
    
}

extension NSOutlineView {
    
    func hpiPath(for indexPath: IndexPath) -> String {
        return "/" + indexPath
            .map({ (self.item(atRow: $0) as? HPIItem)?.name ?? "??" })
            .joined(separator: "/")
    }
    
    func parentRow(forRow row: Int) -> Int {
        let rowLevel = self.level(forRow: row)
        var r = row - 1
        var l = self.level(forRow: r)
        while (r >= 0 && l >= rowLevel) {
            r -= 1
            l = self.level(forRow: r)
        }
        return r
    }
    
    func indexPath(forRow row: Int) -> IndexPath {
        var path = [Int]()
        var i = row
        while (i >= 0) {
            path.append(i)
            i = self.parentRow(forRow: i)
        }
        return IndexPath(indexes: path.reversed())
    }
    
}

fileprivate extension HPIItem {
    
    var numberOfChildren: Int {
        switch self {
        case .file: return 0
        case .directory(_, let items): return items.count
        }
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
