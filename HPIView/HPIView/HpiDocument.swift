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
    
    var root: HpiItem.Directory?
    
    override func makeWindowControllers() {
        let controller = HpiBrowserWindowController(windowNibName: NSNib.Name(rawValue: "HpiBrowserWindow"))
        addWindowController(controller)
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        do {
            root = try HpiItem.loadFromArchive(contentsOf: url).sorted()
        }
        catch {
            Swift.print("Failed to read HPI archive (\(url)): \(error)")
            throw NSError(domain: NSOSStatusErrorDomain, code: readErr, userInfo: nil)
        }
    }
    
}

// MARK:- Browser Window

class HpiBrowserWindowController: NSWindowController {
    
    @IBOutlet weak var finder: FinderView!
    fileprivate var cache: HpiFileCache?
    
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
        guard let palette = try? Palette(contentsOf: url)
            else { fatalError("Faile to init Palette!") }
        return palette
    }()
    
    override func awakeFromNib() {
        finder.register(NSNib(nibNamed: NSNib.Name(rawValue: "HpiFinderRow"), bundle: nil), forIdentifier: "HpiItem")
        finder.delegate = self
        if let root = hpiDocument.root {
            finder.setRoot(directory: root)
        }
        if let url = hpiDocument.fileURL {
            cache = try? HpiFileCache(hpiURL: url)
        }
    }
    
}

extension HpiItem: FinderViewItem {
    
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
                guard let hpic = finder.window?.windowController as? HpiBrowserWindowController
                    else { return nil }
                guard let cache = hpic.cache
                    else { return nil }
                
