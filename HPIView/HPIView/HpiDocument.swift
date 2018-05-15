//
//  HpiDocument.swift
//  HPIView
//
//  Created by Logan Jones on 9/12/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import Quartz
import QuickLook
import CoreGraphics


class HpiDocument: NSDocument {
    
    var filesystem: FileSystem!
    
    override func makeWindowControllers() {
        let controller = HpiBrowserWindowController(windowNibName: NSNib.Name(rawValue: "HpiBrowserWindow"))
        addWindowController(controller)
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        do {
            filesystem = try FileSystem(hpi: url)
        }
        catch {
            Swift.print("Failed to read HPI archive (\(url)): \(error)")
            throw NSError(domain: NSOSStatusErrorDomain, code: readErr, userInfo: nil)
        }
    }
    
}

// MARK:- Browser Window

class HpiBrowserWindowController: NSWindowController {
    
    @IBOutlet weak var container: NSView!
    weak var finder: FinderView<Item>!
    
    let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    
    var hpiDocument: HpiDocument {
        guard let doc = self.document as? HpiDocument
            else { fatalError("No HPI Document associated with this window!?") }
        return doc
    }
    
    lazy var mainPalette: Palette = {
        guard let url = Bundle.main.url(forResource: "PALETTE", withExtension: "PAL")
            else { fatalError("No Palette!") }
        guard let palette = try? Palette(palContentsOf: url)
            else { fatalError("Faile to init Palette!") }
        return palette
    }()
    
    override func awakeFromNib() {
        let finder = FinderView<Item>(frame: container.bounds)
        finder.autoresizingMask = [.width, .height]
        finder.register(NSNib(nibNamed: NSNib.Name(rawValue: "HpiFinderRow"), bundle: nil), forIdentifier: "HpiItem")
        finder.createRowView = { [weak self] (item, tableView) in return self?.rowView(for: item, in: tableView) }
        finder.createContentView = { [weak self] (item, path) in return self?.preview(for: item, at: path) }
        container.addSubview(finder)
        self.finder = finder
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        finder.setRoot(directory: Directory(hpiDocument.filesystem.root, in: hpiDocument.filesystem))
    }
    
}

extension HpiBrowserWindowController {
    
    enum Item {
        case directory(FileSystem.Directory)
        case file(FileSystem.File)
        case gafArchive(FileSystem.File)
        case gafImage(GafItem)
    }
    
    enum Directory {
        case directory(FileSystem.Directory, [FileSystem.Item], Context)
        case gaf(FileSystem.File, [GafItem], Context)
        
        struct Context {
            unowned var filesystem: FileSystem
        }
        
        var context: Context {
            switch self {
            case .directory(_, _, let context): return context
            case .gaf(_, _, let context): return context
            }
        }
    }
}

extension HpiBrowserWindowController.Item {
    
    init(_ item: FileSystem.Item) {
        switch item {
        case .file(let f):
            self = (f.hasExtension("gaf") || f.hasExtension("taf")) ? .gafArchive(f) : .file(f)
        case .directory(let d):
            self = .directory(d)
        }
    }
    
    init(gaf: GafItem) {
        self = .gafImage(gaf)
    }
    
}

extension HpiBrowserWindowController.Item: FinderViewItem {
    typealias Directory = HpiBrowserWindowController.Directory
    
    var name: String {
        switch self {
        case .directory(let d): return d.name
        case .file(let f): return f.name
        case .gafArchive(let g): return g.name
        case .gafImage(let i): return i.name
        }
    }
    
    func isExpandable(path: [Directory]) -> Bool {
        switch self {
        case .directory, .gafArchive: return true
        case .file, .gafImage: return false
        }
    }
    
    func expand(path: [Directory]) -> Directory? {
        guard let filesystem = path.last?.context.filesystem else { return nil }
        switch self {
        case .directory(let d): return Directory(d, in: filesystem)
        case .gafArchive(let g): return try? Directory(gafContentsOf: g, in: filesystem)
        case .file, .gafImage: return nil
        }
    }
    
}

