//
//  MapBrowser.swift
//  TAassets
//
//  Created by Logan Jones on 6/4/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa

class MapBrowserViewController: NSViewController, ContentViewController {
    
    var shared = TaassetsSharedState.empty
    fileprivate var maps: [FileSystem.File] = []
    
    fileprivate var tableView: NSTableView!
    fileprivate var detailViewContainer: NSView!
    fileprivate var detailViewController: MapDetailViewController?
    
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
        tableView.identifier = NSUserInterfaceItemIdentifier(rawValue: "maps")
        tableView.headerView = nil
        tableView.rowHeight = 32
        
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
        let mapsDirectory = shared.filesystem.root[directory: "maps"] ?? FileSystem.Directory()
        let maps = mapsDirectory.items
            .compactMap { $0.asFile() }
            .filter { $0.hasExtension("ota") }
            .sorted { FileSystem.sortNames($0.name, $1.name) }
        self.maps = maps
        let end = Date()
        print("Map list load time: \(end.timeIntervalSince(begin)) seconds")
    }
    
}

extension MapBrowserViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return maps.count
    }
    
}

extension MapBrowserViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell: MapInfoCell
        if let existing = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MapInfo"), owner: self) as? MapInfoCell {
            cell = existing
        }
        else {
            cell = MapInfoCell()
            cell.identifier = NSUserInterfaceItemIdentifier(rawValue: "MapInfo")
        }
        
        let file = maps[row]
        cell.name = file.baseName
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView
            else { return }
        let row = tableView.selectedRow
        if row >= 0 {
            detailViewController?.view.removeFromSuperview()
            
            let controller = MapDetailViewController()
            controller.view.frame = detailViewContainer.bounds
            controller.view.autoresizingMask = [.width, .width]
            detailViewContainer.addSubview(controller.view)
            detailViewController = controller
            try? controller.loadMap(in: maps[row], from: shared.filesystem)
        }
        else {
            detailViewController?.view.removeFromSuperview()
            detailViewController = nil
        }
    }
    
}

class MapInfoCell: NSTableCellView {
    
    private var nameField: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        nameField = NSTextField(labelWithString: "")
        nameField.font = NSFont.systemFont(ofSize: 14)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(nameField)
        
        NSLayoutConstraint.activate([
            nameField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            nameField.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var name: String {
        get { return nameField?.stringValue ?? "" }
        set { nameField.stringValue = newValue }
    }
    
}

class MapDetailViewController: NSViewController {
    
    private var tempView: TempView { return view as! TempView }
    
    override func loadView() {
        let bounds = NSRect(x: 0, y: 0, width: 480, height: 480)
        let mainView = TempView(frame: bounds)
        
        self.view = mainView
    }
    
    func loadMap(in otaFile: FileSystem.File, from filesystem: FileSystem) throws {
        let name = otaFile.baseName
        tempView.title = name
        try tempView.mapView.load(name, from: filesystem)
    }
    
    private class TempView: NSView {
        
        private unowned let titleLabel: NSTextField
        private unowned let sizeLabel: NSTextField
        private unowned let sourceLabel: NSTextField
        unowned let mapView: MapView
        
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
            let contentBox = MapView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
            
            self.titleLabel = titleLabel
            self.sizeLabel = sizeLabel
            self.sourceLabel = sourceLabel
            self.mapView = contentBox
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
