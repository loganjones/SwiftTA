//
//  Document.swift
//  HPIView
//
//  Created by Logan Jones on 9/12/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa
import Quartz
import QuickLook


class Document: NSDocument {
    
    var root: HPIItem?

    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }
    
    override func makeWindowControllers() {
        let controller = HPIBrowserWindowController(windowNibName: "Document")
        addWindowController(controller)
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        
        do {
            root = try HPIItem(withContentsOf: url)
        }
        catch {
            Swift.print("ERROR: \(error)")
            throw NSError(domain: NSOSStatusErrorDomain, code: readErr, userInfo: nil)
        }
        
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        //throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }


}

// MARK:- Browser Window

class HPIBrowserWindowController: NSWindowController {
    
    @IBOutlet weak var fileTreeView: NSOutlineView?
    @IBOutlet weak var previewView: NSView!
    @IBOutlet weak var quicklookView: QLPreviewView?
    @IBOutlet weak var contentAttributesView: NSView!
    @IBOutlet weak var contentTitleField: NSTextField!
    @IBOutlet weak var contentSizeField: NSTextField!
    
    let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    
    var hpiDocument: Document {
        guard let doc = self.document as? Document
            else { fatalError("No HPI Document associated with this window!?") }
        return doc
    }
    
}

extension HPIBrowserWindowController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return hpiDocument.root?.numberOfChildren ?? 0
        }
        else {
            guard let hpi = item as? HPIItem
                else { return 0 }
            return hpi.numberOfChildren
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let hpi: HPIItem
        if item == nil {
            if let good = hpiDocument.root { hpi = good } else { fatalError("Bad Root Item") }
        }
        else {
            if let good = item as? HPIItem { hpi = good } else { fatalError("Bad HPI Item") }
        }
        switch hpi {
        case .file: fatalError("Bad HPI Item")
        case .directory(_, let items): return items[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let hpi = item as? HPIItem else { fatalError("Bad HPI Item") }
        return hpi.numberOfChildren > 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        
        pasteboard.declareTypes([NSFilesPromisePboardType], owner: nil)
        pasteboard.setPropertyList(["txt"], forType: NSFilesPromisePboardType)
        
        return true
        
    }
    
}

extension HPIBrowserWindowController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let hpi = item as? HPIItem else { fatalError("Bad HPI Item") }
        
        switch tableColumn?.identifier {
            
        case .some("FileColumn"):
            let view = outlineView.make(withIdentifier: "FileCell", owner: self) as? NSTableCellView
            view?.textField?.stringValue = hpi.name
            return view
            
        case .some("SizeColumn"):
            let view = outlineView.make(withIdentifier: "SizeCell", owner: self) as? NSTableCellView
            switch hpi {
            case .file(let properties): view?.textField?.stringValue = sizeFormatter.string(fromByteCount: Int64(properties.size))
            case .directory: view?.textField?.stringValue = ""
            }
            return view
            
        default:
            return nil
            
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, namesOfPromisedFilesDroppedAtDestination dropDestination: URL, forDraggedItems items: [Any]) -> [String] {
    
        return ["Foo"]
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView
            else { return }
        outlineView.selectedRowIndexes.forEach {
            let indexPath = outlineView.indexPath(forRow: $0)
            Swift.print("Selected Path: \(outlineView.hpiPath(for: indexPath))")
        }
        let selectedRows = outlineView.selectedRowIndexes
        let selected = selectedRows.flatMap({ outlineView.item(atRow: $0) as? HPIItem })
        switch selected.count {
        case 0: clearPreview()
        case 1:
            switch selected[0] {
            case .file:
                let indexPath = outlineView.indexPath(forRow: selectedRows.first ?? 0)
                preview(file: selected[0], hpiPath: outlineView.hpiPath(for: indexPath))
            case .directory: clearPreview()
            }
        default: clearPreview()
        }
    }
    
}

