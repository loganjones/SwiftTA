//
//  ViewController.swift
//  SwiftTA iOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import UIKit

class GameViewController: UIViewController {
    
    let state: GameState
    let renderer: GameRenderer
    
    private let scrollView: UIScrollView
    
    required init(_ state: GameState) {
        let defaultFrameRect = CGRect(x: 0, y: 0, width: 640, height: 480)
        let initialViewState = GameViewState(viewport: defaultFrameRect)
        
        self.state = state
        self.renderer = MetalRenderer(loadedState: state, viewState: initialViewState)!
        
        scrollView = UIScrollView(frame: defaultFrameRect)
        
        super.init(nibName: nil, bundle: nil)
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
        
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.contentSize = CGSize(state.map.resolution * 2)
        scrollView.delegate = self
        
        view.addSubview(gameView)
        view.addSubview(scrollView)
    }
    
}

extension GameViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        renderer.viewState.viewport = CGRect(origin: scrollView.contentOffset / 2, size: scrollView.bounds.size / 2)
    }
    
}

// TEMP
extension CGPoint {
    
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
