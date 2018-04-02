//
//  GafView.swift
//  HPIView
//
//  Created by Logan Jones on 5/27/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import AppKit

class GafView: NSView {
    
    var useFrameOffsetsForCentering = false
    
    private unowned let imageView: NSImageView
    private unowned let frameSlider: NSSlider
    private unowned let animateButton: NSButton
    
    private var centerX: NSLayoutConstraint!
    private var centerY: NSLayoutConstraint!
    
    private var timer: Timer?
    
    private var frames: [GafItem.Frame] = []
    private var palette = Palette()
    
    override init(frame frameRect: NSRect) {
        
        let imageView = NSImageView()
        let frameSlider = NSSlider()
        let animateButton = NSButton()
        
        self.imageView = imageView
        self.frameSlider = frameSlider
        self.animateButton = animateButton
        super.init(frame: frameRect)
        
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(frameSlider)
        frameSlider.translatesAutoresizingMaskIntoConstraints = false
        frameSlider.target = self
        frameSlider.action = #selector(frameSliderUpdated)
        frameSlider.allowsTickMarkValuesOnly = true
        frameSlider.minValue = 1
        frameSlider.maxValue = 1
        frameSlider.numberOfTickMarks = 1
        frameSlider.doubleValue = 1
        addSubview(animateButton)
        animateButton.translatesAutoresizingMaskIntoConstraints = false
        animateButton.bezelStyle = .smallSquare
        animateButton.title = "▶️" // "◼️"
        animateButton.target = self
        animateButton.action = #selector(toggleAnimation)
        animateButton.isEnabled = false
        
        centerX = imageView.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        centerY = imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        
        NSLayoutConstraint.activate([
//            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
//            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
//            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            centerX,
            centerY,
            frameSlider.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            frameSlider.trailingAnchor.constraint(equalTo: animateButton.leadingAnchor),
            frameSlider.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            animateButton.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            animateButton.centerYAnchor.constraint(equalTo: frameSlider.centerYAnchor),
            ])
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load<File>(_ item: GafItem, from gaf: File, using palette: Palette) throws
        where File: FileReadHandle
    {
        stopAnimating()
        
        imageView.image = nil
        frameSlider.minValue = 1
        frameSlider.maxValue = Double(item.numberOfFrames)
        frameSlider.numberOfTickMarks = item.numberOfFrames
        frameSlider.doubleValue = 1
        animateButton.isEnabled = item.frameOffsets.count > 1
        
        self.palette = palette
        frames = try item.extractFrames(from: gaf)
        
        showCurrentFrame()
    }
    
    private func showCurrentFrame() {
        
        let frameIndex = Int(frameSlider.doubleValue) - 1
        guard frames.indexRange.contains(frameIndex) else { return }
        let frame = frames[frameIndex]
        
        if useFrameOffsetsForCentering {
            centerX.constant = CGFloat(frame.size.width)/2 - CGFloat(frame.offset.x)
            centerY.constant = CGFloat(frame.size.height)/2 - CGFloat(frame.offset.y)
        }
        else {
            centerX.constant = 0
            centerY.constant = 0
        }
        
        imageView.image = try? NSImage(imageIndices: frame.data, size: frame.size, palette: palette, useTransparency: true)
    }
    
    @objc func frameSliderUpdated(_ sender: Any) {
        showCurrentFrame()
    }
    
    @objc func toggleAnimation(_ sender: Any) {
        if isAnimating { stopAnimating() } else { startAnimating() }
    }
    
}

private extension GafView {
    
    var isAnimating: Bool { return timer != nil }
    
    func startAnimating() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/15, repeats: true) { [weak self] t in
            self?.stepAnimation(t)
        }
        animateButton.title = "◼️"
    }
    
    func stopAnimating(resetSlider: Bool = false) {
        
        guard let timer = timer else { return }
        
        timer.invalidate()
        self.timer = nil
        
        animateButton.title = "▶️"
        
        if resetSlider {
            frameSlider.doubleValue = 1
            showCurrentFrame()
        }
    }
    
    func stepAnimation(_ timer: Timer) {
        
        let frameIndex = Int(frameSlider.doubleValue)
        
        guard frameIndex < frames.endIndex else {
            stopAnimating(resetSlider: true)
            return
        }
        
        frameSlider.doubleValue += 1
        showCurrentFrame()
    }
    
}
