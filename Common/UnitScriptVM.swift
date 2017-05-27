//
//  UnitScriptVM.swift
//  HPIView
//
//  Created by Logan Jones on 5/14/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation


extension UnitScript {
    
    static var nextId = 0
    
    class Context {
        var script: UnitScript
        var staticVariables: [UnitScript.CodeUnit]
        var threads: [Thread]
        var animations: [Animation]
        var pieceMap: [UnitModel.Pieces.Index]
        
        init(_ script: UnitScript, _ model: UnitModel) {
            self.script = script
            staticVariables = Array<UnitScript.CodeUnit>(repeating: 0, count: script.numberOfStaticVariables)
            threads = []
            animations = []
            pieceMap = script.pieces.map { model.nameLookup[$0] ?? 0 }
        }
        
    }
    
    class Thread {
        
        var id: Int
        var stack: [UnitScript.CodeUnit]
        var framePointer: Array<UnitScript.CodeUnit>.Index
        var status: Status
        var signalMask: UnitScript.CodeUnit
        
        enum Status {
            case running
            case sleeping(Double)
            case waitingForMove(Int, Axis)
            case waitingForTurn(Int, Axis)
            case finished
        }
        
        init(_ id: Int, _ module: UnitScript.Module, parameters: [UnitScript.CodeUnit] = [] ) {
            let locals = module.localCount > parameters.count
                ? Array<UnitScript.CodeUnit>(repeating: 0, count: module.localCount - parameters.count)
                : []
            stack = [UnitScript.CodeUnit(module.offset)] + parameters + locals
            framePointer = 0
            status = .running
            signalMask = 0
            self.id = id
        }
        
    }
    
}

protocol ScriptMachine {
    
    func getTime() -> Double
    
}

extension UnitScript.Context {
    
    func run<Machine: ScriptMachine>(for instance: UnitModel.Instance, on machine: Machine) {
        threads.forEach { $0.run(with: self, for: instance, on: machine) }
        threads = threads.filter { !$0.isFinished }
    }
    
    func startScript(_ moduleName: String, parameters: [UnitScript.CodeUnit] = []) {
        guard let module = script.module(named: moduleName)
            else { return }
        startScript(module, parameters: parameters)
    }
    
    func startScript(_ module: UnitScript.Module, parameters: [UnitScript.CodeUnit] = []) {
        let thread = UnitScript.Thread(UnitScript.nextId, module, parameters: parameters)
        threads.append(thread)
        UnitScript.nextId += 1
        print("start-script \(module.name)(\(parameters)) -> Thread[\(thread.id)]")
    }
    
    func `static`(at index: UnitScript.CodeUnit) throws -> UnitScript.CodeUnit {
        let i = Int(index)
        guard i < staticVariables.count
            else { throw UnitScript.Thread.ExecutionError.badStatic(index) }
        return staticVariables[i]
    }
    
    func setStatic(at index: UnitScript.CodeUnit, to value: UnitScript.CodeUnit) throws {
        let i = Int(index)
        guard i < staticVariables.count
            else { throw UnitScript.Thread.ExecutionError.badStatic(index) }
        staticVariables[i] = value
    }
    
    func module(at index: UnitScript.CodeUnit) throws -> UnitScript.Module {
        let i = Int(index)
        if i < script.modules.count { return script.modules[i] }
        else { throw UnitScript.Thread.ExecutionError.badModule(index) }
    }
    
    func pieceIndex(at index: UnitScript.CodeUnit) throws -> Int {
        let i = Int(index)
        if i < pieceMap.count { return pieceMap[i] }
        else { throw UnitScript.Thread.ExecutionError.badPiece(index) }
    }
    
    func applyAnimations(to instance: inout UnitModel.Instance, for delta: Double) {
        let unfinished = animations.flatMap { instance.apply($0, with: delta) }
        animations = unfinished
    }
    
    func findSpinAnimation(of piece: Int, around axis: UnitScript.Axis) -> (index: Int, spin: UnitScript.SpinAnimation)? {
        for (i, a) in animations.enumerated() {
            switch a {
            case .spinUp(let spin), .spin(let spin), .spinDown(let spin):
                if spin.piece == piece && spin.axis == axis { return (i, spin) }
            default:
                ()
            }
        }
        return nil
    }
    
    func signalThreads(with mask: UnitScript.CodeUnit, except: UnitScript.Thread? = nil) {
        threads.forEach {
            if $0.isSignaled(by: mask) && $0 !== except {
                $0.status = .finished
                print("[\($0.id)] signaled with \(mask)")
            }
        }
    }
    
}

