//
//  FileBrowser.swift
//  TAassets
//
//  Created by Logan Jones on 1/17/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa

class FileBrowserViewController: NSViewController, ContentViewController {
    
    var shared = TaassetsSharedState.empty
    var finderView: FinderView<Item>!
    var mainPalette = Palette()
    
    let previewController = FilePreviewController()
    var previewContentController: NSViewController?

    
    override func loadView() {
        let mainView = NSView()
        
        let finder = FinderView<Item>(frame: NSRect(x: 0, y: 0, width: 320, height: 480))
        finder.translatesAutoresizingMaskIntoConstraints = false
        finder.register(NSNib(nibNamed: "HpiFinderRow", bundle: nil), forIdentifier: "HpiItem")
        finder.createRowView = { [weak self] (item, tableView) in return self?.rowView(for: item, in: tableView) }
        finder.createContentView = { [weak self] (item, path) in return self?.preview(for: item, at: path) }
        mainView.addSubview(finder)
        
        NSLayoutConstraint.activate([
            finder.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
            finder.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),
            finder.topAnchor.constraint(equalTo: mainView.topAnchor),
            finder.bottomAnchor.constraint(equalTo: mainView.bottomAnchor),
            ])
        
        self.view = mainView
        self.finderView = finder
    }
    
    override func viewDidLoad() {
        let filesystem = shared.filesystem
        finderView.setRoot(directory: Directory(filesystem.root, in: filesystem))
        
        do {
            let file = try filesystem.openFile(at: "Palettes/PALETTE.PAL")
            mainPalette = Palette(palContentsOf: file)
        }
        catch {
            Swift.print("Error loading Palettes/PALETTE.PAL : \(error)")
        }
    }
}

private extension FileBrowserViewController {
    
    func rowView(for item: Item, in tableView: NSTableView) -> NSView? {
        
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HpiItem"), owner: finderView) as? NSTableCellView
            else { return nil }
        
        view.textField?.stringValue = item.name
        
        switch item {
            
        case .directory:
            view.imageView?.image = NSImage(named: NSImage.folderName)
            
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
                addChild(previewController)
            }
            
            return previewController.view
        }
        catch {
            previewController.removeFromParent()
            previewController.contentView = nil
            return nil
        }
    }
    
    func bindContentView<T>(as viewType: T.Type, deafultFrame: NSRect = NSRect(x: 0, y: 0, width: 88, height: 88)) -> T where T: NSView {
        if let view = previewController.contentView as? T {
            return view
        }
        else {
            previewContentController?.removeFromParent()
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
            previewContentController?.removeFromParent()
            
            let controller = T()
            addChild(controller)
            previewContentController = controller
            previewController.contentView = controller.view
            return controller
        }
    }
    
    func configurePreviewContent(forFile file: FileSystem.File, at path: [Directory]) throws {

        let pathString = path.map({ $0.name }).joined(separator: "/") + "/" + file.name
        print("Selected Path: \(pathString)")
        
        let fileHandle = try shared.filesystem.openFile(file)
        
        let preview = previewController
        preview.hpiItemTitle = file.name
        preview.hpiItemSize = file.info.size
        preview.hpiItemSource = file.archiveURL.lastPathComponent
        
        do {
            if file.hasExtension("pcx") {
                switch try Pcx.analyze(contentsOf: fileHandle) {
                case .image:
                    let pcxImage = try NSImage(pcxContentsOf: fileHandle)
                    let view = bindContentView(as: NSImageView.self)
                    view.image = pcxImage
                case .palette:
                    let palette = try Pcx.extractPalette(contentsOf: fileHandle)
                    let view = bindContentView(as: PaletteView.self)
                    view.load(palette)
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
                try controller.load(contentsOf: fileHandle, from: shared.filesystem)
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
        preview.hpiItemSource = gaf.archiveURL.lastPathComponent
        
        // TEMP
        let view = bindContentView(as: GafView.self)
        let reader = try shared.filesystem.openFile(gaf)
        try view.load(item, from: reader, using: mainPalette)
        // END TEMP
    }
    
}

extension FileBrowserViewController {

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

extension FileBrowserViewController.Item {
    
    init(asset: FileSystem.Item) {
        switch asset {
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

extension FileBrowserViewController.Item: FinderViewItem {
    typealias Directory = FileBrowserViewController.Directory
    
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

extension FileBrowserViewController.Directory {
    
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

extension FileBrowserViewController.Directory: FinderViewDirectory {
    typealias Item = FileBrowserViewController.Item
    
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
        case .directory(_, let items, _): return Item(asset: items[index])
        case .gaf(_, let items, _): return Item(gaf: items[index])
        }
    }
    
    func index(of item: Item) -> Int? {
        switch self {
        case .directory(_, let items, _): return items.firstIndex(where: { FileSystem.compareNames($0.name, item.name) })
        case .gaf(_, let items, _): return items.firstIndex(where: { FileSystem.compareNames($0.name, item.name) })
        }
    }
    
    func index(where predicate: (Item) -> Bool) -> Int? {
        switch self {
        case .directory(_, let items, _): return items.lazy.map({ Item(asset: $0) }).firstIndex(where: predicate)
        case .gaf(_, let items, _): return items.lazy.map({ Item(gaf: $0) }).firstIndex(where: predicate)
        }
    }
    
}

protocol FilePreviewDisplay {
    var hpiItemTitle: String { get set }
    var hpiItemSize: Int { get set }
    var hpiItemSource: String { get set }
}

class FilePreviewController: NSViewController, FilePreviewDisplay {
    
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
    
    var hpiItemSource: String {
        get { return preview.sourceLabel.stringValue }
        set(new) { preview.sourceLabel.stringValue = new }
    }
    
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
        unowned let sourceLabel: NSTextField
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
            let sourceLabel = NSTextField(labelWithString: "None")
            sourceLabel.font = NSFont.systemFont(ofSize: 9)
            sourceLabel.textColor = NSColor.secondaryLabelColor
            let contentBox = NSView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
            
            self.titleLabel = titleLabel
            self.sizeLabel = sizeLabel
            self.sourceLabel = sourceLabel
            self.emptyContentView = contentBox
            super.init(frame: frameRect)
            
            addSubview(contentBox)
            addSubview(titleLabel)
            addSubview(sizeLabel)
            addSubview(sourceLabel)
            
            contentBox.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            sizeLabel.translatesAutoresizingMaskIntoConstraints = false
            sourceLabel.translatesAutoresizingMaskIntoConstraints = false
            
            addContentViewConstraints(contentBox)
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                sizeLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                sizeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
                sourceLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                sourceLabel.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 0),
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
