//
//  QuickLookView.swift
//  TAassets
//
//  Created by Logan Jones on 7/2/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation
import Quartz
import SwiftTA_Core

class QuickLookViewController: NSViewController {
    
    private weak var quicklook: QLPreviewView?
    private var tempFileUrl: URL?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
    }
    
    deinit {
        deleteTempFile()
    }
    
    func load<File>(contentsOf file: File) throws
        where File: FileReadHandle
    {
        deleteTempFile()
        
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileDirectory = tempDirectory.appendingPathComponent("TA-QLV", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempFileDirectory, withIntermediateDirectories: false, attributes: nil)
        
        let tempFileUrl = tempDirectory.appendingPathComponent(file.fileName, isDirectory: false)
        let data = file.readDataToEndOfFile()
        try data.write(to: tempFileUrl)
        self.tempFileUrl = tempFileUrl
        
        guard let ql = QLPreviewView(frame: view.bounds, style: .compact) else { return }
        ql.autoresizingMask = [.width, .height]
        ql.previewItem = tempFileUrl as NSURL
        ql.refreshPreviewItem()
        
        quicklook?.removeFromSuperview()
        view.addSubview(ql)
        quicklook = ql
    }
    
    private func deleteTempFile() {
        if let url = tempFileUrl {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
}
