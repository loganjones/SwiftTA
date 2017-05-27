//
//  FileBrowser.swift
//  TAassets
//
//  Created by Logan Jones on 1/17/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa
import Quartz
import QuickLook
import CoreGraphics


class FileBrowserViewController: NSViewController, ContentViewController {
    
    var filesystem = TaassetsFileSystem()
    var finderView: FinderView!
    
    override func loadView() {
        let mainView = NSView()
        
        let finder = FinderView(frame: NSRect(x: 0, y: 0, width: 320, height: 480))
        finder.translatesAutoresizingMaskIntoConstraints = false
        finder.register(NSNib(nibNamed: "HpiFinderRow", bundle: nil), forIdentifier: "HpiItem")
        finder.delegate = self
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
        finderView.setRoot(directory: FileBrowserItem.Directory(asset: filesystem.root, browser: self))
    }
}

extension FileBrowserViewController: FinderViewDelegate {
    
    func rowView(for item: FinderViewItem, in tableView: NSTableView, of finder: FinderView) -> NSView? {
        
        guard let item = item as? FileBrowserItem
            else { return nil }
        guard let view = tableView.make(withIdentifier: "HpiItem", owner: finder) as? NSTableCellView
            else { return nil }
        
        view.textField?.stringValue = item.name
        
        switch item {
            
        case .directory:
            view.imageView?.image = NSImage(named: NSImageNameFolder)
            
        case .file, .gafArchive:
            let ext = URL(fileURLWithPath: item.name, isDirectory: false).pathExtension.lowercased()
            let icon = NSWorkspace.shared().icon(forFileType: ext)
            view.imageView?.image = icon
            
        case .gafImage:
            let icon = NSWorkspace.shared().icon(forFileType: "pcx")
            view.imageView?.image = icon
            
        }
        
        return view
    }
    
    func preview(for item: FinderViewItem, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
        
        guard let item = item as? FileBrowserItem
            else { return nil }
        
        switch item {
            
        case .directory, .gafArchive:
            print("No preview supported for: \(item)")
            return nil
            
        case .file(let f):
            return preview(forFile: f, at: pathDirectories, of: finder)
            
        case .gafImage(let i):
            return preview(forGafImage: i, at: pathDirectories, of: finder)
            
        }
    }
    
