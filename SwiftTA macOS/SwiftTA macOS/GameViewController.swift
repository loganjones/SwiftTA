//
//  ViewController.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa


class GameViewController: NSViewController {
    
    let game: GameManager
    let renderer: GameRenderer & GameViewProvider
    
    private let scrollView: NSScrollView
    private let emptyView: NSView
    
    required init(_ state: GameState) {
        let initialViewState = state.generateInitialViewState(viewportSize: Size2<Int>(1024, 768))
        
        self.renderer = MetalRenderer(loadedState: state, viewState: initialViewState)!
        //self.renderer = OpenglCore3CocoaRenderer(loadedState: state, viewState: initialViewState)!
        self.game = GameManager(state: state, renderer: renderer)
        
        let defaultFrameRect = CGRect(size: initialViewState.viewport.size)
        scrollView = NSScrollView(frame: defaultFrameRect)
        emptyView = Dummy(frame: defaultFrameRect)
        
        super.init(nibName: nil, bundle: nil)
        game.start()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: view)
    }
    
    override func loadView() {
        let frameRect = scrollView.frame
        view = NSView(frame: frameRect)
        
        let gameView = renderer.view
        gameView.frame = frameRect
        gameView.autoresizingMask = [.width, .height]
        
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        //scrollView.wantsLayer = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        
        emptyView.alphaValue = 0
        emptyView.frame = NSRect(size: game.loadedState.map.resolution)
        
        view.addSubview(gameView)
        view.addSubview(scrollView)
        scrollView.documentView = emptyView
        scrollView.contentView.bounds = CGRect(renderer.viewState.viewport)
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(contentBoundsDidChange), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(viewFrameDidChange), name: NSView.frameDidChangeNotification, object: view)
    }
    
    private class Dummy: NSView {
        override var isFlipped: Bool {
            return true
        }
    }
    
    @objc func contentBoundsDidChange(_ notification: NSNotification) {
        renderer.viewState.viewport = Rect4f(scrollView.contentView.bounds)
    }
    
    @objc func viewFrameDidChange(_ notification: NSNotification) {
        renderer.viewState.viewport = Rect4f(scrollView.contentView.bounds)
    }

}