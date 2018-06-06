//
//  CobView.swift
//  TAassets
//
//  Created by Logan Jones on 5/10/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa

class GenericTextView: NSView {
    
    unowned let textView: NSTextView
    
    var font = NSFont.userFixedPitchFont(ofSize: 11) ?? NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet {
            let range = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
            textView.textStorage?.setAttributes([NSAttributedStringKey.font : font], range: range)
        }
    }
    
    override init(frame frameRect: NSRect) {
        
        let scroll = NSScrollView(frame: NSRect(x: 1, y: 1, width: frameRect.size.width-2, height: frameRect.size.height-2))
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
        text.font = font
        text.isEditable = false
        text.isSelectable = true
        self.textView = text
        
        super.init(frame: frameRect)
        
        scroll.documentView = text
        self.addSubview(scroll)
        
        wantsLayer = true
        layer?.borderColor = NSColor.windowFrameColor.cgColor
        layer?.borderWidth = 1
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var text: String {
        get { return textView.string }
        set(new) { textView.textStorage?.setAttributedString(NSAttributedString(string: new, attributes: [NSAttributedStringKey.font: font])) }
    }
    
}

class CobView: GenericTextView {
    
    func load(_ script: UnitScript) {
        textView.string = ""
        guard let textStorage = textView.textStorage
            else { return }
        
        textStorage.beginEditing()
        script.decompile(writingTo: self.append)
        textStorage.endEditing()
        
        setNeedsDisplay(bounds)
    }
    
    func append(_ s: String) {
        let text = NSAttributedString(string: s, attributes: [NSAttributedStringKey.font: font])
        textView.textStorage?.append(text)
    }
    
}

private func computeModuleLengths(from script: UnitScript) -> [Int] {
    return script.modules.enumerated().map { (index, module) -> Int in
        let end = index+1 == script.modules.count ? script.code.count : script.modules[index+1].offset
        return module.offset - end
    }
}
