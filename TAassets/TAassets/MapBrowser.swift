//
//  MapBrowser.swift
//  TAassets
//
//  Created by Logan Jones on 6/4/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa
import SwiftTA_Core

class MapBrowserViewController: NSViewController, ContentViewController {
    
    var shared = TaassetsSharedState.empty
    private var maps: [FileSystem.File] = []
    
    private var tableView: NSTableView!
    private var detailViewContainer: NSView!
    private var detailViewController = MapDetailViewController()
    private var isShowingDetail = false
    
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
            
            if !isShowingDetail {
                let controller = detailViewController
                controller.view.frame = detailViewContainer.bounds
                controller.view.autoresizingMask = [.width, .width]
                addChild(controller)
                detailViewContainer.addSubview(controller.view)
                isShowingDetail = true
            }
            
            do { try detailViewController.loadMap(in: maps[row], from: shared.filesystem) }
            catch { print("!!! Failed to map \(maps[row].name): \(error)") }
        }
        else if isShowingDetail {
            detailViewController.clear()
            detailViewController.view.removeFromSuperview()
            detailViewController.removeFromParent()
            isShowingDetail = false
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
    
    let mapView = MapViewController()
    
    func loadMap(in otaFile: FileSystem.File, from filesystem: FileSystem) throws {
        let name = otaFile.baseName
        try mapView.load(name, from: filesystem)
        mapTitle = name
    }
    
    func clear() {
        mapView.clear()
    }
    
    var mapTitle: String {
        get { return container.titleLabel.stringValue }
        set(new) { container.titleLabel.stringValue = new }
    }
    
    private var container: ContainerView {
        return view as! ContainerView
    }
    
    private class ContainerView: NSView {
        
        unowned let titleLabel: NSTextField
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
            let contentBox = NSView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
            
            self.titleLabel = titleLabel
            self.emptyContentView = contentBox
            super.init(frame: frameRect)
            
            addSubview(contentBox)
            addSubview(titleLabel)
            
            contentBox.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
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
        let container = ContainerView(frame: NSRect(x: 0, y: 0, width: 256, height: 256))
        self.view = container
        
        addChild(mapView)
        container.contentView = mapView.view
    }
    
}
