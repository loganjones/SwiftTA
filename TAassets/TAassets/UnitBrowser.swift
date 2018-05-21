//
//  UnitBrowser.swift
//  TAassets
//
//  Created by Logan Jones on 1/22/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa


class UnitBrowserViewController: NSViewController, ContentViewController {
    
    var shared = TaassetsSharedState.empty
    fileprivate var units: [UnitInfo] = []
    fileprivate var textures = ModelTexturePack()
    
    fileprivate var tableView: NSTableView!
    fileprivate var detailViewContainer: NSView!
    fileprivate var detailViewController: UnitDetailViewController?
    
    static let picSize: CGFloat = 64
    
    override func loadView() {
        let bounds = NSRect(x: 0, y: 0, width: 480, height: 480)
        let mainView = NSView(frame: bounds)
        
        let listWidth: CGFloat = 240
        
        let scrollView = NSScrollView(frame: NSMakeRect(0, 0, listWidth, bounds.size.height))
        scrollView.autoresizingMask = [.height]
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        
        let tableView = NSTableView(frame: NSMakeRect(0, 0, listWidth, bounds.size.height))
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
        column.width = listWidth-2
        tableView.addTableColumn(column)
        tableView.identifier = NSUserInterfaceItemIdentifier(rawValue: "units")
        tableView.headerView = nil
        tableView.rowHeight = UnitBrowserViewController.picSize
        
        scrollView.documentView = tableView
        
        tableView.dataSource = self
        tableView.delegate = self
        mainView.addSubview(scrollView)
        
        let detail = NSView(frame: NSMakeRect(listWidth, 0, bounds.size.width - listWidth, bounds.size.height))
        detail.autoresizingMask = [.width, .height]
        mainView.addSubview(detail)
        
        self.view = mainView
        self.detailViewContainer = detail
        self.tableView = tableView
    }
    
    override func viewDidLoad() {
        let begin = Date()
        let unitsDirectory = shared.filesystem.root[directory: "units"] ?? FileSystem.Directory()
        let units = unitsDirectory.items
            .compactMap { $0.asFile() }
            .filter { $0.hasExtension("fbi") }
            .sorted { FileSystem.sortNames($0.name, $1.name) }
            .compactMap { try? shared.filesystem.openFile($0) }
            .compactMap { try? UnitInfo(contentsOf: $0) }
        self.units = units
        let end = Date()
        print("UnitInfo list load time: \(end.timeIntervalSince(begin)) seconds")
        
        textures = ModelTexturePack(loadFrom: shared.filesystem)
    }
    
    final func buildpic(for unitName: String) -> NSImage? {
        if let file = try? shared.filesystem.openFile(at: "unitpics/" + unitName + ".PCX") {
            return try? NSImage(pcxContentsOf: file)
        }
        else if let file = try? shared.filesystem.openFile(at: "anims/buildpic/" + unitName + ".jpg") {
            let data = file.readDataToEndOfFile()
            return NSImage(data: data)
        }
        else {
            return nil
        }
    }
    
}

extension UnitBrowserViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return units.count
    }
    
}

extension UnitBrowserViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell: UnitInfoCell
        if let existing = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "UnitInfo"), owner: self) as? UnitInfoCell {
            cell = existing
        }
        else {
            cell = UnitInfoCell()
            cell.identifier = NSUserInterfaceItemIdentifier(rawValue: "UnitInfo")
        }
        
        let unit = units[row]
        cell.name = unit.name
        cell.title = unit.title
        cell.descriptionText = unit.description
        cell.buildpic = buildpic(for: unit.name)
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView
            else { return }
        let row = tableView.selectedRow
        if row >= 0 {
            detailViewController?.view.removeFromSuperview()
            
            let controller = UnitDetailViewController()
            controller.view.frame = detailViewContainer.bounds
            controller.view.autoresizingMask = [.width, .width]
            detailViewContainer.addSubview(controller.view)
            detailViewController = controller
            controller.shared = UnitBrowserSharedState(filesystem: shared.filesystem, textures: textures, sides: shared.sides)
            do { try controller.load(units[row]) }
            catch { print("!!! Failed to load \(units[row].name): \(error)") }
        }
        else {
            detailViewController?.view.removeFromSuperview()
            detailViewController = nil
        }
    }
    
}

class UnitInfoCell: NSTableCellView {
    
    private var picView: NSImageView!
    private var nameField: NSTextField!
    private var titleField: NSTextField!
    private var descriptionField: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        picView = NSImageView()
        picView.translatesAutoresizingMaskIntoConstraints = false
        picView.imageScaling = .scaleProportionallyUpOrDown
        self.addSubview(picView)
        