    func preview(forFile file: Asset.File, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
        
        let pathString = pathDirectories.map({ $0.name }).joined(separator: "/") + "/" + file.name
        print("Selected Path: \(pathString)")
        
        let fileURL: URL
        do {
            fileURL = try filesystem.urlForFile(file, at: pathString)
        }
        catch {
            print("Failed to extract \(file.name) for preview: \(error)")
            return nil
        }
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = file.name
        preview.size = file.info.size
        preview.source = file.archiveURL.lastPathComponent
        
        let fileExtension = fileURL.pathExtension
        let contentView = preview.contentView
        let subview: NSView
        if fileExtension.caseInsensitiveCompare("pcx") == .orderedSame {
            do {
                let pcxImage = try NSImage(pcxContentsOf: fileURL)
                let pcxView = NSImageView(frame: contentView.bounds)
                pcxView.image = pcxImage
                subview = pcxView
            }
            catch {
                print("Faile to load image from \(file.name): \(error)")
                let qlv = QLPreviewView(frame: contentView.bounds, style: .compact)!
                qlv.previewItem = fileURL as NSURL
                qlv.refreshPreviewItem()
                subview = qlv
            }
        }
        else if fileExtension.caseInsensitiveCompare("3do") == .orderedSame {
            let model = Model3DOView(frame: contentView.bounds)
            try! model.loadModel(contentsOf: fileURL)
            subview = model
        }
        else if fileExtension.caseInsensitiveCompare("cob") == .orderedSame {
            let view = CobView(frame: contentView.bounds)
            try! view.load(contentsOf: fileURL)
            subview = view
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
        
        return preview
    }
    
    func preview(forGafImage image: GafImage, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
        
        // MORE TEMP
        guard let gaf = pathDirectories.last as? FileBrowserItem.GafContents
            else { return nil }
        
        let pathString = pathDirectories.map({ $0.name }).joined(separator: "/")
        print("Selected Path: \(pathString)")
        
        guard let gafUrl = try? gaf.cache.url(for: gaf.asset.info, atHpiPath: pathString)
            else { return nil }
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = image.name
        preview.size = 13
        preview.source = gaf.asset.archiveURL.lastPathComponent
        
        // TEMP
        do {
            let contentView = preview.contentView
            let subview: NSView
            
            let gaf = GafView(frame: contentView.bounds)
            try gaf.load(image: image, from: gafUrl)
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
    
}

enum FileBrowserItem {
    case directory(Directory)
    case file(Asset.File)
    case gafArchive(GafArchive)
    case gafImage(GafImage)
    
    struct Directory {
        var asset: Asset.Directory
        unowned var browser: FileBrowserViewController
    }
    
    struct GafArchive {
        var asset: Asset.File
        unowned var browser: FileBrowserViewController
    }
    
    struct GafContents {
        var asset: Asset.File
        var cache: HpiFileCache
        var listing: GafListing
        unowned var browser: FileBrowserViewController
    }
}

extension FileBrowserItem {
    
    init(asset: Asset, browser: FileBrowserViewController) {
        switch asset {
        case .file(let f):
            let ext = (f.name as NSString).pathExtension.lowercased()
            self = ext == "gaf" ? .gafArchive(GafArchive(asset: f, browser: browser)) : .file(f)
        case .directory(let d):
            self = .directory(Directory(asset: d, browser: browser))
        }
    }
    
    init(gaf: GafItem) {
        switch gaf {
        case .image(let i): self = .gafImage(i)
        }
    }
    
}

extension FileBrowserItem: NamedAsset { }

extension FileBrowserItem: FinderViewItem {
    
    var name: String {
        switch self {
        case .directory(let d): return d.asset.name
        case .file(let f): return f.name
        case .gafArchive(let g): return g.asset.name
        case .gafImage(let i): return i.name
        }
    }
    
    func isExpandable(in finder: FinderView, path: [FinderViewDirectory]) -> Bool {
        switch self {
        case .directory, .gafArchive: return true
        case .file, .gafImage: return false
        }
    }
    
    func expand(in finder: FinderView, path: [FinderViewDirectory]) -> FinderViewDirectory? {
        switch self {
        case .directory(let d): return d
        case .gafArchive(let g): return try? FileBrowserItem.GafContents(of: g, at: path)
        case .file, .gafImage: return nil
        }
    }
    
}

extension FileBrowserItem.Directory: FinderViewDirectory {
    
    var name: String {
        return asset.name
    }

    var numberOfItems: Int {
        return asset.items.count
    }
    
    func item(at index: Int) -> FinderViewItem {
        return FileBrowserItem(asset: asset.items[index], browser: browser)
    }
    
    func index(of item: FinderViewItem) -> Int? {
        guard let item = item as? FileBrowserItem else { return nil }
        let i = asset.items.index(where: { $0.isSimilarlyNamed(to: item.name) })
        return i
    }
    
    func index(where predicate: (FinderViewItem) -> Bool) -> Int? {
        let b = browser
        return asset.items.lazy
            .map { FileBrowserItem(asset: $0, browser: b) }
            .index(where: predicate)
    }
    
}

extension FileBrowserItem.GafContents {
    
    init(of archive: FileBrowserItem.GafArchive, at path: [FinderViewDirectory]) throws {
        asset = archive.asset
        browser = archive.browser
        cache = try HpiFileCache(hpiURL: asset.archiveURL)
        let pathString = path.map({ $0.name }).joined(separator: "/") + "/" + asset.name
        listing = try GafListing(withContentsOf: cache.url(for: asset.info, atHpiPath: pathString))
    }
    
}

extension FileBrowserItem.GafContents: FinderViewDirectory {
    
    var name: String {
        return asset.name
    }
    
    var numberOfItems: Int {
        return listing.items.count
    }
    
    func item(at index: Int) -> FinderViewItem {
        return FileBrowserItem(gaf: listing.items[index])
    }
    
    func index(of item: FinderViewItem) -> Int? {
        guard let item = item as? FileBrowserItem else { return nil }
        let i = listing.items.index(where: { item.isSimilarlyNamed(to: $0.name) })
        return i
    }
    
    func index(where predicate: (FinderViewItem) -> Bool) -> Int? {
        return listing.items.lazy
            .map { FileBrowserItem(gaf: $0) }
            .index(where: predicate)
    }
    
}

class PreviewContainerView: NSView {
    
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
