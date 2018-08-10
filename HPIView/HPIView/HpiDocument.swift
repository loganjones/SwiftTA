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
        let window = NSWindow(contentRect: NSMakeRect(100, 100, 800, 600),
                              styleMask: [.titled, .resizable, .miniaturizable, .closable],
                              backing: .buffered,
                              defer: false)
        let controller = NSWindowController(window: window)
        controller.contentViewController = HpiBrowserViewController(document: self)
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

// MARK:- Browser View Controller

class HpiBrowserViewController: NSViewController {
    
    unowned let hpiDocument: HpiDocument
    
    var finder: FinderView<Item> {
        return view as! FinderView<Item>
    }
    
    let previewController: HpiItemPreviewController
    var previewContentController: NSViewController?
    
    let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    
    lazy var mainPalette: Palette = {
        guard let url = Bundle.main.url(forResource: "PALETTE", withExtension: "PAL")
            else { fatalError("No Palette!") }
        guard let palette = try? Palette(palContentsOf: url)
            else { fatalError("Faile to init Palette!") }
        return palette
    }()
    
    required init(document: HpiDocument) {
        hpiDocument = document
        previewController = HpiItemPreviewController()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = FinderView<Item>(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        finder.register(NSNib(nibNamed: NSNib.Name(rawValue: "HpiFinderRow"), bundle: nil), forIdentifier: "HpiItem")
        finder.createRowView = { [weak self] (item, tableView) in return self?.rowView(for: item, in: tableView) }
        finder.createContentView = { [weak self] (item, path) in return self?.preview(for: item, at: path) }
        finder.setRoot(directory: Directory(hpiDocument.filesystem.root, in: hpiDocument.filesystem))
    }
    
}

extension HpiBrowserViewController {
    
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

extension HpiBrowserViewController.Item {
    
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

extension HpiBrowserViewController.Item: FinderViewItem {
    typealias Directory = HpiBrowserViewController.Directory
    
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

extension HpiBrowserViewController.Directory {
    
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

extension HpiBrowserViewController.Directory: FinderViewDirectory {
    typealias Item = HpiBrowserViewController.Item
    
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

extension HpiBrowserViewController {
    
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
    
    enum PreviewError: Error {
        case directory
        case notGaf
        case notSupported
    }
    
    func preview(for item: Item, at path: [Directory]) -> NSView? {
        do {
            switch item {
            case .directory, .gafArchive:
                throw PreviewError.directory
            case .file(let f):
                try configurePreviewContent(forFile: f, at: path)
            case .gafImage(let i):
                try configurePreviewContent(forGafImage: i, at: path)
            }
            
            if previewController.parent != self {
                addChildViewController(previewController)
            }
            
            return previewController.view
        }
        catch {
            previewController.removeFromParentViewController()
            previewController.contentView = nil
            return nil
        }
    }
    
    func bindContentView<T>(as viewType: T.Type, deafultFrame: NSRect = NSRect(x: 0, y: 0, width: 88, height: 88)) -> T where T: NSView {
        if let view = previewController.contentView as? T {
            return view
        }
        else {
            previewContentController?.removeFromParentViewController()
            previewContentController = nil
            
            let view = T(frame: deafultFrame)
            previewController.contentView = view
            return view
        }
    }
    
    func bindContentViewController<T>(as viewType: T.Type) -> T where T: NSViewController {
        if let controller = previewContentController as? T {
            return controller
        }
        else {
            previewContentController?.removeFromParentViewController()
            
            let controller = T()
            addChildViewController(controller)
            previewContentController = controller
            previewController.contentView = controller.view
            return controller
        }
    }
    
