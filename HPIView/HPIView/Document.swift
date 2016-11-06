//
//  Document.swift
//  HPIView
//
//  Created by Logan Jones on 9/12/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

import Cocoa

class Document: NSDocument {
    
    var root: HPIItem?
    @IBOutlet weak var fileTreeView: NSOutlineView?
    
    let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

    override var windowNibName: String? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return "Document"
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

extension Document: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return root?.numberOfChildren ?? 0
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
            if let good = root { hpi = good } else { fatalError("Bad Root Item") }
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

extension Document: NSOutlineViewDelegate {
    
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
    
}

extension Document {
    
    @IBAction func selectBrowserItem(sender: Any?) {
        guard let browser = sender as? NSBrowser else { return }
        let col = browser.selectedColumn
        let rows = browser.selectedRowIndexes(inColumn: col)
        Swift.print("selected [ \(col), \(rows) ]")
    }
    
    @IBAction func invokeBrowserItem(sender: Any?) {
        guard let browser = sender as? NSBrowser else { return }
        let col = browser.selectedColumn
        let rows = browser.selectedRowIndexes(inColumn: col)
        Swift.print("invoked [ \(col), \(rows) ]")
    }
    
    @IBAction func extract(sender: Any?) {
        
        let items = selectedItems()
        guard items.count > 0
            else { Swift.print("No selected items to extract."); return }
        
        guard let window = windowForSheet
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
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(extract) {
            return (fileTreeView?.selectedRowIndexes.count ?? 0) > 0
        }
        return true
    }
    
    func extractItems(_ items: [HPIItem], to rootDirectory: URL) {
        
        for item in items {
            
            switch item {
            case .file(let file):
                do {
                    let fileURL = rootDirectory.appendingPathComponent(file.name)
                    let data = try HPIItem.extract(item: item, fromFile: self.fileURL!)
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

extension Document {
    
    func selectedItems() -> [HPIItem] {
        guard let tree = fileTreeView else { return [] }
        return tree.selectedRowIndexes.flatMap({ tree.item(atRow: $0) as? HPIItem })
    }
    
}

class FooWriter: NSObject {
    
    var name = "Foo"
    
}

extension FooWriter: NSPasteboardWriting {
    
    func writableTypes(for pasteboard: NSPasteboard) -> [String] {
        print("writableTypes")
        //return [ kUTTypeData as String ]
        return [ kUTTypeText as String ]
    }
    
    func pasteboardPropertyList(forType type: String) -> Any? {
        print("pasteboardPropertyList(forType: \(type))")
        if let data = "Hello \(name)!".data(using: .utf8) {
            return data as NSData
        }
        else {
            return nil
        }
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
