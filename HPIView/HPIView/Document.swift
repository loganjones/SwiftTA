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
    @IBOutlet weak var browser: NSBrowser?

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

extension Document: NSBrowserDelegate {
    
    func rootItem(for browser: NSBrowser) -> Any? {
        return root
    }
    
    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        guard let hpi = item as? HPIItem else { return 0 }
        switch hpi {
        case .file: return 0
        case .directory(_, let items): return items.count
        }
    }
    
    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        guard let hpi = item as? HPIItem else { fatalError("Bad HPI Item") }
        switch hpi {
        case .file: fatalError("Bad HPI Item")
        case .directory(_, let items): return items[index]
        }
    }
    
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        guard let hpi = item as? HPIItem else { return true }
        switch hpi {
        case .file: return true
        case .directory: return false
        }
    }
    
    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        guard let hpi = item as? HPIItem else { return "!?!" }
        switch hpi {
        case .file(let name): return name
        case .directory(let name, _): return name
        }
    }
    
    func browser(_ browser: NSBrowser, writeRowsWith rowIndexes: IndexSet, inColumn column: Int, to pasteboard: NSPasteboard) -> Bool {
        Swift.print("browser:writeRowsWith:inColumn:to:")
        
        //pasteboard.declareTypes([NSFileContentsPboardType], owner: self)
        
        //pasteboard.clearContents()
        //pasteboard.writeObjects([FooWriter()])
        
        pasteboard.declareTypes([NSFilesPromisePboardType], owner: self)
        pasteboard.setPropertyList(["txt"], forType: NSFilesPromisePboardType)
        
        return true
    }
    
    func browser(_ browser: NSBrowser, namesOfPromisedFilesDroppedAtDestination dropDestination: URL, forDraggedRowsWith rowIndexes: IndexSet, inColumn column: Int) -> [String] {
        Swift.print("browser:namesOfPromisedFilesDropped(atDestination: \(dropDestination))")
        return ["test.txt"]
    }
    
//    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
//        Swift.print("namesOfPromisedFilesDropped(atDestination: \(dropDestination))")
//        return ["test.txt"]
//    }
    
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
        
    }
    
    @IBAction func extractAll(sender: Any?) {
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(extract) {
            return (browser?.selectionIndexPaths.count ?? 0) > 0
        }
        return true
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
