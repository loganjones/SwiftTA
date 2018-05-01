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
    
    override func loadView() {
        let mainView = NSView()
        
        let finder = FinderView<Item>(frame: NSRect(x: 0, y: 0, width: 320, height: 480))
        finder.translatesAutoresizingMaskIntoConstraints = false
        finder.register(NSNib(nibNamed: NSNib.Name(rawValue: "HpiFinderRow"), bundle: nil), forIdentifier: "HpiItem")
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
    
    func preview(for item: Item, at pathDirectories: [Directory]) -> NSView? {
        switch item {
            
        case .directory, .gafArchive:
            print("No preview supported for: \(item)")
            return nil
            
        case .file(let f):
            return preview(forFile: f, at: pathDirectories)
            
        case .gafImage(let i):
            return preview(forGafImage: i, at: pathDirectories)
            
        }
    }
    
    func preview(forFile file: FileSystem.File, at pathDirectories: [Directory]) -> NSView? {
        
        let pathString = pathDirectories.map({ $0.name }).joined(separator: "/") + "/" + file.name
        print("Selected Path: \(pathString)")
        
        let fileHandle: FileSystem.FileHandle
        do {
            fileHandle = try shared.filesystem.openFile(file)
        }
        catch {
            print("Failed to extract \(file.name) for preview: \(error)")
            return nil
        }
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = file.name
        preview.size = file.info.size
        preview.source = file.archiveURL.lastPathComponent
        
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
                let paletteView = PaletteView(frame: contentView.bounds)
                paletteView.load(palette)
                subview = paletteView
            }
            else if file.hasExtension("3do") {
                let model = try UnitModel(contentsOf: fileHandle)
                let view = Model3DOView(frame: contentView.bounds)
                view.load(model)
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
                try view.load(contentsOf: fileHandle, from: shared.filesystem)
                subview = view
            }
            else {
                let view = QuickLookView(frame: contentView.bounds)
                try view.load(contentsOf: fileHandle)
                subview = view
            }
        }
        catch {
            print("Failed to load load \(file.name) for preview: \(error)")
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
        preview.source = gaf.archiveURL.lastPathComponent
        
        // TEMP
        do {
            let contentView = preview.contentView
            let subview: NSView
            
            let view = GafView(frame: contentView.bounds)
            try view.load(item, from: try shared.filesystem.openFile(gaf), using: mainPalette)
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
        case .directory(_, let items, _): return items.index(where: { FileSystem.compareNames($0.name, item.name) })
        case .gaf(_, let items, _): return items.index(where: { FileSystem.compareNames($0.name, item.name) })
        }
    }
    
    func index(where predicate: (Item) -> Bool) -> Int? {
        switch self {
        case .directory(_, let items, _): return items.lazy.map({ Item(asset: $0) }).index(where: predicate)
        case .gaf(_, let items, _): return items.lazy.map({ Item(gaf: $0) }).index(where: predicate)
        }
    }
    
}

private class PreviewContainerView: NSView {
    
    private unowned let titleLabel: NSTextField
    private unowned let sizeLabel: NSTextField
    private unowned let sourceLabel: NSTextField
    unowned let contentView: NSView
    
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
        self.contentView = contentBox
        super.init(frame: frameRect)
        
        addSubview(contentBox)
        addSubview(titleLabel)
        addSubview(sizeLabel)
        addSubview(sourceLabel)
        
        contentBox.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentBox.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            contentBox.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
            contentBox.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            contentBox.heightAnchor.constraint(equalTo: self.heightAnchor, multiplier: 0.61803398875),
            
            titleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: 8),
            
            sizeLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            sizeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
            
            sourceLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            sourceLabel.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 0),
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
    
    var source: String {
        get { return sourceLabel.stringValue }
        set(new) { sourceLabel.stringValue = new }
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
