//
//  PaletteView.swift
//  HPIView
//
//  Created by Logan Jones on 3/31/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa


class PaletteView: NSView {
    
    private unowned let scrollView: NSScrollView
    private unowned let collectionView: NSCollectionView
    var palette = Palette()
    
    override init(frame frameRect: NSRect) {
        
        let scrollView = NSScrollView(frame: frameRect)
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.wantsLayer = true
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        
        let collectionView = NSCollectionView(frame: frameRect)
        let layout = NSCollectionViewGridLayout()
        layout.maximumNumberOfRows = 16
        layout.maximumNumberOfColumns = 16
        layout.minimumItemSize = NSSize(width: 16, height: 16)
        layout.maximumItemSize = NSSize(width: 64, height: 64)
        collectionView.collectionViewLayout = layout
        
        self.scrollView = scrollView
        self.collectionView = collectionView
        super.init(frame: frameRect)
        wantsLayer = true
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PaletteViewItem.self, forItemWithIdentifier: PaletteViewItem.collectionViewItemIdentifier)
        
        addSubview(scrollView)
        scrollView.documentView = collectionView
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(_ palette: Palette) {
        self.palette = palette
        collectionView.reloadData()
    }
    
}

extension PaletteView: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return 256
    }
    
    func collectionView(_ itemForRepresentedObjectAtcollectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        guard let item = collectionView.makeItem(withIdentifier: PaletteViewItem.collectionViewItemIdentifier, for: indexPath) as? PaletteViewItem else { fatalError("Expected PaletteViewItem") }
        
        item.setColor(palette[indexPath[1]])
        return item
    }
    
}

extension PaletteView: NSCollectionViewDelegate {
    
}

@objc(PaletteViewItem) class PaletteViewItem: NSCollectionViewItem {
    
    static let collectionViewItemIdentifier = NSUserInterfaceItemIdentifier(rawValue: "paletteItem")
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.blue.cgColor
    }
    
    func setColor(_ color: Palette.Color) {
        view.layer?.backgroundColor = color.cgColor
    }
    
}
