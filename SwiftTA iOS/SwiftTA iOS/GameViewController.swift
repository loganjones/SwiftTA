//
//  ViewController.swift
//  SwiftTA iOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import UIKit


class GameViewController: UIViewController {
    
    let game: GameManager
    let renderer: GameRenderer & GameViewProvider
    
    private let scrollView: UIScrollView
    private let dummy: UIView
    
    required init(_ state: GameState) {
        let initialViewState = state.generateInitialViewState(viewportSize: Size2D(640, 480))
        
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
        scrollView.contentOffset = renderer.viewState.viewport.origin * scale
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
        renderer.viewState.viewport = CGRect(origin: scrollView.contentOffset / scrollView.zoomScale, size: scrollView.bounds.size / scrollView.zoomScale)
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

// TEMP
extension CGPoint {
    
    static func * (point: CGPoint, mult: Int) -> CGPoint {
        let df = CGFloat(mult)
        return CGPoint(x: point.x * df, y: point.y * df)
    }
    static func * (point: CGPoint, mult: CGFloat) -> CGPoint {
        let df = mult
        return CGPoint(x: point.x * df, y: point.y * df)
    }
    
    static func / (point: CGPoint, divisor: Int) -> CGPoint {
        let df = CGFloat(divisor)
        return CGPoint(x: point.x / df, y: point.y / df)
    }
    static func /= (point: inout CGPoint, divisor: Int) {
        let df = CGFloat(divisor)
        point.x /= df
        point.y /= df
    }
    
    static func / (point: CGPoint, divisor: CGFloat) -> CGPoint {
        return CGPoint(x: point.x / divisor, y: point.y / divisor)
    }
    static func /= (point: inout CGPoint, divisor: CGFloat) {
        point.x /= divisor
        point.y /= divisor
    }
    
}
extension CGSize {
    
    static func * (size: CGSize, mult: Int) -> CGSize {
        let df = CGFloat(mult)
        return CGSize(width: size.width * df, height: size.height * df)
    }
    static func * (size: CGSize, mult: CGFloat) -> CGSize {
        let df = mult
        return CGSize(width: size.width * df, height: size.height * df)
    }
    
    static func / (size: CGSize, divisor: Int) -> CGSize {
        let df = CGFloat(divisor)
        return CGSize(width: size.width / df, height: size.height / df)
    }
    static func /= (size: inout CGSize, divisor: Int) {
        let df = CGFloat(divisor)
        size.width /= df
        size.height /= df
    }
    
    static func / (size: CGSize, divisor: CGFloat) -> CGSize {
        return CGSize(width: size.width / divisor, height: size.height / divisor)
    }
    static func /= (size: inout CGSize, divisor: CGFloat) {
        size.width /= divisor
        size.height /= divisor
    }
    
}