        nameField = NSTextField(labelWithString: "")
        nameField.font = NSFont.systemFont(ofSize: 14)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(nameField)
        
        titleField = NSTextField(labelWithString: "")
        titleField.font = NSFont.systemFont(ofSize: 12)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(titleField)
        
        descriptionField = NSTextField(labelWithString: "")
        descriptionField.font = NSFont.systemFont(ofSize: 8)
        descriptionField.textColor = NSColor.secondaryLabelColor
        descriptionField.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(descriptionField)
        
        NSLayoutConstraint.activate([
            picView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            picView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            picView.widthAnchor.constraint(equalToConstant: UnitBrowserViewController.picSize),
            picView.heightAnchor.constraint(equalToConstant: UnitBrowserViewController.picSize),
            
            nameField.leadingAnchor.constraint(equalTo: picView.trailingAnchor, constant: 8),
            nameField.topAnchor.constraint(equalTo: picView.topAnchor),
            
            titleField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
            titleField.topAnchor.constraint(equalTo: nameField.bottomAnchor),
            
            descriptionField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
            descriptionField.topAnchor.constraint(equalTo: titleField.bottomAnchor),
            ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var name: String {
        get { return nameField?.stringValue ?? "" }
        set { nameField.stringValue = newValue }
    }
    var title: String {
        get { return titleField?.stringValue ?? "" }
        set { titleField.stringValue = newValue }
    }
    var descriptionText: String {
        get { return descriptionField?.stringValue ?? "" }
        set { descriptionField.stringValue = newValue }
    }
    var buildpic: NSImage? {
        get { return picView.image }
        set { picView.image = newValue }
    }
    
}

struct UnitBrowserSharedState {
    unowned let filesystem: FileSystem
    unowned let textures: ModelTexturePack
    let sides: [SideInfo]
}
extension UnitBrowserSharedState {
    static var empty: UnitBrowserSharedState {
        return UnitBrowserSharedState(filesystem: FileSystem(), textures: ModelTexturePack(), sides: [])
    }
}

class UnitDetailViewController: NSViewController {
    
    var shared = UnitBrowserSharedState.empty
    
    func load(_ unit: UnitInfo) throws {
        tempView.title = unit.object
        let modelFile = try shared.filesystem.openFile(at: "objects3d/" + unit.object + ".3DO")
        let model = try UnitModel(contentsOf: modelFile)
        let scriptFile = try shared.filesystem.openFile(at: "scripts/" + unit.object + ".COB")
        let script = try UnitScript(contentsOf: scriptFile)
        let atlas = UnitTextureAtlas(for: model.textures, from: shared.textures)
        let palette = try Palette.texturePalette(for: unit, in: shared.sides, from: shared.filesystem)
        try tempView.modelView.load(unit, model, script, atlas, shared.filesystem, palette)
        
        //try tempSaveAtlasToFile(atlas, palette)
    }
    
    private func tempSaveAtlasToFile(_ atlas: UnitTextureAtlas, _ palette: Palette) throws {
        let pixelData = atlas.build(from: shared.filesystem, using: palette)
        
        let cfdata = pixelData.withUnsafeBytes { (pixels: UnsafePointer<UInt8>) -> CFData in
            return CFDataCreate(kCFAllocatorDefault, pixels, pixelData.count)
        }
        let image = CGImage(width: atlas.size.width,
                            height: atlas.size.height,
                            bitsPerComponent: 8,
                            bitsPerPixel: 32,
                            bytesPerRow: atlas.size.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: [],
                            provider: CGDataProvider(data: cfdata)!,
                            decode: nil,
                            shouldInterpolate: false,
                            intent: .defaultIntent)
        //let image2 = NSImage(cgImage: image!, size: NSSize(width: atlas.size.width, height: atlas.size.height))
        
        let rep = NSBitmapImageRep(cgImage: image!)
        rep.size = NSSize(width: atlas.size.width, height: atlas.size.height)
        let fileData = rep.representation(using: .png, properties: [:])
        let url2 = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop").appendingPathComponent("test.png")
        try fileData?.write(to: url2, options: .atomic)
    }
    
    private var tempView: TempView { return view as! TempView }
    
    override func loadView() {
        let bounds = NSRect(x: 0, y: 0, width: 480, height: 480)
        let mainView = TempView(frame: bounds)
        
        self.view = mainView
    }
    
    
    private class TempView: NSView {
        
        private unowned let titleLabel: NSTextField
        private unowned let sizeLabel: NSTextField
        private unowned let sourceLabel: NSTextField
        unowned let modelView: UnitView
        
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
            let contentBox = UnitView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
            
            self.titleLabel = titleLabel
            self.sizeLabel = sizeLabel
            self.sourceLabel = sourceLabel
            self.modelView = contentBox
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
    
}
