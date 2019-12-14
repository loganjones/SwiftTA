//
//  FinderView.swift
//  HPIView
//
//  Created by Logan Jones on 11/18/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa


class FinderView<Item: FinderViewItem>: NSView {
    
    typealias Directory = Item.Directory
    
    var createRowView: (_ item: Item, _ tableView: NSTableView) -> NSView? = { (_,_) in return nil }
    var createContentView: (_ item: Item, _ path: [Directory]) -> NSView? = { (_,_) in return nil }

    public var paneWidth: CGFloat = 180
    
    fileprivate let horizontalScrollView: NSScrollView
    fileprivate let tierField: FieldView
    fileprivate var selection: [Int] = []
    fileprivate var tiers = [Tier]()
    fileprivate weak var preview: NSView?
    fileprivate var nibs = [String:NSNib]()
    
    override init(frame frameRect: NSRect) {
        horizontalScrollView = NSScrollView(frame: NSRect(x: 0, y: 0,
                                                          width: frameRect.size.width,
                                                          height: frameRect.size.height))
        tierField = FieldView(frame: NSRect(x: 0, y: 0, width: 200, height: frameRect.size.height))
        super.init(frame: frameRect)
        horizontalScrollView.autoresizingMask = [.width, .height]
        horizontalScrollView.borderType = .noBorder
        horizontalScrollView.hasVerticalScroller = false
        horizontalScrollView.hasHorizontalScroller = true
        addSubview(horizontalScrollView)
        tierField.autoresizingMask = [.height]
        horizontalScrollView.documentView = tierField
    }
    
    required public init?(coder: NSCoder) {
        horizontalScrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        tierField = FieldView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        super.init(coder: coder)
        horizontalScrollView.autoresizingMask = [.width, .height]
        horizontalScrollView.borderType = .noBorder
        horizontalScrollView.hasVerticalScroller = false
        horizontalScrollView.hasHorizontalScroller = true
        horizontalScrollView.frame = NSRect(x: 0, y: 0,
                                            width: bounds.size.width,
                                            height: bounds.size.height)
        tierField.frame = NSRect(x: 0, y: 0, width: 200, height: bounds.size.height)
        tierField.autoresizingMask = [.height]
        addSubview(horizontalScrollView)
        horizontalScrollView.documentView = tierField
    }
    
    override var frame: NSRect {
        didSet {
            if let preview = preview {
                var frame = preview.frame
                let x = endOfTiers
                let widthAvailable = self.frame.width - x
                let width = max(widthAvailable, paneWidth)
                if width != frame.width {
                    frame.size.width = width
                    preview.frame = frame
                    tierField.frame = NSRect(x: 0, y: 0, width: frame.maxX, height: tierField.frame.size.height)
                }
            }
        }
    }
    
    private var endOfTiers: CGFloat {
        guard let tier = tiers.last else { return 0 }
        return tier.frame.maxX
    }
    
    func setRoot(directory: Directory) {
        addTier(for: directory)
    }
    
    func register(_ nib: NSNib?, forIdentifier identifier: String) {
        if let nib = nib {
            nibs[identifier] = nib
        }
        else {
            nibs.removeValue(forKey: identifier)
        }
        tiers.forEach({ $0.tableView.register(nib, forIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier)) })
    }
    
    var selectedItems: [Item] {
        get {
            guard let tier = tiers.last else { return [] }
            let rows = tier.tableView.selectedRowIndexes
            return rows.map({ tier.directory.item(at: $0) })
        }
        set(new) {
            guard let tier = tiers.last else { return }
            guard !new.isEmpty else { tier.tableView.deselectAll(nil); return }
            let rows = new.compactMap({ tier.directory.index(of: $0) })
            tier.tableView.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)
        }
    }
    