extension HpiBrowserWindowController.Directory {
    
    init(_ directory: FileSystem.Directory, in filesystem: FileSystem) {
        let items = directory.items.sorted { FileSystem.sortNames($0.name, $1.name) }
        self = .directory(directory, items, Context(filesystem: filesystem))
    }
    
    init(gafContentsOf file: FileSystem.File, in filesystem: FileSystem) throws {
        let reader = try filesystem.openFile(file)
        let listing = try GafListing(withContentsOf: reader)
        let items = listing.items.sorted { FileSystem.sortNames($0.name, $1.name) }
        self = .gaf(file, items, Context(filesystem: filesystem))
    }
    
}

extension HpiBrowserWindowController.Directory: FinderViewDirectory {
    typealias Item = HpiBrowserWindowController.Item
    
    var name: String {
        switch self {
        case .directory(let d, _, _): return d.name
        case .gaf(let f, _, _): return f.name
        }
    }
    
    var numberOfItems: Int {
        switch self {
        case .directory(_, let items, _): return items.count
        case .gaf(_, let items, _): return items.count
        }
    }
    
    func item(at index: Int) -> Item {
        switch self {
        case .directory(_, let items, _): return Item(items[index])
        case .gaf(_, let items, _): return Item(gaf: items[index])
        }
    }
    
    func index(of item: Item) -> Int? {
        switch self {
        case .directory(_, let items, _): return items.index(where: { FileSystem.compareNames($0.name, item.name) })
        case .gaf(_, let items, _): return items.index(where: { FileSystem.compareNames($0.name, item.name) })
        }
    }
    
    func index(where predicate: (Item) -> Bool) -> Int? {
        switch self {
        case .directory(_, let items, _): return items.lazy.map({ Item($0) }).index(where: predicate)
        case .gaf(_, let items, _): return items.lazy.map({ Item(gaf: $0) }).index(where: predicate)
        }
    }
    
}

extension HpiBrowserWindowController {
    
    func rowView(for item: Item, in tableView: NSTableView) -> NSView? {
        
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HpiItem"), owner: finder) as? NSTableCellView
            else { return nil }
        
        view.textField?.stringValue = item.name
        
        switch item {
            
        case .directory:
            view.imageView?.image = NSImage(named: .folder)
            
        case .file, .gafArchive:
            let ext = URL(fileURLWithPath: item.name, isDirectory: false).pathExtension.lowercased()
            let icon = NSWorkspace.shared.icon(forFileType: ext)
            view.imageView?.image = icon
            
        case .gafImage:
            let icon = NSWorkspace.shared.icon(forFileType: "pcx")
            view.imageView?.image = icon
            
        }
        
        return view
    }
    
    func preview(for item: Item, at path: [Directory]) -> NSView? {
        switch item {
            
        case .directory, .gafArchive:
            print("No preview supported for: \(item)")
            return nil
            
        case .file(let f):
            return preview(forFile: f, at: path)
            
        case .gafImage(let i):
            return preview(forGafImage: i, at: path)
            
        }
    }
    