    func configurePreviewContent(forFile file: FileSystem.File, at path: [Directory]) throws {
        
        let pathString = path.map({ $0.name }).joined(separator: "/") + "/" + file.name
        print("Selected Path: \(pathString)")
        
        let fileHandle = try hpiDocument.filesystem.openFile(file)
        
        let preview = previewController
        preview.hpiItemTitle = file.name
        preview.hpiItemSize = file.info.size
        
        do {
            if file.hasExtension("pcx") {
                switch try Pcx.analyze(contentsOf: fileHandle) {
                case .image:
                    let pcxImage = try NSImage(pcxContentsOf: fileHandle)
                    let pcxView = bindContentView(as: NSImageView.self)
                    pcxView.image = pcxImage
                case .palette:
                    let palette = try Pcx.extractPalette(contentsOf: fileHandle)
                    let paletteView = bindContentView(as: PaletteView.self)
                    paletteView.load(palette)
                }
            }
            else if file.hasExtension("pal") {
                let palette = Palette(palContentsOf: fileHandle)
                let view = bindContentView(as: PaletteView.self)
                view.load(palette)
            }
            else if file.hasExtension("3do") {
                let model = try UnitModel(contentsOf: fileHandle)
                let controller = bindContentViewController(as: ModelViewController.self)
                try controller.load(model)
            }
            else if file.hasExtension("cob") {
                let script = try UnitScript(contentsOf: fileHandle)
                let view = bindContentView(as: CobView.self)
                view.load(script)
            }
            else if file.hasExtension("tnt") {
                let controller = bindContentViewController(as: TntViewController.self)
                try controller.load(contentsOf: fileHandle, using: mainPalette)
            }
            else if file.hasExtension(["fbi", "bos", "gui", "tdf", "ota"]) {
                let data = fileHandle.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
                let view = bindContentView(as: GenericTextView.self)
                view.text = text
            }
            else {
                throw PreviewError.notSupported
            }
        }
        catch {
            if case PreviewError.notSupported = error {
                // File type not supported for preview; use QuickLook.
            }
            else {
                print("Failed to load preview from \(file.name): \(error)")
            }
            let quicklook = bindContentViewController(as: QuickLookViewController.self)
            try quicklook.load(contentsOf: fileHandle)
        }
    }
    
    func configurePreviewContent(forGafImage item: GafItem, at path: [Directory]) throws {
        
        // MORE TEMP
        guard case .gaf(let gaf, _, _)? = path.last
            else { throw PreviewError.notGaf }
        
        let pathString = path.map({ $0.name }).joined(separator: "/")
        print("Selected Path: \(pathString)")
        
        let preview = previewController
        preview.hpiItemTitle = item.name
        preview.hpiItemSize = 13
        
        // TEMP
        let view = bindContentView(as: GafView.self)
        let reader = try hpiDocument.filesystem.openFile(gaf)
        try view.load(item, from: reader, using: mainPalette)
        // END TEMP
    }
    
}

extension HpiBrowserViewController {
    
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
    
    init?(_ item: HpiBrowserViewController.Item) {
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

protocol HpiItemPreviewDisplay {
    var hpiItemTitle: String { get set }
    var hpiItemSize: Int { get set }
}

class HpiItemPreviewController: NSViewController, HpiItemPreviewDisplay {
    
    var hpiItemTitle: String {
        get { return preview.titleLabel.stringValue }
        set(new) { preview.titleLabel.stringValue = new }
    }
    
    var hpiItemSize: Int {
        get { return sizeValue }
        set(new) { sizeValue = new }
    }
    
    private var sizeValue: Int = 0 {
        didSet {
            preview.sizeLabel.stringValue = sizeFormatter.string(fromByteCount: Int64(sizeValue))
        }
    }
    
    private let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    
    private var preview: ContainerView {
        return view as! ContainerView
    }
    
    var contentView: NSView? {
        get { return preview.contentView }
        set(new) { preview.contentView = new }
    }
    
    private class ContainerView: NSView {
        
        unowned let titleLabel: NSTextField
        unowned let sizeLabel: NSTextField
        let emptyContentView: NSView
        
        weak var contentView: NSView? {
            didSet {
                guard contentView != oldValue else { return }
                oldValue?.removeFromSuperview()
                if let contentView = contentView {
                    addSubview(contentView)
                    contentView.translatesAutoresizingMaskIntoConstraints = false
                    addContentViewConstraints(contentView)
                }
                else {
                    oldValue?.removeFromSuperview()
                    addSubview(emptyContentView)
                    addContentViewConstraints(emptyContentView)
                }
            }
        }
        
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
            self.emptyContentView = contentBox
            super.init(frame: frameRect)
            
            addSubview(contentBox)
            addSubview(titleLabel)
            addSubview(sizeLabel)
            
            contentBox.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            sizeLabel.translatesAutoresizingMaskIntoConstraints = false
            
            addContentViewConstraints(contentBox)
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                sizeLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                sizeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
                ])
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func addContentViewConstraints(_ contentBox: NSView) {
            NSLayoutConstraint.activate([
                contentBox.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
                contentBox.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
                contentBox.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
                contentBox.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.61803398875),
                titleLabel.topAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: 8),
                ])
        }
        
    }
    
    override func loadView() {
        let preview = ContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        self.view = preview
    }
    
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
