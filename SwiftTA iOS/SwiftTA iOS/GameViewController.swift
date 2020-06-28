//
//  ViewController.swift
//  SwiftTA iOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import UIKit
import SwiftTA_Core
import SwiftTA_Metal

class GameViewController: UIViewController {
    
    let game: GameManager
    let renderer: GameRenderer & GameViewProvider
    
    private let scrollView: UIScrollView
    private let dummy: UIView
    
    required init(_ state: GameState) {
        let initialViewState = state.generateInitialViewState(viewportSize: Size2<Int>(640, 480))
        
        self.renderer = MetalRenderer(loadedState: state, viewState: initialViewState)!
        self.game = GameManager(state: state, renderer: renderer)
        
        let defaultFrameRect = CGRect(size: initialViewState.viewport.size)
        scrollView = UIScrollView(frame: defaultFrameRect)
        dummy = UIView(frame: defaultFrameRect)
        
        super.init(nibName: nil, bundle: nil)
        game.start()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let frameRect = scrollView.frame
        view = UIView(frame: frameRect)
        
        let gameView = renderer.view
        gameView.frame = frameRect
        gameView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let scale: CGFloat = 1
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.contentOffset = CGPoint(renderer.viewState.viewport.origin) * scale
        scrollView.contentSize = CGSize(game.loadedState.map.resolution) * scale
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 2
        scrollView.zoomScale = scale
        scrollView.delegate = self
        
        dummy.frame.size = CGSize(game.loadedState.map.resolution) * scale
        scrollView.addSubview(dummy)
        
        view.addSubview(gameView)
        view.addSubview(scrollView)
    }
    
    fileprivate func updateRendererViewport() {
        renderer.viewState.viewport = Rect4f(origin: Point2f(scrollView.contentOffset / scrollView.zoomScale),
                                             size: Size2f(scrollView.bounds.size / scrollView.zoomScale))
    }
    
}

extension GameViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateRendererViewport()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return dummy
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateRendererViewport()
    }
    
}
