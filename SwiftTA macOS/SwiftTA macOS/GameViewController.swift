//
//  ViewController.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa
import SwiftTA_Core

class GameViewController: NSViewController {
    
    let game: GameManager
    let renderer: GameRenderer & GameViewProvider
    
    private let scrollView: NSScrollView
    private let emptyView: NSView
    
    private let invisibleCursor = { () -> NSCursor in
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { rect in
            //NSColor.red.drawSwatch(in: rect)
            return true
        }
        return NSCursor(image: image, hotSpot: .zero)
    }()
    
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
        let view = MouseTrackingView(frame: frameRect)
        view.trackingDelegate = self
        self.view = view
        
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

extension GameViewController: MouseTrackingDelegate {
    
    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        invisibleCursor.set()
        //print("[TEST] cursorUpdate")
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        //print("[TEST] mouseEntered: \(event.locationInWindow)")
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        //print("[TEST] mouseExited: \(event.locationInWindow)")
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseExited(with: event)
        var location = event.locationInWindow
        location.y = view.bounds.size.height - location.y
        renderer.viewState.cursorLocation = Point2f(location)
        //print("[TEST] mouseMoved: \(event.locationInWindow)")
    }
    
}

private protocol MouseTrackingDelegate: AnyObject {
    func cursorUpdate(with event: NSEvent)
    func mouseEntered(with event: NSEvent)
    func mouseExited(with event: NSEvent)
    func mouseMoved(with event: NSEvent)
}

private class MouseTrackingView: NSView {
    
    weak var trackingDelegate: MouseTrackingDelegate?
    private weak var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        print("[TEST] updateTrackingAreas")
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        let new = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .cursorUpdate, .mouseEnteredAndExited, .mouseMoved],
            owner: trackingDelegate,
            userInfo: nil)
        addTrackingArea(new)
        trackingArea = new
    }
    
}