extension UnitScript.Thread {
    
    var isFinished: Bool {
        switch status {
        case .finished: return true
        default: return false
        }
    }
    
    func callScript(_ module: UnitScript.Module, parameters: [UnitScript.CodeUnit] = []) {
        print("[\(id)] call-script \(module.name)(\(parameters))")
        
        stack.append(UnitScript.CodeUnit(framePointer))
        
        let locals = module.localCount > parameters.count
            ? Array<UnitScript.CodeUnit>(repeating: 0, count: module.localCount - parameters.count)
            : []
        
        framePointer = stack.count
        stack.append(UnitScript.CodeUnit(module.offset))
        stack.append(contentsOf: parameters)
        stack.append(contentsOf: locals)
    }
    
    @discardableResult func `return`(with value: UnitScript.CodeUnit) -> Status {
        if framePointer > 0 {
            let n = stack.count - (framePointer-1)
            framePointer = Int(stack[framePointer - 1])
            stack.removeLast(n)
            // Do something with value?
            print("[\(id)] return \(value)")
        }
        else {
            // Do something with value?
            print("[\(id)] return \(value)")
            status = .finished
        }
        return status
    }
    
    var instructionPointer: UnitScript.Code.Index {
        get { return Int(stack[framePointer]) }
        set(new) { stack[framePointer] = UnitScript.CodeUnit(new) }
    }
    
    func local(at index: UnitScript.CodeUnit) throws -> UnitScript.CodeUnit {
        let offset = framePointer + 1 + Int(index)
        guard offset < stack.count
            else { throw ExecutionError.badLocal(index) }
        return stack[offset]
    }
    
    func setLocal(at index: UnitScript.CodeUnit, to value: UnitScript.CodeUnit) throws {
        let offset = framePointer + 1 + Int(index)
        guard offset < stack.count
            else { throw ExecutionError.badLocal(index) }
        stack[offset] = value
    }
    
    func makeAxis(for value: UnitScript.CodeUnit) throws -> UnitScript.Axis {
        guard let axis = UnitScript.Axis(rawValue: value)
            else { throw ExecutionError.badAxis(value) }
        return axis
    }
    
    func isSignaled(by mask: UnitScript.CodeUnit) -> Bool {
        return (signalMask & mask) != 0
    }
    
    func run<Machine: ScriptMachine>(with context: UnitScript.Context, for instance: UnitModel.Instance, on machine: Machine) {
        do {
            runLoop: while true {
                switch status {
                case .running:
                    try execute(with: context, for: instance, on: machine)
                case .sleeping(let until):
                    if machine.getTime() > until {
                        //print("[\(id)] sleep over!")
                        status = .running
                    }
                    break runLoop
                case .waitingForMove:
                    print("[\(id)] waiting for move")
                    break runLoop
                case .waitingForTurn:
                    print("[\(id)] waiting for turn")
                    break runLoop
                case .finished:
                    print("[\(id)] finished")
                    break runLoop
                }
            }
        }
        catch {
            print("[\(id)] Script Error: \(error)")
            status = .finished
        }
    }
    