                let pathString = path.map({ $0.name }).joined(separator: "/") + "/" + file.name
                print("Selected Path: \(pathString)")
                do {
                    let gafURL = try cache.url(for: file, atHpiPath: pathString)
                    let gafFile = try FileHandle(forReadingFrom: gafURL)
                    let listing = try GafListing(withContentsOf: gafFile)
                    return BrowserGafFile(name: file.name, listing: listing)
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

extension HpiItem.Directory: FinderViewDirectory {
    
    var numberOfItems: Int {
        return items.count
    }
    
    func item(at index: Int) -> FinderViewItem {
        return items[index]
    }
    
    func index(of item: FinderViewItem) -> Int? {
        guard let other = item as? HpiItem else { return nil }
        let i = items.index(where: { $0.name == other.name })
        return i
    }
    
    func index(where predicate: (FinderViewItem) -> Bool) -> Int? {
        return items.index(where: predicate)
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

struct BrowserGafFile: FinderViewDirectory {
    
    var name: String
    var listing: GafListing
    
    var numberOfItems: Int {
        return listing.items.count
    }
    
    func item(at index: Int) -> FinderViewItem {
        return listing.items[index]
    }
    
    func index(of item: FinderViewItem) -> Int? {
        guard let other = item as? GafItem else { return nil }
        let i = listing.items.index(where: { $0.name == other.name })
        return i
    }
    
    func index(where predicate: (FinderViewItem) -> Bool) -> Int? {
        return listing.items.index(where: predicate)
    }
    
}

extension HpiBrowserWindowController: FinderViewDelegate {
    
    func rowView(for item: FinderViewItem, in tableView: NSTableView, of finder: FinderView) -> NSView? {
        switch item {
        case let item as HpiItem:
            return rowView(for: item, in: tableView, of: finder)
        case let item as GafItem:
            return rowView(for: item, in: tableView, of: finder)
        default:
            print("Unknown item type for: \(item)")
            return nil
        }
    }
    
    func rowView(for item: HpiItem, in tableView: NSTableView, of finder: FinderView) -> NSView? {
    
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HpiItem"), owner: finder) as? NSTableCellView
            else { return nil }
        
        view.textField?.stringValue = item.name
        
        switch item {
            
        case .file:
            let ext = URL(fileURLWithPath: item.name, isDirectory: false).pathExtension.lowercased()
            let icon = NSWorkspace.shared.icon(forFileType: ext)
            view.imageView?.image = icon
            
        case .directory:
            view.imageView?.image = NSImage(named: NSImage.Name.folder)
        }
        
        return view
    }
    
    func rowView(for item: GafItem, in tableView: NSTableView, of finder: FinderView) -> NSView? {
        
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HpiItem"), owner: finder) as? NSTableCellView
            else { return nil }
        
        view.textField?.stringValue = item.name
        
        let icon = NSWorkspace.shared.icon(forFileType: "pcx")
        view.imageView?.image = icon
        
        return view
    }
    
    func preview(for item: FinderViewItem, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
        switch item {
        case let item as HpiItem:
            return preview(for: item, at: pathDirectories, of: finder)
        case let item as GafItem:
            return preview(for: item, at: pathDirectories, of: finder)
        default:
            print("Unknown item type for: \(item)")
            return nil
        }
    }
    
    func preview(for item: HpiItem, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
    
        guard case .file(let file) = item else { return nil }
        guard let cache = cache else { return nil }
        
        let pathString = pathDirectories.map({ $0.name }).joined(separator: "/") + "/" + item.name
        print("Selected Path: \(pathString)")
        
        let fileURL: URL
        do {
            fileURL = try cache.url(for: file, atHpiPath: pathString)
        }
        catch {
            print("Failed to extract \(file.name) for preview: \(error)")
            return nil
        }
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = file.name
        preview.size = file.size
        
        let fileExtension = fileURL.pathExtension
        let contentView = preview.contentView
        let subview: NSView
        do {
            if fileExtension.caseInsensitiveCompare("pcx") == .orderedSame {
                let fileHandle = try FileHandle(forReadingFrom: fileURL)
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
            else if fileExtension.caseInsensitiveCompare("pal") == .orderedSame {
                let palette = try Palette(contentsOf: fileURL)
                let view = PaletteView()
                view.load(palette)
                subview = view
            }
            else if fileExtension.caseInsensitiveCompare("3do") == .orderedSame {
                let modelFile = try FileHandle(forReadingFrom: fileURL)
                let model = try UnitModel(contentsOf: modelFile)
                let view = Model3DOView(frame: contentView.bounds)
                view.load(model)
                subview = view
            }
            else if fileExtension.caseInsensitiveCompare("cob") == .orderedSame {
                let cobFile = try FileHandle(forReadingFrom: fileURL)
                let script = try UnitScript(contentsOf: cobFile)
                let view = CobView(frame: contentView.bounds)
                view.load(script)
                subview = view
            }
            else if fileExtension.caseInsensitiveCompare("tnt") == .orderedSame {
                let mapFile = try FileHandle(forReadingFrom: fileURL)
                let view = TntView(frame: contentView.bounds)
                try view.load(contentsOf: mapFile, using: mainPalette)
                subview = view
            }
            else {
                let view = QLPreviewView(frame: contentView.bounds, style: .compact)!
                view.previewItem = fileURL as NSURL
                view.refreshPreviewItem()
                subview = view
            }
        }
        catch {
            print("Faile to load image from \(file.name): \(error)")
            let view = QLPreviewView(frame: contentView.bounds, style: .compact)!
            view.previewItem = fileURL as NSURL
            view.refreshPreviewItem()
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
    
    func preview(for item: GafItem, at pathDirectories: [FinderViewDirectory], of finder: FinderView) -> NSView? {
        
        // MORE TEMP
        guard let gafFile = pathDirectories.last as? BrowserGafFile,
            let parent = pathDirectories[pathDirectories.endIndex-2] as? HpiItem.Directory,
            let i = parent.items.index(where: { $0.name == gafFile.name }),
            case .file(let file) = parent.items[i]
            else { return nil }
        
        let pathString = pathDirectories.map({ $0.name }).joined(separator: "/")
        print("Selected Path: \(pathString)")
        
        guard let _fileURL = try? cache?.url(for: file, atHpiPath: pathString), let fileURL = _fileURL
            else { return nil }
        
        let preview = PreviewContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        preview.title = item.name
        preview.size = 13
        
        // TEMP
        do {
            let contentView = preview.contentView
            let subview: NSView

                let view = GafView(frame: contentView.bounds)
                let gafFile = try FileHandle(forReadingFrom: fileURL)
                try view.load(item, from: gafFile, using: mainPalette)
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
        
        let items = finder.selectedItems.compactMap({ $0 as? HpiItem })
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
    
    func sorted() -> HpiItem {
        switch self {
        case .file:
            return self
        case .directory(let directory):
            return .directory(directory.sorted())
        }
    }
    
}

fileprivate extension HpiItem.Directory {
    
    func sorted() -> HpiItem.Directory {
        let comp = { (a: HpiItem, b: HpiItem) -> Bool in
            a.name.caseInsensitiveCompare(b.name) == .orderedAscending
        }
        let items = self.items
            .sorted(by: comp)
            .map({ $0.sorted() })
        return HpiItem.Directory(name: self.name, items: items)
    }
    
}

fileprivate extension HpiItem.File {
    
    var fileExtension: String {
        let n = name as NSString
        return n.pathExtension
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
