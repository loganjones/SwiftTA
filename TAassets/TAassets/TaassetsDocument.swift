//
//  Document.swift
//  TAassets
//
//  Created by Logan Jones on 1/15/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa

class TaassetsDocument: NSDocument {

    var filesystem: FileSystem!
    var sides: [SideInfo] = []

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Document Window Controller")) as! NSWindowController
        let viewController = windowController.contentViewController as! TaassetsViewController
        viewController.shared = TaassetsSharedState(filesystem: filesystem, sides: sides)
        self.addWindowController(windowController)
    }
    
    override func read(from directoryURL: URL, ofType typeName: String) throws {
        
        let fm = FileManager.default
        var dirCheck: ObjCBool = false
        guard directoryURL.isFileURL, fm.fileExists(atPath: directoryURL.path, isDirectory: &dirCheck), dirCheck.boolValue
            else { throw NSError(domain: NSOSStatusErrorDomain, code: readErr, userInfo: nil) }
        
        let begin = Date()
        filesystem = try! FileSystem(from: directoryURL)
        let end = Date()
        Swift.print("\(directoryURL.lastPathComponent) filesystem load time: \(end.timeIntervalSince(begin)) seconds")
        
        let sidedata = try filesystem.openFile(at: "gamedata/sidedata.tdf")
        sides = try SideInfo.load(contentsOf: sidedata)
    }

}

class TaassetsDocumentController: NSDocumentController {
    
    override func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { result in
            guard result == .OK else { return }
            guard let selectedURL = panel.urls.first else { return }
            self.openDocument(withContentsOf: selectedURL, display: true) { (document, wasOpened, error) in
                if let document = document {
                    print("opened document: \(document)")
                }
                else if let error = error {
                    print("error opening document: \(error)")
                }
            }
        }
    }
    
}


// MARK: - View

struct TaassetsSharedState {
    unowned let filesystem: FileSystem
    let sides: [SideInfo]
}
extension TaassetsSharedState {
    static var empty: TaassetsSharedState {
        return TaassetsSharedState(filesystem: FileSystem(), sides: [])
    }
}

class TaassetsViewController: NSViewController {
    
    var shared: TaassetsSharedState!
    
    @IBOutlet var unitsButton: NSButton!
    @IBOutlet var weaponsButton: NSButton!
    @IBOutlet var mapsButton: NSButton!
    @IBOutlet var filesButton: NSButton!
    @IBOutlet var contentView: NSView!
    
    private var selectedViewController: ContentViewController?
    private var selectedButton: NSButton?
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // There will be nothing selected the first time this view appears.
        // Select a default in this case.
        if selectedButton == nil {
            unitsButton.state = .on
            didChangeSelection(unitsButton)
        }
    }
    
    @IBAction func didChangeSelection(_ sender: NSButton) {
        
        // Disallow deselcetion (toggling).
        // A selected button can only be deselected by selecting something else.
        guard sender.state == .on, !(sender === selectedButton) else {
            sender.state = .on
            return
        }
        
        selectedButton?.state = .off
        selectedButton = sender
        showSelectedContent(for: sender)
    }
    
    func showSelectedContent(for button: NSButton) {
        switch button {
        case unitsButton:
            showSelectedContent(controller: UnitBrowserViewController())
        case weaponsButton:
            showSelectedContent(controller: EmptyContentViewController())
        case mapsButton:
            showSelectedContent(controller: MapBrowserViewController())
        case filesButton:
            showSelectedContent(controller: FileBrowserViewController())
        default:
            print("Unknown content button: \(button)")
        }
    }
    
    func showSelectedContent<T: ContentViewController>(controller: T) {
        selectedViewController?.view.removeFromSuperview()
        
        controller.shared = shared
        controller.view.frame = contentView.bounds
        controller.view.autoresizingMask = [.width, .height]
        contentView.addSubview(controller.view)
        selectedViewController = controller
    }
    
}

protocol ContentViewController: class {
    var view: NSView { get }
    var shared: TaassetsSharedState { get set }
}

class EmptyContentViewController: NSViewController, ContentViewController {
    
    var shared = TaassetsSharedState.empty
    
    override func loadView() {
        let mainView = NSView()
        
        let label = NSTextField(labelWithString: "Empty")
        label.translatesAutoresizingMaskIntoConstraints = false
        mainView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: mainView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: mainView.centerYAnchor),
            ])
        
        self.view = mainView
    }
    
}