//    var selectedPath: [FinderViewItem] {
//        get {
//            let tierPath = tiers.map({ $0.directory as FinderViewItem }).dropFirst()
//            guard let selected = selectedItems.last else { return Array(tierPath) }
//            return Array(tierPath) + [selected]
//        }
//    }
    
    
    func selectPath(string: String) {
        var identifiers = string.components(separatedBy: "/")
        if identifiers.first == "" { identifiers.removeFirst() }
        self.select(pathIdentifiers: identifiers)
    }
    
    private func select(pathIdentifiers identifiers: [String]) {
        for (index, identifier) in identifiers.enumerated() {
            if !select(identifier: identifier, inTierWithIndex: index) {
                break
            }
        }
    }
    
    private func select(identifier: String, inTierWithIndex tierIndex: Int) -> Bool {
        
        guard tierIndex >= 0 && tierIndex < tiers.count else { return false }
        let tier = tiers[tierIndex]
        
        if let itemIndex = tier.directory.index(where: { $0.name == identifier }) {
            tier.tableView.selectRowIndexes([itemIndex], byExtendingSelection: false)
            tier.tableView.scrollRowToVisible(itemIndex)
            let item = tier.directory.item(at: itemIndex)
            handleSelection(of: item, in: tier)
            return true
        }
        else {
            return false
        }
    }
    
    fileprivate func addTier(for directory: Directory) {
        let frame = NSRect(x: 0, y: 0, width: paneWidth, height: tierField.bounds.size.height)
        let tier = Tier(directory: directory, frame: frame, in: self)
        tierField.addSubview(tier)
        tiers = [tier]
    }
    
    fileprivate func addTier(for directory: Directory, after parent: Tier) {
        
        guard let parentIndex = tiers.firstIndex(of: parent) else { return }
        
        let new = tiers.prefix(through: parentIndex)
        let dropped = tiers.suffix(from: parentIndex+1)
        dropped.forEach({ $0.removeFromSuperview() })
        tiers = Array(new)
        
        let frame = NSRect(x: endOfTiers, y: 0, width: paneWidth, height: tierField.bounds.size.height)
        let tier = Tier(directory: directory, frame: frame, in: self)
        
        tierField.frame = NSRect(x: 0, y: 0, width: frame.maxX, height: tierField.frame.size.height)
        tierField.addSubview(tier)
        tiers.append(tier)
        
        preview?.removeFromSuperview()
    }
    
    fileprivate func clear(after tier: Tier) {
        guard let index = tiers.firstIndex(of: tier) else { return }
        let new = tiers.prefix(through: index)
        let dropped = tiers.suffix(from: index+1)
        dropped.forEach({ $0.removeFromSuperview() })
        tiers = Array(new)
        preview?.removeFromSuperview()
        tierField.frame = NSRect(x: 0, y: 0, width: tier.frame.maxX, height: tierField.frame.size.height)
    }
    
    fileprivate func showPreview(for item: Item, in tier: Tier, path: [Directory]) {
        if let view = createContentView(item, path) {
            let x = endOfTiers
            let widthAvailable = self.frame.width - x
            let width = max(widthAvailable, paneWidth)
            let frame = NSRect(x: x, y: 0, width: width, height: tierField.bounds.size.height)
            view.frame = frame
            tierField.frame = NSRect(x: 0, y: 0, width: frame.maxX, height: tierField.frame.size.height)
            tierField.addSubview(view)
            preview = view
        }
    }
    
    fileprivate func path(upTo tier: Tier) -> [Directory] {
        guard let index = tiers.firstIndex(of: tier) else { return [] }
        return tiers[0...index].map({ $0.directory })
    }
    
    fileprivate func handleSelection(of item: Item, in tier: Tier) {
        let path = self.path(upTo: tier)
        if item.isExpandable(path: path),
            let subdirectory = item.expand(path: path) {
            addTier(for: subdirectory, after: tier)
        }
        else {
            clear(after: tier)
            showPreview(for: item, in: tier, path: path)
        }
    }
    
    fileprivate func handleDeselection(in tier: Tier) {
        clear(after: tier)
    }
    
    fileprivate class FieldView: NSView {
        
    }
    
    /**
     A custom NSScrollView subclass for the tiers.
     This subclass intercepts scroll gestures to filter out horizontal scrolls
     and pass them down the responder chain where they should be picked up
     by the enclosing NSScrollView of the FinderView.
     */
    fileprivate class TierScrollView: NSScrollView {
        var currentScrollIsVertical = false
        
        fileprivate override func scrollWheel(with event: NSEvent) {
            
            // Adapted from:
            // http://stackoverflow.com/questions/8623785/nsscrollview-inside-another-nsscrollview
            
            /* Ensure that both scrollbars are flashed when the user taps trackpad with two fingers */
            if event.phase == .mayBegin {
                super.scrollWheel(with: event)
                self.nextResponder?.scrollWheel(with: event)
                return
            }
            
            /* Check the scroll direction only at the beginning of a gesture for modern scrolling devices */
            /* Check every event for legacy scrolling devices */
            if event.phase == .began || (event.phase == [] && event.momentumPhase == []) {
                currentScrollIsVertical = abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX)
            }
            if currentScrollIsVertical {
                super.scrollWheel(with: event)
            }
            else {
                self.nextResponder?.scrollWheel(with: event)
            }
        }
        
    }
    
    fileprivate class Tier: NSView, NSTableViewDataSource, NSTableViewDelegate {
        
        let directory: Directory
        unowned var finder: FinderView<Item>
        unowned let scrollView: TierScrollView
        unowned let tableView: NSTableView
        
        init(directory dir: Directory, frame: NSRect, in finder: FinderView<Item>) {
            
            let scrollView = TierScrollView(frame: NSMakeRect(0, 0, frame.size.width-1, frame.size.height))
            scrollView.autoresizingMask = [.height]
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            
            let tableView = NSTableView(frame: NSMakeRect(0, 0, frame.size.width-1, frame.size.height))
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
            column.width = frame.size.width-2
            tableView.addTableColumn(column)
            tableView.identifier = NSUserInterfaceItemIdentifier(rawValue: dir.name)
            tableView.headerView = nil
            finder.nibs.forEach({ tableView.register($0.value, forIdentifier: NSUserInterfaceItemIdentifier(rawValue: $0.key)) })
            
            scrollView.documentView = tableView
            
            directory = dir
            self.finder = finder
            self.scrollView = scrollView
            self.tableView = tableView
            super.init(frame: frame)
            
            self.autoresizingMask = [.height]
            
            tableView.dataSource = self
            tableView.delegate = self
            addSubview(scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func draw(_ dirtyRect: NSRect) {
            NSColor(white: 0.8, alpha: 1).setStroke()
            let edgeX = bounds.maxX - 0.5
            let path = NSBezierPath()
            path.move(to: NSPoint(x: edgeX, y: bounds.minY))
            path.line(to: NSPoint(x: edgeX, y: bounds.maxY))
            path.lineWidth = 1
            path.stroke()
        }
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return directory.numberOfItems
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let item = directory.item(at: row)
            let view = finder.createRowView(item, tableView)
            return view
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView
                else { return }
            let row = tableView.selectedRow
            if row >= 0 {
                let item = directory.item(at: row)
                finder.handleSelection(of: item, in: self)
            }
            else {
                finder.handleDeselection(in: self)
            }
        }
        
    }
    
}

protocol FinderViewItem {
    associatedtype Directory: FinderViewDirectory where Directory.Item == Self
    var name: String { get }
    func isExpandable(path: [Directory]) -> Bool
    func expand(path: [Directory]) -> Directory?
}

protocol FinderViewDirectory {
    associatedtype Item: FinderViewItem where Item.Directory == Self
    var name: String { get }
    var numberOfItems: Int { get }
    func item(at index: Int) -> Item
    func index(of item: Item) -> Int?
    func index(where: (Item) -> Bool) -> Int?
}

extension FinderViewItem {
    func isExpandable(path: [Directory]) -> Bool {
        return expand(path: path) != nil
    }
}