    func execute<Machine: ScriptMachine>(with context: UnitScript.Context, for instance: UnitModel.Instance, on machine: Machine) throws {
        
        let i = instructionPointer
        let code = context.script.code
        let instructionSize: Int
        
        guard let instruction = UnitScript.Opcode(rawValue: code[i])
            else { throw ExecutionError.badOpcode(code[i]) }
        
        switch instruction {
            
        case .movePieceWithSpeed:
            let piece = code[i+1]
            let axis = code[i+2]
            let destination = try stack.pop()
            let speed = try stack.pop()
            let translation = instance.beginTranslation(
                for: try context.pieceIndex(at: piece),
                along: try makeAxis(for: axis),
                to: destination.linearValue,
                with: speed.linearValue)
            context.animations.append(translation)
            //print("[\(id)] Move \(piece) along \(axis) to \(destination) with speed \(speed)")
            instructionSize = 3
            
        case .turnPieceWithSpeed:
            let piece = code[i+1]
            let axis = code[i+2]
            let destination = try stack.pop()
            let speed = try stack.pop()
            let rotation = instance.beginRotation(
                for: try context.pieceIndex(at: piece),
                around: try makeAxis(for: axis),
                to: destination.angularValue,
                with: speed.angularValue)
            context.animations.append(rotation)
            //print("[\(id)] Turn \(piece) around \(axis) to \(destination) with speed \(speed)")
            instructionSize = 3
            
        case .startSpin:
            let piece = code[i+1]
            let axis = code[i+2]
            let speed = try stack.pop()
            let acceleration = try stack.pop()
            let spin = instance.beginSpin(
                for: try context.pieceIndex(at: piece),
                around: try makeAxis(for: axis),
                accelerating: acceleration.angularValue,
                to: speed.angularValue)
            context.animations.append(spin)
            //print("[\(id)] Spin \(piece) around \(axis) accelerate \(acceleration) to speed \(speed)")
            instructionSize = 3
            
        case .stopSpin:
            let piece = code[i+1]
            let axis = code[i+2]
            let decceleration = try stack.pop()
            //print("[\(id)] Stop spin \(piece) around \(axis) deccelerate \(decceleration)")
            if let found = context.findSpinAnimation(of: try context.pieceIndex(at: piece), around: try makeAxis(for: axis)) {
                var spin = found.spin
                spin.acceleration = decceleration.angularValue * Double.pi/180.0
                context.animations[found.index] = .spinDown(spin)
            }
            instructionSize = 3
            
        case .showPiece:
            let piece = code[i+1]
            context.animations.append(.show(try context.pieceIndex(at: piece)))
            instructionSize = 2
            
        case .hidePiece:
            let piece = code[i+1]
            context.animations.append(.hide(try context.pieceIndex(at: piece)))
            instructionSize = 2
            
        case .cachePiece:
            //let piece = code[i+1]
            instructionSize = 2
        case .dontCachePiece:
            //let piece = code[i+1]
            instructionSize = 2
        case .dontShadow:
            ///let piece = code[i+1]
            instructionSize = 2
            
        case .movePieceNow:
            let piece = code[i+1]
            let axis = code[i+2]
            let destination = try stack.pop()
            context.animations.append(.setPosition(UnitScript.SetPosition(
                piece: try context.pieceIndex(at: piece),
                axis: try makeAxis(for: axis),
                target: destination.linearValue
            )))
            //print("[\(id)] Move \(piece) along \(axis) to \(destination)")
            instructionSize = 3
            
        case .turnPieceNow:
            let piece = code[i+1]
            let axis = code[i+2]
            let destination = try stack.pop()
            context.animations.append(.setAngle(UnitScript.SetAngle(
                piece: try context.pieceIndex(at: piece),
                axis: try makeAxis(for: axis),
                target: destination.angularValue
            )))
            //print("[\(id)] Turn \(piece) around \(axis) to \(destination)")
            instructionSize = 3
            
        case .dontShade:
            //let piece = code[i+1]
            instructionSize = 2
        case .emitSfx:
            //let piece = code[i+1]
            instructionSize = 2
            
        case .waitForTurn:
            let piece = code[i+1]
            let axis = try makeAxis(for: code[i+2])
            print("[\(id)] wait for turn: \(piece) around \(axis)")
            status = .waitingForTurn(Int(piece), axis)
            instructionSize = 3
            
        case .waitForMove:
            let piece = code[i+1]
            let axis = try makeAxis(for: code[i+2])
            print("[\(id)] wait for move: \(piece) along \(axis)")
            status = .waitingForMove(Int(piece), axis)
            instructionSize = 3
            
        case .sleep:
            let sleep = try stack.pop()
            let time = machine.getTime()
            //print("[\(id)] sleep \(sleep) =~ \(Double(sleep) / 1500)")
            status = .sleeping(time + (Double(sleep) / 1500))
            instructionSize = 1
            
        case .pushConstant:
            let value = code[i+1]
            stack.push(value)
            instructionSize = 2
            
        case .pushLocalVariable:
            let index = code[i+1]
            let value = try local(at: index)
            stack.push(value)
            instructionSize = 2
            
        case .pushStaticVariable:
            let index = code[i+1]
            let value = try context.static(at: index)
            stack.push(value)
            instructionSize = 2
            
        case .stackAllocate:
            stack.push(0)
            instructionSize = 1
            
        case .setLocalVariable:
            let value = try stack.pop()
            let index = code[i+1]
            try setLocal(at: index, to: value)
            instructionSize = 2
            
        case .setStaticVariable:
            let value = try stack.pop()
            let index = code[i+1]
            try context.setStatic(at: index, to: value)
            instructionSize = 2
            
        case .popStack:
            let _ = try stack.pop()
            instructionSize = 1
            
        case .add:
            try stack.perform(operation: &+)
            instructionSize = 1
        case .subtract:
            try stack.perform(operation: &-)
            instructionSize = 1
        case .multiply:
            try stack.perform(operation: &*)
            instructionSize = 1
        case .divide:
            try stack.perform(operation: /)
            instructionSize = 1
        case .bitwiseAnd:
            try stack.perform(operation: &)
            instructionSize = 1
        case .bitwiseOr:
            try stack.perform(operation: |)
            instructionSize = 1
            
        case .unknown1: fallthrough
        case .unknown2: fallthrough
        case .unknown3:
            try stack.perform(operation: &+)
            instructionSize = 1
            
        case .random:
            try stack.perform(operation: taRandom)
            instructionSize = 1
            
        case .getUnitValue:
            instructionSize = 1
        case .getFunctionResult:
            instructionSize = 1
            
        case .lessThan:
            try stack.perform(comparison: <)
            instructionSize = 1
        case .lessThanOrEqual:
            try stack.perform(comparison: <=)
            instructionSize = 1
        case .greaterThan:
            try stack.perform(comparison: >)
            instructionSize = 1
        case .greaterThanOrEqual:
            try stack.perform(comparison: >=)
            instructionSize = 1
        case .equal:
            try stack.perform(comparison: ==)
            instructionSize = 1
        case .notEqual:
            try stack.perform(comparison: !=)
            instructionSize = 1
            
        case .and:
            try stack.perform(operation: StackValue.booleanAnd)
            instructionSize = 1
        case .or:
            try stack.perform(operation: StackValue.booleanOr)
            instructionSize = 1
            
        case .not:
            try stack.perform(modification: StackValue.booleanNot)
            instructionSize = 1
            
        case .startScript:
            let moduleIndex = code[i+1]
            let paramCount = code[i+2]
            let module = try context.module(at: moduleIndex)
            let params = try stack.pop(count: paramCount)
            context.startScript(module, parameters: params)
            instructionSize = 3
            
        case .callScript:
            let moduleIndex = code[i+1]
            let paramCount = code[i+2]
            let module = try context.module(at: moduleIndex)
            let params = try stack.pop(count: paramCount)
            instructionPointer += 3
            callScript(module, parameters: params)
            instructionSize = 0
            
        case .jumpToOffset:
            let joffset = code[i+1]
            instructionPointer = Int(joffset)
            instructionSize = 0
            
        case .`return`:
            let value = try stack.pop()
            `return`(with: value)
            instructionSize = 0
            
        case .jumpToOffsetIfFalse:
            let joffset = code[i+1]
            let condition = try stack.pop()
            if condition != 0 {
                instructionSize = 2
            }
            else {
                instructionPointer = Int(joffset)
                instructionSize = 0
            }
            
        case .signal:
            let mask = try stack.pop()
            context.signalThreads(with: mask, except: self)
            instructionSize = 1
            
        case .setSignalMask:
            let mask = try stack.pop()
            signalMask = mask
            instructionSize = 1
            
        case .explode:
            instructionSize = 2
        case .playSound:
            instructionSize = 2
        case .mapCommand:
            instructionSize = 3
        case .setUnitValue:
            instructionSize = 1
        case .attachUnit:
            instructionSize = 1
        case .dropUnit:
            instructionSize = 1
        }
        
        if instructionSize > 0 {
            instructionPointer += instructionSize
        }
    }
    
