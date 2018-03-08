//
//  CobView.swift
//  TAassets
//
//  Created by Logan Jones on 5/10/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa

class CobView: NSView {
    
    private unowned let textView: NSTextView
    
    override init(frame frameRect: NSRect) {
        
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: frameRect.size.width, height: frameRect.size.height))
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autoresizingMask = [.width, .height]
        
        let contentSize = scroll.contentSize
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        text.minSize = NSSize(width: 0, height: contentSize.height)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
        text.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        text.isEditable = false
        text.isSelectable = true
        self.textView = text
        
        super.init(frame: frameRect)
        
        scroll.documentView = text
        self.addSubview(scroll)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(_ script: UnitScript) {
        textView.string = ""
        guard let textStorage = textView.textStorage
            else { return }
        
        textStorage.beginEditing()
        script.decompile(writingTo: textStorage.append)
        textStorage.endEditing()
        
        setNeedsDisplay(bounds)
    }
    
}

private func computeModuleLengths(from script: UnitScript) -> [Int] {
    return script.modules.enumerated().map { (index, module) -> Int in
        let end = index+1 == script.modules.count ? script.code.count : script.modules[index+1].offset
        return module.offset - end
    }
}








private extension NSTextStorage {
    
    func append(_ s: String) {
        let text = NSAttributedString(string: s)
        self.append(text)
    }
    
}
