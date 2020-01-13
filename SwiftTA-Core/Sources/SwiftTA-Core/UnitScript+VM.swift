//
//  UnitScript+VM.swift
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
        
        init(_ script: UnitScript, _ model: UnitModel) throws {
            self.script = script
            staticVariables = Array<UnitScript.CodeUnit>(repeating: 0, count: script.numberOfStaticVariables)
            threads = []
            animations = []
            pieceMap = try script.pieces.map {
                guard let index = model.nameLookup[$0.lowercased()] else {
                    throw Error.badPiece($0)
                }
                return index
            }
        }
        
    }
    
    class Thread {
        
        var id: Int
        var stack: Stack<UnitScript.CodeUnit>
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
        
        struct Stack<Element> {
            fileprivate var _array: [Element] = []
        }
        
        init(_ id: Int, _ module: UnitScript.Module, parameters: [UnitScript.CodeUnit] = [] ) {
            stack = Stack()
            stack.push(module, with: parameters)
            framePointer = 0
            status = .running
            signalMask = 0
            self.id = id
        }
        
    }
    
    enum Error: Swift.Error {
        case badPiece(String)
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
        //print("start-script \(module.name)(\(parameters)) -> Thread[\(thread.id)]")
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
    
    func applyAnimations(to instance: inout UnitModel.Instance, for delta: GameFloat) {
        let unfinished = animations.compactMap { instance.apply($0, with: delta) }
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
                //print("[\($0.id)] signaled with \(mask)")
            }
        }
    }
    
}

extension UnitScript.Thread {
    
    typealias CodeUnit = UnitScript.CodeUnit
    
    var isFinished: Bool {
        switch status {
        case .finished: return true
        default: return false
        }
    }
    
    func callScript(_ module: UnitScript.Module, parameters: [CodeUnit] = []) {
//        print("[\(id)] call-script \(module.name)(\(parameters))")
        
        stack.push(framePointer)
        framePointer = stack.count
        
        stack.push(module, with: parameters)
    }
    
    @discardableResult func `return`(with value: CodeUnit) -> Status {
        if framePointer > 0 {
            let n = stack.count - (framePointer-1)
            framePointer = Int(stack._array[framePointer - 1])
            stack._array.removeLast(n)
            // Do something with value?
//            print("[\(id)] return \(value)")
        }
        else {
            // Do something with value?
//            print("[\(id)] return \(value)")
            status = .finished
        }
        return status
    }
    
    var instructionPointer: UnitScript.Code.Index {
        get { return Int(stack._array[framePointer]) }
        set(new) { stack._array[framePointer] = UnitScript.CodeUnit(new) }
    }
    
    func local(at index: CodeUnit) throws -> CodeUnit {
        let offset = framePointer + 1 + Int(index)
        guard offset < stack.count
            else { throw ExecutionError.badLocal(index) }
        return stack._array[offset]
    }
    
    func setLocal(at index: CodeUnit, to value: CodeUnit) throws {
        let offset = framePointer + 1 + Int(index)
        guard offset < stack.count
            else { throw ExecutionError.badLocal(index) }
        stack._array[offset] = value
    }
    
    func makeAxis(for value: CodeUnit) throws -> UnitScript.Axis {
        guard let axis = UnitScript.Axis(rawValue: value)
            else { throw ExecutionError.badAxis(value) }
        return axis
    }
    
    func isSignaled(by mask: CodeUnit) -> Bool {
        return (signalMask & mask) != 0
    }
    
    func run<Machine: ScriptMachine>(with context: UnitScript.Context, for instance: UnitModel.Instance, on machine: Machine) {
        let execution = ScriptExecutionContext(process: context, thread: self, model: instance, machine: machine)
        do {
            runLoop: while true {
                switch status {
                case .running:
                    let operation = try UnitScript.Thread.decode(opcode: context.script.code[instructionPointer])
                    try operation(execution)
                case .sleeping(let until):
                    if machine.getTime() > until {
                        //print("[\(id)] sleep over!")
                        status = .running
                    }
                    break runLoop
                case .waitingForMove:
                    //print("[\(id)] waiting for move")
                    break runLoop
                case .waitingForTurn:
                    //print("[\(id)] waiting for turn")
                    break runLoop
                case .finished:
                    //print("[\(id)] finished")
                    break runLoop
                }
            }
        }
        catch {
            print("[\(id)] Script Error: \(error)")
            status = .finished
        }
    }
    
    private static func decode(opcode raw: CodeUnit) throws -> Instruction {
        guard let opcode = UnitScript.Opcode(rawValue: raw) else { throw ExecutionError.badOpcode(raw) }
        guard let operation = Instructions[opcode] else { throw ExecutionError.unimplementedOpcode(raw) }
        return operation
    }
    
    enum ExecutionError: Error {
        case badOpcode(CodeUnit)
        case unimplementedOpcode(CodeUnit)
        case badLocal(CodeUnit)
        case badStatic(CodeUnit)
        case badModule(CodeUnit)
        case badPiece(CodeUnit)
        case badAxis(CodeUnit)
    }
    
}

// MARK:- Thread Stack

extension UnitScript.Thread.Stack {
    
    var count: Int {
        return _array.count
    }
    
    mutating func pop() throws -> Element {
        if let e = _array.popLast() { return e }
        else { throw Error.stackUnderflow }
    }
    
    mutating func pop(count n: Int) throws -> [Element] {
        guard n > 0 else { return [] }
        if _array.count >= n {
            defer { _array.removeLast(n) }
            return Array( _array.suffix(from: n-1) )
        }
        else { throw Error.stackUnderflow }
    }
    
    mutating func push(_ newElement: Element) {
        _array.append(newElement)
    }
    
    mutating func push<S>(contentsOf newElements: S) where Element == S.Element, S : Sequence {
        _array.append(contentsOf: newElements)
    }
    
    enum Error: Swift.Error {
        case stackUnderflow
    }
    
}

private extension UnitScript.Thread.Stack where Element == UnitScript.CodeUnit {
    
    mutating func push(_ newElement: Int) {
        _array.append(UnitScript.CodeUnit(newElement))
    }
    
    mutating func push(_ module: UnitScript.Module, with parameters: [UnitScript.CodeUnit]) {
        push(module.offset)
        push(contentsOf: parameters)
        if module.localCount > parameters.count {
            push(contentsOf: Array<UnitScript.CodeUnit>(repeating: 0, count: module.localCount - parameters.count))
        }
    }
    
}
