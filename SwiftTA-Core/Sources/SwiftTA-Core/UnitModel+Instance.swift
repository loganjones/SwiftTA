//
//  UnitModel+Instance.swift
//  TAassets
//
//  Created by Logan Jones on 6/3/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

extension UnitModel {
    
    struct Instance {
        var position: Vector3f = .zero
        var orientation: Vector3f = .zero
        var pieces: [PieceState]
    }
    
    struct PieceState {
        var move = Vector3f.zero
        var turn = Vector3f.zero
        var hidden = false
        var cache = true
        var shade = true
        var shadow = true
    }
    
}

extension UnitModel.Instance {
    
    init(for model: UnitModel) {
        self.init(count: model.pieces.count)
    }
    
    init(count: Int) {
        pieces = Array(repeating: UnitModel.PieceState(), count: count)
    }
    
}

extension UnitModel.Instance {
    
    func beginTranslation(for piece: Int, along axis: UnitScript.Axis, to target: GameFloat, with speed: GameFloat) -> UnitScript.Animation {
        
        let current = pieces[piece].move[axis]
        
        let translation = UnitScript.TranslationAnimation(
            piece: piece,
            axis: axis,
            target: target,
            velocity: target > current ? speed : -speed)
        
        return .translation(translation)
    }
    
    func beginRotation(for piece: Int, around axis: UnitScript.Axis, to target: GameFloat, with speed: GameFloat) -> UnitScript.Animation {
        
        let deg2rad = GameFloat.pi/180.0
        
        let rotation = UnitScript.RotationAnimation(
            piece: piece,
            axis: axis,
            target: target,
            speed: speed * deg2rad,
            targetPolar: Vector2f(polarAngle: target * deg2rad))
        
        return .rotation(rotation)
    }
    
    func beginSpin(for piece: Int, around axis: UnitScript.Axis, accelerating acceleration: GameFloat, to speed: GameFloat) -> UnitScript.Animation {
        
        let deg2rad = GameFloat.pi/180.0
        
        if acceleration > 0 {
            let spin = UnitScript.SpinAnimation(
                piece: piece,
                axis: axis,
                acceleration: acceleration * deg2rad,
                speed: 0,
                targetSpeed: speed * deg2rad)
            return .spinUp(spin)
        }
        else {
            let spin = UnitScript.SpinAnimation(
                piece: piece,
                axis: axis,
                acceleration: acceleration * deg2rad,
                speed: speed * deg2rad,
                targetSpeed: speed * deg2rad)
            return .spin(spin)
        }
    }
    
    mutating func apply(_ animation: UnitScript.Animation, with delta: GameFloat) -> UnitScript.Animation? {
        switch animation {
            
        case .setPosition(let move):
            pieces[move.piece].move[move.axis] = move.target
            return nil
            
        case .translation(let move):
            return apply(move, with: delta)
            
        case .setAngle(let turn):
            pieces[turn.piece].turn[turn.axis] = turn.target
            return nil
            
        case .rotation(let turn):
            return apply(turn, with: delta)
            
        case .spinUp(var spin):
            let nextSpeed = spin.speed + spin.acceleration * delta
            if nextSpeed >= spin.targetSpeed {
                spin.speed = spin.targetSpeed
                apply(spin, with: delta)
                return .spin(spin)
            }
            else {
                spin.speed = nextSpeed
                apply(spin, with: delta)
                return .spinUp(spin)
            }
            
        case .spin(let spin):
            apply(spin, with: delta)
            return .spin(spin)
            
        case .spinDown(var spin):
            let nextSpeed = spin.speed - spin.acceleration * delta
            if nextSpeed <= 0 {
                return nil
            }
            else {
                spin.speed = nextSpeed
                apply(spin, with: delta)
                return .spinDown(spin)
            }
            
        case .show(let piece):
            pieces[piece].hidden = false
            //print("Anim: Show \(piece)")
            return nil
        case .hide(let piece):
            pieces[piece].hidden = true
            //print("Anim: Hide \(piece)")
            return nil
            
        }
    }
    
    mutating func apply(_ move: UnitScript.TranslationAnimation, with delta: GameFloat) -> UnitScript.Animation? {
        
        let current = pieces[move.piece].move[move.axis]
        let next = current + move.velocity * delta
        
        if move.velocity > 0 {
            if next > move.target {
                pieces[move.piece].move[move.axis] = move.target
                return nil
            }
            else {
                pieces[move.piece].move[move.axis] = next
                return .translation(move)
            }
        }
        else if move.velocity < 0 {
            if next < move.target {
                pieces[move.piece].move[move.axis] = move.target
                return nil
            }
            else {
                pieces[move.piece].move[move.axis] = next
                return .translation(move)
            }
        }
        else {
            pieces[move.piece].move[move.axis] = move.target
            return nil
        }
    }
    
    mutating func apply(_ turn: UnitScript.RotationAnimation, with delta: GameFloat) -> UnitScript.Animation? {
        
        let deg2rad = GameFloat.pi/180.0
        let rad2deg = 180.0/GameFloat.pi
        
        let current = pieces[turn.piece].turn[turn.axis]
        let currentPolar = Vector2(polarAngle: current * deg2rad)
        let rate = turn.speed * delta
        
        if acos( currentPolar • turn.targetPolar ) <= rate {
            pieces[turn.piece].turn[turn.axis] = turn.target
            return nil
        }
        else {
            let next = (Vector2.determinant(currentPolar, turn.targetPolar) >= 0)
                ? currentPolar.rotated(by: rate)
                : currentPolar.rotated(by: -rate)
            pieces[turn.piece].turn[turn.axis] = next.angle * rad2deg
            return .rotation(turn)
        }
    }
    
    mutating func apply(_ turn: UnitScript.SpinAnimation, with delta: GameFloat) {
        
        let deg2rad = GameFloat.pi/180.0
        let rad2deg = 180.0/GameFloat.pi
        
        let current = pieces[turn.piece].turn[turn.axis]
        let currentPolar = Vector2(polarAngle: current * deg2rad)
        let rate = turn.speed * delta
        
        let next = currentPolar.rotated(by: rate)
        pieces[turn.piece].turn[turn.axis] = next.angle * rad2deg
    }
    
}

private extension Vector3 {
    
    subscript(axis: UnitScript.Axis) -> Element {
        get {
            switch axis {
            case .x: return x
            case .y: return y
            case .z: return z
            }
        }
        set(new) {
            switch axis {
            case .x: x = new
            case .y: y = new
            case .z: z = new
            }
        }
    }
    
}

private extension Vector2f {
    
    init(polarAngle angle: GameFloat, magnitude: GameFloat = 1) {
        self.init(
            cos(angle) * magnitude,
            sin(angle) * magnitude
        )
    }
    
    var angle: GameFloat {
        if y >= 0 { return acos(x) }
        else { return -acos(x) }
    }
    
    func rotated(by angle: GameFloat) -> Vector2f {
        let c = cos(angle)
        let s = sin(angle)
        return Vector2f(
            x: (x * c) + (y * -s),
            y: (x * s) + (y * c)
        )
    }
    
    static func determinant(_ a: Vector2f, _ b: Vector2f) -> GameFloat {
        return (a.x * b.y) - (a.y * b.x)
    }
    
}
