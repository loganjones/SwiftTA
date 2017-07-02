//
//  QuickLookView.swift
//  TAassets
//
//  Created by Logan Jones on 7/2/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation
import Quartz

class QuickLookView: QLPreviewView {
    
    private var tempFileUrl: URL?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect, style: .compact)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        
        previewItem = tempFileUrl as NSURL
        refreshPreviewItem()
    }
    
    private func deleteTempFile() {
        if let url = tempFileUrl {
            try? FileManager.default.removeItem(at: url)
        }
    }

}