    enum ExecutionError: Error {
        case badOpcode(UnitScript.CodeUnit)
        case badLocal(UnitScript.CodeUnit)
        case badStatic(UnitScript.CodeUnit)
        case badModule(UnitScript.CodeUnit)
        case badPiece(UnitScript.CodeUnit)
        case badAxis(UnitScript.CodeUnit)
        case stackUnderflow
    }
    
}

private extension UnitModel.Instance {
    
    func beginTranslation(for piece: Int, along axis: UnitScript.Axis, to target: Double, with speed: Double) -> UnitScript.Animation {
        
        let current = pieces[piece].move[axis]
        
        let translation = UnitScript.TranslationAnimation(
            piece: piece,
            axis: axis,
            target: target,
            velocity: target > current ? speed : -speed)
        
        return .translation(translation)
    }
    
    func beginRotation(for piece: Int, around axis: UnitScript.Axis, to target: Double, with speed: Double) -> UnitScript.Animation {
        
        let deg2rad = Double.pi/180.0
        
        let rotation = UnitScript.RotationAnimation(
            piece: piece,
            axis: axis,
            target: target,
            speed: speed * deg2rad,
            targetPolar: Vector2(polarAngle: target * deg2rad))
        
        return .rotation(rotation)
    }
    
    func beginSpin(for piece: Int, around axis: UnitScript.Axis, accelerating acceleration: Double, to speed: Double) -> UnitScript.Animation {
        
        let deg2rad = Double.pi/180.0
        
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
    
    mutating func apply(_ animation: UnitScript.Animation, with delta: Double) -> UnitScript.Animation? {
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
            return nil
        case .hide(let piece):
            pieces[piece].hidden = true
            return nil
            
        }
    }
    