extension HPIBrowserWindowController {
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(extract) {
            return (fileTreeView?.selectedRowIndexes.count ?? 0) > 0
        }
        return true
    }
    
    @IBAction func extract(sender: Any?) {
        
        let items = selectedItems()
        guard items.count > 0
            else { Swift.print("No selected items to extract."); return }
        
        guard let window = hpiDocument.windowForSheet
            else { Swift.print("Document has no windowForSheet."); return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.beginSheetModal(for: window) {
            switch $0 {
            case NSFileHandlingPanelOKButton:
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
    
    func selectedItems() -> [HPIItem] {
        guard let tree = fileTreeView else { return [] }
        return tree.selectedRowIndexes.flatMap({ tree.item(atRow: $0) as? HPIItem })
    }
    
    func extractItems(_ items: [HPIItem], to rootDirectory: URL) {
        
        for item in items {
            
            switch item {
            case .file(let file):
                do {
                    let fileURL = rootDirectory.appendingPathComponent(file.name)
                    let data = try HPIItem.extract(item: item, fromFile: hpiDocument.fileURL!)
                    try data.write(to: fileURL, options: [.atomic])
                }
                catch {
                    Swift.print("Failed to write \(file.name) to file: \(error)")
                }
                
            case .directory(let name, let children):
                do {
                    let directoryURL = rootDirectory.appendingPathComponent(name)
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                    extractItems(children, to: directoryURL)
                }
                catch {
                    Swift.print("Failed to create directory \(name): \(error)")
                }
            }
            
        }
        
    }
}

extension HPIBrowserWindowController {
    
    func clearPreview() {
        contentAttributesView.isHidden = true
        previewView.isHidden = true
    }
    
    func preview(file: HPIItem, hpiPath: String) {
        guard case .file(let properties) = file else { return }
        contentAttributesView.isHidden = false
        contentTitleField.stringValue = properties.name
        contentSizeField.stringValue = sizeFormatter.string(fromByteCount: Int64(properties.size))
        
        guard let archiveURL = hpiDocument.fileURL
            else { return }
        let archiveIdentifier = String(format: "%08X", archiveURL.hashValue)
        
        guard let cachesURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            else { return }
        
        let archiveContainerURL = cachesURL
            .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
            .appendingPathComponent(archiveIdentifier, isDirectory: true)
        try? FileManager.default.createDirectory(at: archiveContainerURL, withIntermediateDirectories: true)
        Swift.print("archiveContainer: \(archiveContainerURL)")
        
        let fileURL = archiveContainerURL.appendingPathComponent(hpiPath, isDirectory: false)
        let fileDirectoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: fileDirectoryURL, withIntermediateDirectories: true)
        let data = try? HPIItem.extract(item: file, fromFile: hpiDocument.fileURL!)
        try? data?.write(to: fileURL, options: [.atomic])
        
        let qlv = quicklookView ?? makeQuicklookView()
        qlv.previewItem = fileURL as NSURL
        previewView.isHidden = false
        qlv.refreshPreviewItem()
    }
    
    func makeQuicklookView() -> QLPreviewView {
        let previewView = self.previewView!
        let qlv = QLPreviewView(frame: previewView.bounds, style: .compact)!
        
        previewView.addSubview(qlv)
        
        qlv.leadingAnchor.constraint(equalTo: previewView.leadingAnchor).isActive = true
        qlv.trailingAnchor.constraint(equalTo: previewView.trailingAnchor).isActive = true
        qlv.topAnchor.constraint(equalTo: previewView.topAnchor).isActive = true
        qlv.bottomAnchor.constraint(equalTo: previewView.bottomAnchor).isActive = true
        
        quicklookView = qlv
        return qlv
    }
    
    func path(forItem item: HPIItem) -> String {
        guard let outlineView = fileTreeView else { return "" }
        
        if let parent = outlineView.parent(forItem: item) as? HPIItem {
            return path(forItem: parent) + "/" + item.name
        }
        else {
            return "/" + item.name
        }
    }
    
}

extension NSOutlineView {
    
    func hpiPath(for indexPath: IndexPath) -> String {
        return "/" + indexPath
            .map({ (self.item(atRow: $0) as? HPIItem)?.name ?? "??" })
            .joined(separator: "/")
    }
    
    func parentRow(forRow row: Int) -> Int {
        let rowLevel = self.level(forRow: row)
        var r = row - 1
        var l = self.level(forRow: r)
        while (r >= 0 && l >= rowLevel) {
            r -= 1
            l = self.level(forRow: r)
        }
        return r
    }
    
    func indexPath(forRow row: Int) -> IndexPath {
        var path = [Int]()
        var i = row
        while (i >= 0) {
            path.append(i)
            i = self.parentRow(forRow: i)
        }
        return IndexPath(indexes: path.reversed())
    }
    
}

fileprivate extension HPIItem {
    
    var numberOfChildren: Int {
        switch self {
        case .file: return 0
        case .directory(_, let items): return items.count
        }
    }
    
}
