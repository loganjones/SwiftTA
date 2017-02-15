//
//  UnitBrowser.swift
//  TAassets
//
//  Created by Logan Jones on 1/22/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa


class UnitBrowserViewController: NSViewController, ContentViewController {
    
    var filesystem = TaassetsFileSystem()
    fileprivate var units: [UnitInfo] = []
    
    fileprivate var tableView: NSTableView!
    fileprivate var detailViewContainer: NSView!
    fileprivate var detailViewController: UnitDetailViewController?
    
    static let picSize: CGFloat = 64
    
    override func loadView() {
        let bounds = NSRect(x: 0, y: 0, width: 480, height: 480)
        let mainView = NSView(frame: bounds)
        
        let listWidth: CGFloat = 240
        
        let scrollView = NSScrollView(frame: NSMakeRect(0, 0, listWidth, bounds.size.height))
        scrollView.autoresizingMask = [.viewHeightSizable]
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        
        let tableView = NSTableView(frame: NSMakeRect(0, 0, listWidth, bounds.size.height))
        let column = NSTableColumn(identifier: "name")
        column.width = listWidth-2
        tableView.addTableColumn(column)
        tableView.identifier = "units"
        tableView.headerView = nil
        tableView.rowHeight = UnitBrowserViewController.picSize
        
        scrollView.documentView = tableView
        
        tableView.dataSource = self
        tableView.delegate = self
        mainView.addSubview(scrollView)
        
        let detail = NSView(frame: NSMakeRect(listWidth, 0, bounds.size.width - listWidth, bounds.size.height))
        detail.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        mainView.addSubview(detail)
        
        self.view = mainView
        self.detailViewContainer = detail
        self.tableView = tableView
    }
    
    override func viewDidLoad() {
        let unitsDirectory = filesystem.root[directory: "units"] ?? Asset.Directory()
        let units = unitsDirectory.items
            .flatMap { $0.fileAsset() }
            .filter { $0.hasExtension("fbi") }
            .flatMap { try? filesystem.urlForFile($0, at: "units/" + $0.name) }
            .map { UnitInfo(withContentsOf: $0) }
        self.units = units
    }
    
    final func buildpic(for unitName: String) -> NSImage? {
        guard let url = try? filesystem.urlForFile(at: "unitpics/" + unitName + ".PCX")
            else { return nil }
        return try? NSImage(pcxContentsOf: url)
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
        if let existing = tableView.make(withIdentifier: "UnitInfo", owner: self) as? UnitInfoCell {
            cell = existing
            print("Cell Reuse!")
        }
        else {
            cell = UnitInfoCell()
            cell.identifier = "UnitInfo"
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
            controller.view.autoresizingMask = [.viewWidthSizable, .viewWidthSizable]
            detailViewContainer.addSubview(controller.view)
            detailViewController = controller
            controller.filesystem = filesystem
            controller.unit = units[row]
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

private extension Asset {
    
    func fileAsset() -> Asset.File? {
        switch self {
        case .file(let f): return f
        default: return nil
        }
    }
    
}

private extension Asset.File {
    
    func hasExtension(_ ext: String) -> Bool {
        return (name as NSString).pathExtension.caseInsensitiveCompare(ext) == .orderedSame
    }
    
}

struct UnitInfo {
    var name: String = ""
    var side: String = ""
    var object: String = ""
    
    var title: String = ""
    var description: String = ""
    
    var categories: Set<String> = []
    var tedClass: String = ""
}

extension UnitInfo {
    
    init(withContentsOf fileUrl: URL) {
        UnitInfo.processFbi(at: fileUrl) { field, value in
            switch field {
            case "UnitName":
                name = value
            case "Side":
                side = value
            case "Objectname":
                object = value
            case "Name":
                title = value
            case "Description":
                description = value
            case "Category":
                categories = Set(value.components(separatedBy: " "))
            case "TEDClass":
                tedClass = value
            default:
                () // Unhandled field
            }
        }
    }
    
    static func processFbi(at fileUrl: URL, item: (String, String) -> Void) {
        
        var encoding = String.Encoding.ascii
        guard let contents = try? String(textContentsOf: fileUrl, usedEncoding: &encoding)
            else { return }
        
        let scanner = Scanner(string: contents)
        //scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "\r\n\t=;{}")
        
        scanner.scanUpTo("[UNITINFO]", into: nil)
        scanner.scanUpTo("{", into: nil)
        
        while !scanner.isAtEnd {
            var field: NSString?
            var value: NSString?
            scanner.scanUpTo("=", into: &field)
            scanner.scanUpTo(";", into: &value)
            
            if let field = field as? String, let value = value as? String {
                item(field, value)
            }
        }
        
    }
    
}

extension String {
    
    init(textContentsOf url: URL, usedEncoding inoutEncoding: inout String.Encoding) throws {
        do {
            try self.init(contentsOf: url, usedEncoding: &inoutEncoding)
        }
        catch {
            let cocoaError = error as NSError
            if cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSFileReadUnknownStringEncodingError {
                do {
                    try self.init(contentsOf: url, encoding: .utf8)
                    inoutEncoding = .utf8
                }
                catch {
                    do {
                        try self.init(contentsOf: url, encoding: .ascii)
                        inoutEncoding = .ascii
                    }
                    catch {
                        throw error
                    }
                }
            }
            else {
                throw error
            }
        }
    }
    
}

class UnitDetailViewController: NSViewController {
    
    var filesystem = TaassetsFileSystem()
    
    var unit: UnitInfo? {
        didSet {
            if let unit = unit {
                tempView.title = unit.object
                let modelUrl = try! filesystem.urlForFile(at: "objects3d/" + unit.object + ".3DO")
                try! tempView.modelView.loadModel(contentsOf: modelUrl)
            }
            else {
                
            }
        }
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
        unowned let modelView: Model3DOView
        
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
            let contentBox = Model3DOView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
            
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
