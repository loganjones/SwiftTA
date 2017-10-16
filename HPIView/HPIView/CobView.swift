//
//  CobView.swift
//  TAassets
//
//  Created by Logan Jones on 5/10/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Cocoa

class CobView: NSView {
    
    private unowned let textView: NSTextView
    
    override init(frame frameRect: NSRect) {
        
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: frameRect.size.width, height: frameRect.size.height))
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autoresizingMask = [.width, .height]
        
        let contentSize = scroll.contentSize
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        text.minSize = NSSize(width: 0, height: contentSize.height)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
        text.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        text.isEditable = false
        text.isSelectable = true
        self.textView = text
        
        super.init(frame: frameRect)
        
        scroll.documentView = text
        self.addSubview(scroll)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(_ script: UnitScript) {
        textView.string = ""
        guard let textStorage = textView.textStorage
            else { return }
        
        textStorage.beginEditing()
        var stack: [StackItem] = []
        var index = 0
        while index < script.code.count {
            if let m = script.modules.first(where: { $0.offset == index }) {
                if !stack.isEmpty {
                    textStorage.append("/* !!! STACK LEAK? !!! */\n")
                    stack.removeAll()
                }
                textStorage.append("\n"+m.name+":\n")
            }
            index = decode(script, at: index, stack: &stack) { line in
                textStorage.append(line+"\n")
            }
        }
        textStorage.endEditing()
        
        setNeedsDisplay(bounds)
    }
    
}

