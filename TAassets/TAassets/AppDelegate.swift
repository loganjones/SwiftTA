//
//  AppDelegate.swift
//  TAassets
//
//  Created by Logan Jones on 1/15/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    override init() {
        super.init()
        TaassetsDocumentController.shared()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

