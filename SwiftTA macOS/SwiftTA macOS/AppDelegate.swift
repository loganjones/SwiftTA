//
//  AppDelegate.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}

class MainWindowController: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        startLoading()
    }
    
    func startLoading() {
        DispatchQueue(label: "Loading").async {
            do {
                guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw RuntimeError("No Documents directory?!")
                }
                
                let taDir = try URL(resolvingAliasFileAt: documents.appendingPathComponent("Total Annihilation", isDirectory: true))
                let state = try GameState(loadFrom: taDir, mapName: "Coast to Coast")
//                let state = try GameState(loadFrom: taDir, mapName: "Dark Side")
//                let state = try GameState(loadFrom: taDir, mapName: "Great Divide")
//                let state = try GameState(loadFrom: taDir, mapName: "King of the Hill")
//                let state = try GameState(loadFrom: taDir, mapName: "Ring Atoll")
//                let state = try GameState(loadFrom: taDir, mapName: "Two Continents")
                
//                let taDir = try URL(resolvingAliasFileAt: documents.appendingPathComponent("Total Annihilation Kingdoms", isDirectory: true))
//                let state = try GameState(loadFrom: taDir, mapName: "Athri Cay")
//                let state = try GameState(loadFrom: taDir, mapName: "Black Heart Jungle")
//                let state = try GameState(loadFrom: taDir, mapName: "The Old Riverbed")
//                let state = try GameState(loadFrom: taDir, mapName: "Two Castles")
                
                DispatchQueue.main.async {
                    self.proceedWithLoaded(state)
                }
            }
            catch {
                print("Loading phase failed with error: \(error)")
            }
        }
    }
    
    func proceedWithLoaded(_ state: GameState) {
        let vc = GameViewController(state)
        self.contentViewController = vc
    }
    
}

class LoadingViewController: NSViewController {
    
    @IBOutlet weak var loadingIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadingIndicator.usesThreadedAnimation = true
        loadingIndicator.startAnimation(nil)
    }
    
}