private func decode(_ script: UnitScript, at offset: UnitScript.Code.Index, stack: inout [StackItem], printLine: (String) -> ()) -> UnitScript.Code.Index {
    
    let code = script.code
    guard let instruction = UnitScript.Opcode(rawValue: code[offset])
        else { printLine(valueString(for: code[offset], at: offset) + "Unknown ???"); return offset + 1 }
    
    switch instruction {
        
    case .movePieceWithSpeed:
        let piece = code[offset + 1]
        let axis = code[offset + 2]
        let target = stack.pop()
        let speed = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "move piece with speed")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(valueString(for: axis, at: offset+2) + "axis: \(axis)")
        printLine(statementString()
            + "move " + script.pieceName(for: piece)
            + " to " + axisString(for: axis)
            + " " + target.linearValue()
            + " speed " + speed.linearValue()
            + ";" )
        return offset + 3
        
    case .turnPieceWithSpeed:
        let piece = code[offset + 1]
        let axis = code[offset + 2]
        let target = stack.pop()
        let speed = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "turn piece with speed")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(valueString(for: axis, at: offset+2) + "axis: \(axis)")
        printLine(statementString()
            + "turn " + script.pieceName(for: piece)
            + " to " + axisString(for: axis)
            + " " + target.angularValue()
            + " speed " + speed.angularValue()
            + ";" )
        return offset + 3
        
    case .startSpin:
        let piece = code[offset + 1]
        let axis = code[offset + 2]
        let speed = stack.pop()
        let accel = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "start spin")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(valueString(for: axis, at: offset+2) + "axis: \(axis)")
        printLine(statementString()
            + "start-spin " + script.pieceName(for: piece)
            + " around " + axisString(for: axis)
            + " speed " + speed.angularValue()
            + " accel " + accel.angularValue()
            + ";" )
        return offset + 3
        
    case .stopSpin:
        let piece = code[offset + 1]
        let axis = code[offset + 2]
        let deccel = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "stop spin")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(valueString(for: axis, at: offset+2) + "axis: \(axis)")
        printLine(statementString()
            + "stop-spin"
            + " "+script.pieceName(for: piece)
            + " around " + axisString(for: axis)
            + " deccel " + deccel.angularValue()
            + ";" )
        return offset + 3
        
    case .showPiece:
        let piece = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "show piece")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(statementString()
            + "show " + script.pieceName(for: piece)
            + ";" )
        return offset + 2
    case .hidePiece:
        let piece = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "hide piece")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(statementString()
            + "hide " + script.pieceName(for: piece)
            + ";" )
        return offset + 2
        
    case .cachePiece:
        let piece = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "cache piece")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(statementString()
            + "cache " + script.pieceName(for: piece)
            + ";" )
        return offset + 2
    case .dontCachePiece:
        let piece = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "dont cache piece")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(statementString()
            + "dont-cache " + script.pieceName(for: piece)
            + ";" )
        return offset + 2
        
    case .dontShadow:
        let piece = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "dont shadow piece")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(statementString()
            + "dont-shadow " + script.pieceName(for: piece)
            + ";" )
        return offset + 2
        
    case .movePieceNow:
        let piece = code[offset + 1]
        let axis = code[offset + 2]
        let target = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "move piece now")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(valueString(for: axis, at: offset+2) + "axis: \(axis)")
        printLine(statementString()
            + "move " + script.pieceName(for: piece)
            + " to " + axisString(for: axis)
            + " " + target.linearValue()
            + " now"
            + ";" )
        return offset + 3
        
    case .turnPieceNow:
        let piece = code[offset + 1]
        let axis = code[offset + 2]
        let target = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "turn piece now")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(valueString(for: axis, at: offset+2) + "axis: \(axis)")
        printLine(statementString()
            + "turn " + script.pieceName(for: piece)
            + " to " + axisString(for: axis)
            + " " + target.angularValue()
            + " now"
            + ";" )
        return offset + 3
        
    case .dontShade:
        let piece = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "dont shade piece")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(statementString()
            + "dont-shade " + script.pieceName(for: piece)+";"
            + ";" )
        return offset + 2
        
    case .emitSfx:
        let piece = code[offset + 1]
        let sfx = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "emit sfx from piece")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(statementString()
            + "emit-sfx " + sfx.expand()
            + " from " + script.pieceName(for: piece)
            + ";" )
        return offset + 2
        
    case .waitForTurn:
        let piece = code[offset + 1]
        let axis = code[offset + 2]
        printLine(statementString()
            + "wait-for-turn " + script.pieceName(for: piece)
            + " around " + axisString(for: axis)
            + ";" )
        return offset + 3
        
    case .waitForMove:
        let piece = code[offset + 1]
        let axis = code[offset + 2]
        printLine(statementString()
            + "wait-for-move " + script.pieceName(for: piece)
            + " along " + axisString(for: axis)
            + ";" )
        return offset + 3
        
    case .sleep:
        let time = stack.pop()
        printLine(statementString()
            + "sleep " + time.expand()
            + ";" )
        return offset + 1
        
    case .pushConstant:
        let value = code[offset + 1]
        stack.append(.constant(value))
        printLine(instructionString(for: instruction, at: offset) + "stack push value")
        printLine(valueString(for: value, at: offset+1) + "value: \(value)")
        return offset + 2
        
    case .pushLocalVariable:
        let index = code[offset + 1]
        stack.append(.local(index))
        printLine(instructionString(for: instruction, at: offset) + "stack push local")
        printLine(valueString(for: index, at: offset+1) + "local: \(index)")
        return offset + 2
        
    case .pushStaticVariable:
        let index = code[offset + 1]
        stack.append(.`static`(index))
        printLine(instructionString(for: instruction, at: offset) + "stack push static")
        printLine(valueString(for: index, at: offset+1) + "static: \(index)")
        return offset + 2
        
    case .stackAllocate:
        printLine(instructionString(for: instruction, at: offset) + "allocate local")
        return offset + 1
        
    case .setLocalVariable:
        let index = code[offset + 1]
        let value = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "set local variable")
        printLine(valueString(for: index, at: offset+1) + "local: \(index)")
        printLine(statementString() + StackItem.local(index).expand() + " = " + value.expand() + ";")
        return offset + 2
        
    case .setStaticVariable:
        let index = code[offset + 1]
        let value = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "set static variable")
        printLine(valueString(for: index, at: offset+1) + "static: \(index)")
        printLine(statementString() + StackItem.static(index).expand() + " = " + value.expand() + ";")
        return offset + 2
        
    case .popStack:
        printLine(instructionString(for: instruction, at: offset) + "stack pop")
        return offset + 1
        
    case .add:
        return binaryOperator("+", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .subtract:
        return binaryOperator("-", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .multiply:
        return binaryOperator("*", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .divide:
        return binaryOperator("/", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .bitwiseAnd:
        return binaryOperator("&", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .bitwiseOr:
        return binaryOperator("|", for: instruction, at: offset, stack: &stack, printLine: printLine)
        
    case .unknown1: printLine(instructionString(for: instruction, at: offset) + "UNKNOWN 1"); return offset + 1
    case .unknown2: printLine(instructionString(for: instruction, at: offset) + "UNKNOWN 2"); return offset + 1
    case .unknown3: printLine(instructionString(for: instruction, at: offset) + "UNKNOWN 3"); return offset + 1
        
    case .random:
        let max = stack.pop()
        let min = stack.pop()
        stack.append(.random(min,max))
        printLine(instructionString(for: instruction, at: offset) + "random")
        return offset + 1
        
    case .getUnitValue:
        let what = stack.pop()
        stack.append(.unitValue(what))
        printLine(instructionString(for: instruction, at: offset) + "get unit-value")
        return offset + 1
        
    case .getFunctionResult:
        let params: [StackItem] = [ stack.pop(), stack.pop(), stack.pop(), stack.pop() ].reversed()
        let what = stack.pop()
        stack.append(.function(what, params))
        printLine(instructionString(for: instruction, at: offset) + "get function result")
        return offset + 1
        
    case .lessThan:
        return binaryOperator("<", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .lessThanOrEqual:
        return binaryOperator("<=", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .greaterThan:
        return binaryOperator(">", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .greaterThanOrEqual:
        return binaryOperator(">=", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .equal:
        return binaryOperator("==", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .notEqual:
        return binaryOperator("!=", for: instruction, at: offset, stack: &stack, printLine: printLine)
    
    case .and:
        return binaryOperator("&&", for: instruction, at: offset, stack: &stack, printLine: printLine)
    case .or:
        return binaryOperator("||", for: instruction, at: offset, stack: &stack, printLine: printLine)
        
    case .not:
        return unaryOperator("!", for: instruction, at: offset, stack: &stack, printLine: printLine)
        
    case .startScript:
        let module = code[offset + 1]
        let params = stack.pop(count: code[offset + 2]).reversed()
        printLine(instructionString(for: instruction, at: offset) + "start script")
        printLine(valueString(for: module, at: offset+1) + "module: \(module)")
        printLine(valueString(for: code[offset + 2], at: offset+2) + "params: \(params.count)")
        printLine(statementString()
            + "start-script"
            + " "+script.moduleName(for: module)
            + "(\(params.map({ $0.expand() }).joined(separator: ", ")))"
            + ";" )
        return offset + 3
        
    case .callScript:
        let module = code[offset + 1]
        let params = stack.pop(count: code[offset + 2]).reversed()
        printLine(instructionString(for: instruction, at: offset) + "call script")
        printLine(valueString(for: module, at: offset+1) + "module: \(module)")
        printLine(valueString(for: code[offset + 2], at: offset+2) + "params: \(params.count)")
        printLine(statementString()
            + "call-script"
            + " "+script.moduleName(for: module)
            + "(\(params.map({ $0.expand() }).joined(separator: ", ")))"
            + ";" )
        return offset + 3
        
    case .jumpToOffset:
        let joffset = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "jump to offset")
        printLine(valueString(for: joffset, at: offset+1) + "offset: " + String(format: "%04X", joffset))
        return offset + 2
        
    case .`return`:
        printLine(statementString()
            + "return \(stack.pop().expand())"
            + ";" )
        return offset + 1
        
    case .jumpToOffsetIfFalse:
        let joffset = code[offset + 1]
        let condition = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "jump to offset if false")
        printLine(valueString(for: joffset, at: offset+1) + "offset: " + String(format: "%04X", joffset))
        printLine(statementString() + "if (" + condition.expand() + ")" )
        return offset + 2
        
    case .signal:
        let signal = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "send signal")
        printLine(statementString()
            + "signal " + signal.expand()
            + ";" )
        return offset + 1
        
    case .setSignalMask:
        let signal = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "set signal mask")
        printLine(statementString()
            + "set-signal-mask " + signal.expand()
            + ";" )
        return offset + 1
        
    case .explode:
        let piece = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "explode")
        printLine(valueString(for: piece, at: offset+1) + "piece: \(piece)")
        printLine(statementString()
            + "explode"
            + " "+script.pieceName(for: piece)
            + " type \(stack.pop().expand())"
            + ";" )
        return offset + 2
        
    case .playSound:
        let sound = code[offset + 1]
        printLine(instructionString(for: instruction, at: offset) + "play sound")
        printLine(valueString(for: sound, at: offset+1) + "sound: \(sound)")
        return offset + 2
        
    case .mapCommand:
        let param1 = code[offset + 1]
        let param2 = code[offset + 2]
        printLine(instructionString(for: instruction, at: offset) + "map command?")
        printLine(valueString(for: param1, at: offset+1) + "?: \(param1)")
        printLine(valueString(for: param2, at: offset+1) + "?: \(param2)")
        return offset + 3
        
    case .setUnitValue:
        let param = stack.pop()
        let what = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "set unit-value")
        printLine(statementString()
            + "set " + what.expand()
            + " to " + param.expand()
            + ";" )
        return offset + 1
        
    case .attachUnit:
        let something = stack.pop()
        let piece = stack.pop()
        let unit = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "attach unit")
        printLine(statementString()
            + "attach-unit " + unit.expand()
            + " to " + piece.expand()
            + ";" + " // " + something.expand() )
        return offset + 1
        
    case .dropUnit:
        let unit = stack.pop()
        printLine(instructionString(for: instruction, at: offset) + "drop unit")
        printLine(statementString()
            + "drop-unit " + unit.expand()
            + ";" )
        return offset + 1
    }
}

private func instructionString(for instruction: UnitScript.Opcode, at index: UnitScript.Code.Index) -> String {
    return String(format: "%04X    %08X ", index, instruction.rawValue)
}
private func valueString(for value: StackValue, at index: UnitScript.Code.Index) -> String {
    return String(format: "%04X    %08X ", index, value)
}
private func statementString() -> String {
    return String(format: "----    ")
}

private func axisString(for value: StackValue) -> String {
    if let axis = UnitScript.Axis(rawValue: value) {
        switch axis {
        case .x: return "x-axis"
        case .y: return "y-axis"
        case .z: return "z-axis"
        }
    }
    else {
        return "?-axis[\(value)]"
    }
}

private func unitValueString(for uv: UnitScript.UnitValue) -> String {
    switch uv {
    case .activation: return "ACTIVATION"
    case .standingMoveOrders: return "STANDINGMOVEORDERS"
    case .standingFireOrders: return "STANDINGFIREORDERS"
    case .health: return "HEALTH"
    case .inBuildStance: return "INBUILDSTANCE"
    case .busy: return "BUSY"
    case .pieceXZ: return "PIECE_XZ"
    case .pieceY: return "PIECE_Y"
    case .unitXZ: return "UNIT_XZ"
    case .unitY: return "UNIT_Y"
    case .unitHeight: return "UNIT_HEIGHT"
    case .xzAtan: return "XZ_ATAN"
    case .xzHypot: return "XZ_HYPOT"
    case .atan: return "ATAN"
    case .hypot: return "HYPOT"
    case .groundHeight: return "GROUND_HEIGHT"
    case .buildPercentLeft: return "BUILD_PERCENT_LEFT"
    case .yardOpen: return "YARD_OPEN"
    case .buggerOff: return "BUGGER_OFF"
    case .armored: return "ARMORED"
    }
}

private typealias StackValue = UnitScript.CodeUnit

private func binaryOperator(_ op: String, for instruction: UnitScript.Opcode, at offset: UnitScript.Code.Index, stack: inout [StackItem], printLine: (String) -> ()) -> UnitScript.Code.Index {
    let rhs = stack.pop()
    let lhs = stack.pop()
    stack.append(.binaryOperator(op, lhs, rhs))
    printLine(instructionString(for: instruction, at: offset) + "binary operator " + op)
    return offset + 1
}

private func unaryOperator(_ op: String, for instruction: UnitScript.Opcode, at offset: UnitScript.Code.Index, stack: inout [StackItem], printLine: (String) -> ()) -> UnitScript.Code.Index {
    let rhs = stack.pop()
    stack.append(.unaryOperator(op, rhs))
    printLine(instructionString(for: instruction, at: offset) + "unary operator " + op)
    return offset + 1
}

private enum StackItem {
    case constant(StackValue)
    case local(StackValue)
    case `static`(StackValue)
    indirect case binaryOperator(String, StackItem, StackItem)
    indirect case unaryOperator(String, StackItem)
    case underflow
    indirect case random(StackItem, StackItem)
    indirect case unitValue(StackItem)
    indirect case function(StackItem,[StackItem])
}

private extension StackItem {
    func expand(style: ValueStyle = .normal) -> String {
        switch self {
        case .constant(let v):
            switch style {
            case .normal: return String(v)
            case .linear: return String(Double(v) / LINEAR_CONSTANT)
            case .angular:return String(Double(v) / ANGULAR_CONSTANT)
            }
        case .local(let i): return "local[\(i)]"
        case .`static`(let i): return "static[\(i)]"
        case .underflow: return "UNDERFLOW"
        case let .binaryOperator(op, lhs, rhs):
            return "(\(lhs.expand()) \(op) \(rhs.expand()))"
        case let .unaryOperator(op, rhs):
            return "(\(op) \(rhs.expand()))"
        case let .random(min, max):
            return "random("+min.expand()+", "+max.expand()+")"
        case let .unitValue(what):
            guard case .constant(let index) = what,
                let uv = UnitScript.UnitValue(rawValue: index)
                else { return "get unit-value[" + what.expand() + "]" }
            return "get " + unitValueString(for: uv)
        case let .function(what, params):
            let paramsString = "(" + params.map({ $0.expand() }).joined(separator: ", ") + ")"
            guard case .constant(let index) = what,
                let f = UnitScript.UnitValue(rawValue: index)
                else { return "get function[" + what.expand() + "]" + paramsString }
            return "get " + unitValueString(for: f) + paramsString
        }
    }
    enum ValueStyle {
        case normal
        case linear
        case angular
    }
    func linearValue() -> String {
        return "[" + expand(style: .linear) + "]"
    }
    func angularValue() -> String {
        return "<" + expand(style: .angular) + ">"
    }
}

private extension Array where Element == StackItem {
    mutating func pop() -> StackItem {
        if count > 0 { return removeLast() }
        else { return .underflow }
    }
    mutating func pop(count: StackValue) -> [StackItem] {
        return (0 ..< count).map { _ in pop() }
    }
}

private extension UnitScript {
    
    func pieceName(for pieceIndex: UnitScript.CodeUnit) -> String {
        return self.pieces[Int(pieceIndex)]
    }
    func moduleName(for moduleIndex: UnitScript.CodeUnit) -> String {
        return self.modules[Int(moduleIndex)].name
    }
    
}

private extension NSTextStorage {
    
    func append(_ s: String) {
        let text = NSAttributedString(string: s)
        self.append(text)
    }
    
}