    mutating func apply(_ move: UnitScript.TranslationAnimation, with delta: Double) -> UnitScript.Animation? {
        
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
    
    mutating func apply(_ turn: UnitScript.RotationAnimation, with delta: Double) -> UnitScript.Animation? {
        
        let deg2rad = Double.pi/180.0
        let rad2deg = 180.0/Double.pi
        
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
    
    mutating func apply(_ turn: UnitScript.SpinAnimation, with delta: Double) {
        
        let deg2rad = Double.pi/180.0
        let rad2deg = 180.0/Double.pi
        
        let current = pieces[turn.piece].turn[turn.axis]
        let currentPolar = Vector2(polarAngle: current * deg2rad)
        let rate = turn.speed * delta
        
        let next = currentPolar.rotated(by: rate)
        pieces[turn.piece].turn[turn.axis] = next.angle * rad2deg
    }
    
}

private extension Vector3 {
    
    subscript(axis: UnitScript.Axis) -> Double {
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

private extension Vector2 {
    
    init(polarAngle angle: Double, magnitude: Double = 1) {
        x = cos(angle) * magnitude
        y = sin(angle) * magnitude
    }
    
    var angle: Double {
        if y >= 0 { return acos(x) }
        else { return -acos(x) }
    }
    
    func rotated(by angle: Double) -> Vector2 {
        let c = cos(angle)
        let s = sin(angle)
        return Vector2(
            x: (x * c) + (y * -s),
            y: (x * s) + (y * c)
        )
    }
    
    static func determinant(_ a: Vector2, _ b: Vector2) -> Double {
        return (a.x * b.y) - (a.y * b.x)
    }
    
}

private typealias StackValue = UnitScript.CodeUnit

private extension UnitScript.CodeUnit {
    
    var linearValue: Double { return Double(self) / LINEAR_CONSTANT }
    var angularValue: Double { return Double(self) / ANGULAR_CONSTANT }
    
    static func booleanAnd(lhs: StackValue, rhs: StackValue) -> StackValue {
        return ((lhs != 0) && (rhs != 0)) ? 1 : 0
    }
    static func booleanOr(lhs: StackValue, rhs: StackValue) -> StackValue {
        return ((lhs != 0) || (rhs != 0)) ? 1 : 0
    }
    static func booleanNot(value: StackValue) -> StackValue {
        return (value != 0) ? 0 : 1
    }
    
}

private extension Array where Element == StackValue {
    
    mutating func pop() throws -> StackValue {
        if let e = popLast() { return e }
        else { throw UnitScript.Thread.ExecutionError.stackUnderflow }
    }
    
    mutating func pop(count c: StackValue) throws -> [StackValue] {
        guard c > 0 else { return [] }
        let n = Int(c)
        if count >= n {
            defer { removeLast(n) }
            return Array( suffix(from: n-1) )
        }
        else { throw UnitScript.Thread.ExecutionError.stackUnderflow }
    }
    
    mutating func push(_ newElement: StackValue) {
        append(newElement)
    }
    
    mutating func perform(operation: (StackValue, StackValue) -> StackValue) throws {
        let right = try self.pop()
        let left = try self.pop()
        let result = operation(left, right)
        self.push(result)
    }
    
    mutating func perform(comparison: (StackValue, StackValue) -> Bool) throws {
        let right = try self.pop()
        let left = try self.pop()
        let result = StackValue(comparison(left, right) ? 1 : 0)
        self.push(result)
    }
    
    mutating func perform(modification: (StackValue) -> StackValue) throws {
        let value = try self.pop()
        let result = modification(value)
        self.push(result)
    }
    
}

private func taRandom(min: StackValue, max: StackValue) -> StackValue {
    let spread = UInt32(max - min)
    let random = arc4random_uniform(spread)
    return min + StackValue(random)
}