    func preview(forFile file: FileSystem.File, at path: [Directory]) -> NSView? {
        
        let pathString = path.map({ $0.name }).joined(separator: "/") + "/" + file.name
        print("Selected Path: \(pathString)")
        
        let fileHandle: FileSystem.FileHandle
        do {
            fileHandle = try hpiDocument.filesystem.openFile(file)
        }
        catch {
            print("Failed to extract \(file.name) for preview: \(error)")
            return nil
        }
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = file.name
        preview.size = file.info.size
        
        let contentView = preview.contentView
        let subview: NSView
        do {
            if file.hasExtension("pcx") {
                switch try Pcx.analyze(contentsOf: fileHandle) {
                case .image:
                    let pcxImage = try NSImage(pcxContentsOf: fileHandle)
                    let pcxView = NSImageView(frame: contentView.bounds)
                    pcxView.image = pcxImage
                    subview = pcxView
                case .palette:
                    let palette = try Pcx.extractPalette(contentsOf: fileHandle)
                    let paletteView = PaletteView(frame: contentView.bounds)
                    paletteView.load(palette)
                    subview = paletteView
                }
            }
            else if file.hasExtension("pal") {
                let palette = Palette(palContentsOf: fileHandle)
                let view = PaletteView()
                view.load(palette)
                subview = view
            }
            else if file.hasExtension("3do") {
                let model = try UnitModel(contentsOf: fileHandle)
                let view = Model3DOView(frame: contentView.bounds)
                try view.load(model)
                subview = view
            }
            else if file.hasExtension("cob") {
                let script = try UnitScript(contentsOf: fileHandle)
                let view = CobView(frame: contentView.bounds)
                view.load(script)
                subview = view
            }
            else if file.hasExtension("tnt") {
                let view = TntView(frame: contentView.bounds)
                try view.load(contentsOf: fileHandle, using: mainPalette)
                subview = view
            }
            else {
                let view = QuickLookView(frame: contentView.bounds)
                try view.load(contentsOf: fileHandle)
                subview = view
            }
        }
        catch {
            print("Faile to load image from \(file.name): \(error)")
            let view = QuickLookView(frame: contentView.bounds)
            try? view.load(contentsOf: fileHandle)
            subview = view
        }
        
        subview.translatesAutoresizingMaskIntoConstraints = false
        preview.contentView.addSubview(subview)
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            subview.topAnchor.constraint(equalTo: contentView.topAnchor),
            subview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        
        return preview
    }
    
    func preview(forGafImage item: GafItem, at path: [Directory]) -> NSView? {
        
        // MORE TEMP
        guard case .gaf(let gaf, _, _)? = path.last
            else { return nil }
        
        let pathString = path.map({ $0.name }).joined(separator: "/")
        print("Selected Path: \(pathString)")
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = item.name
        preview.size = 13
        
        // TEMP
        do {
            let contentView = preview.contentView
            let subview: NSView

                let view = GafView(frame: contentView.bounds)
                let reader = try hpiDocument.filesystem.openFile(gaf)
                try view.load(item, from: reader, using: mainPalette)
                subview = view

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
    
}

extension HpiBrowserWindowController {
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(extract) {
            return finder.selectedItems.count > 0
        }
        return true
    }
    
    @IBAction func extract(sender: Any?) {
        
        let items = finder.selectedItems.compactMap { HpiItem($0) }
        guard items.count > 0
            else { Swift.print("No selected items to extract."); return }
        
        guard let window = hpiDocument.windowForSheet
            else { Swift.print("Document has no windowForSheet."); return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.beginSheetModal(for: window) {
            switch $0 {
            case .OK:
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
    
    func extractItems(_ items: [HpiItem], to rootDirectory: URL) {
        
        for item in items {
            
            switch item {
            case .file(let file):
                do {
                    let fileURL = rootDirectory.appendingPathComponent(file.name)
                    let data = try HpiItem.extract(file: file, fromHPI: hpiDocument.fileURL!)
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

fileprivate extension HpiItem {
    
    init?(_ item: HpiBrowserWindowController.Item) {
        switch item {
        case .directory(let d): self = .directory(HpiItem.Directory(name: d.name, items: d.items.map { HpiItem($0) }))
        case .file(let f): self = .file(f.info)
        case .gafArchive(let f): self = .file(f.info)
        case .gafImage: return nil
        }
    }
    
    init(_ item: FileSystem.Item) {
        switch item {
        case .directory(let d): self = .directory(HpiItem.Directory(name: d.name, items: d.items.map { HpiItem($0) }))
        case .file(let f): self = .file(f.info)
        }
    }
    
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

extension FileHandle: FileReadHandle {
    
    var fileName: String {
        return "???"
    }
    
    var fileSize: Int {
        let current = offsetInFile
        let size = seekToEndOfFile()
        seek(toFileOffset: current)
        return Int(size)
    }
    
    var fileOffset: Int {
        return Int(offsetInFile)
    }
    
}
