//
//  UnitScript+CobDecompile.swift
//  TAassets
//
//  Created by Logan Jones on 3/8/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


extension UnitScript {
    
    func decompile(writingTo output: @escaping (String) -> (), options: CobDecompile.OutputOptions = .defaults) {
        
        let script = self
        var formatter = CobDecompile.OutputFormatter(rawOutput: output, options: options)
        var context = CobDecompile.DecodeContext(pieces: script.pieces, modules: script.modules.map({$0.name}))
        var index = 0
        
        output("// Decompiled Script\n\n")
        output("piece " + script.pieces.joined(separator: ", ") + ";\n\n")
        
        context.staticVariables = Array<String>(count: script.numberOfStaticVariables, eachValue: { i in "static"+String(i+1) })
        if context.staticVariables.count > 0 {
            output("static-var " + context.staticVariables.joined(separator: ", ") + ";\n\n")
        }
        
        while true {
            if let m = script.modules.first(where: { $0.offset == index }) {
                if !context.stack.isEmpty {
                    output("/* !!! STACK LEAK? !!! */\n")
                    context.stack.removeAll()
                }
                formatter.clearScopes()
                if index > 0 {
                    output("\t}\n\n")
                }
                
                context.localVariables = Array<String>(count: m.localCount, eachValue: { i in "local"+String(i+1) })
                
                var parameterList = ""
                var localList = ""
                
                if let hint = CobDecompile.Hints(forModule: m.name) {
                    var localsStartIndex = 0
                    if m.localCount > 0 && hint.parameters.count > 0 {
                        let params = hint.parameters[0..<min(m.localCount, hint.parameters.count)]
                        context.localVariables.replaceElements(withContentsOf: params)
                        parameterList = params.joined(separator: ", ")
                        localsStartIndex = params.count
                    }
                    if (m.localCount - localsStartIndex) > 0 {
                        context.localVariables.replaceElements(withContentsOf: hint.locals, startingAt: localsStartIndex)
                        localList = context.localVariables[localsStartIndex..<m.localCount].joined(separator: ", ")
                    }
                }
                else {
                    localList = context.localVariables[0..<m.localCount].joined(separator: ", ")
                }
                
                output("\n"+m.name+"("+parameterList+")\n\t{\n")
                
                if !localList.isEmpty {
                    output("\n\tvar "+localList+";\n\n")
                }
            }
            else if index >= script.code.count {
                context.localVariables = []
                formatter.endScopes(for: index)
                output("\t}\n\n")
                break
            }
            formatter.endScopes(for: index)
            index = CobDecompile.decodeInstruction(at: index, in: script.code, context: &context, output: &formatter)
        }
    }
    
}

enum CobDecompile {
}

// MARK:- Output Formatting

extension CobDecompile {
    
    struct OutputOptions {
        var shouldPrintInstructions: Bool
        var shouldPrintOperands: Bool
        var shouldPrintStatements: Bool
        var indent: String
        
        init(shouldPrintInstructions: Bool = false,
             shouldPrintOperands: Bool = false,
             shouldPrintStatements: Bool = true,
             indent: String = "    ") {
            self.shouldPrintInstructions = shouldPrintInstructions
            self.shouldPrintOperands = shouldPrintOperands
            self.shouldPrintStatements = shouldPrintStatements
            self.indent = indent
        }
        
        static var defaults = OutputOptions()
    }
    
    struct OutputFormatter {
        
        var rawOutput: (String) -> ()
        var options: OutputOptions
        
        fileprivate var scopes: [Int] = []
    }
    
}

extension CobDecompile.OutputFormatter {
    
    init(rawOutput: @escaping (String) -> (), options: CobDecompile.OutputOptions = .defaults) {
        self.rawOutput = rawOutput
        self.options = options
    }
    
    func printInstruction(_ instruction: UnitScript.Opcode, at offset: Int, description: String, operands: (UnitScript.CodeUnit, String)...) {
        guard options.shouldPrintInstructions else { return }
        
        let instructionLine = String(format: "// %04X    %08X  ", offset, instruction.rawValue) + description
        let operandLines = options.shouldPrintOperands ? operands.enumerated().map {
            String(format: "// %04X      %08X  ", offset + $0.offset, $0.element.0) + $0.element.1
            } : []
        
        let string = ([instructionLine] + operandLines).joined(separator: "\n")
        rawOutput(string+"\n")
    }
    
    func printUnknown(_ value: UnitScript.CodeUnit, at offset: Int) {
        let line = String(format: "// %04X    %08X  ", offset, value) + "!!! Unknown opcode !!!"
        rawOutput(line+"\n")
    }
    
    func printStatement(_ s: String) {
        guard options.shouldPrintStatements else { return }
        rawOutput(indent+s+"\n")
    }
    
    var indent: String {
        return String(repeating: options.indent, count: scopes.count+1)
    }
    
    mutating func addScope(until offset: Int) {
        scopes.append(offset)
        rawOutput(String(repeating: "\t", count: scopes.count+1)+"{\n")
    }
    
    mutating func endScopes(for offset: Int) {
        while let a = scopes.last, a <= offset {
            rawOutput(indent + "}\n")
            scopes.removeLast()
        }
    }
    
    mutating func clearScopes() {
        var n = scopes.count+1
        for _ in 0..<scopes.count {
            rawOutput(String(repeating: "\t", count: n) + "}\n")
            n -= 1
        }
        scopes.removeAll()
    }
    
}

// MARK:- Decode Context

extension CobDecompile {
    
    struct DecodeContext {
        var pieces: [String] = []
        var modules: [String] = []
        var staticVariables: [String] = []
        var localVariables: [String] = []
        var stack: [StackItem] = []
    }
    
}

extension CobDecompile.DecodeContext {
    
    init(pieces: [String], modules: [String]) {
        self.pieces = pieces
        self.modules = modules
    }
    
    func pieceName(for pieceIndex: CobDecompile.StackValue) -> String {
        return pieces[safe: Int(pieceIndex)] ?? "piece\(pieceIndex)?"
    }
    
    func moduleName(for moduleIndex: CobDecompile.StackValue) -> String {
        return modules[safe: Int(moduleIndex)] ?? "module\(moduleIndex)?"
    }
    
    func axisName(for axisIndex: CobDecompile.StackValue) -> String {
        guard let axis = UnitScript.Axis(rawValue: axisIndex) else { return "?\(axisIndex)?-axis" }
        return axis.scriptIdentifier
    }
    
}

// MARK:- Instruction Decoding

extension CobDecompile {
    
    static func decodeInstruction(at offset: UnitScript.Code.Index, in code: UnitScript.Code, context: inout DecodeContext, output: inout OutputFormatter) -> UnitScript.Code.Index {
        
        guard let instruction = UnitScript.Opcode(rawValue: code[offset])
            else { output.printUnknown(code[offset], at: offset); return offset + 1 }
        
        switch instruction {
            
        case .movePieceWithSpeed:
            let piece = code[offset + 1]
            let axis = code[offset + 2]
            let target = context.stack.pop()
            let speed = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "move piece with speed",
                operands: (piece, "piece"), (axis, "axis") )
            output.printStatement(
                "move " + context.pieceName(for: piece)
                    + " to " + context.axisName(for: axis)
                    + " " + target.linearValue(with: context)
                    + " speed " + speed.linearValue(with: context)
                    + ";" )
            return offset + 3
            
        case .turnPieceWithSpeed:
            let piece = code[offset + 1]
            let axis = code[offset + 2]
            let target = context.stack.pop()
            let speed = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "turn piece with speed",
                operands: (piece, "piece"), (axis, "axis") )
            output.printStatement(
                "turn " + context.pieceName(for: piece)
                    + " to " + context.axisName(for: axis)
                    + " " + target.angularValue(with: context)
                    + " speed " + speed.angularValue(with: context)
                    + ";" )
            return offset + 3
            
        case .startSpin:
            let piece = code[offset + 1]
            let axis = code[offset + 2]
            let speed = context.stack.pop()
            let accel = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "start spin",
                operands: (piece, "piece"), (axis, "axis") )
            output.printStatement(
                "start-spin " + context.pieceName(for: piece)
                    + " around " + context.axisName(for: axis)
                    + " speed " + speed.angularValue(with: context)
                    + " accel " + accel.angularValue(with: context)
                    + ";" )
            return offset + 3
            
        case .stopSpin:
            let piece = code[offset + 1]
            let axis = code[offset + 2]
            let deccel = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "stop spin",
                operands: (piece, "piece"), (axis, "axis") )
            output.printStatement(
                "stop-spin"
                    + " "+context.pieceName(for: piece)
                    + " around " + context.axisName(for: axis)
                    + " deccel " + deccel.angularValue(with: context)
                    + ";" )
            return offset + 3
            
        case .showPiece:
            let piece = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "show piece",
                operands: (piece, "piece") )
            output.printStatement(
                "show " + context.pieceName(for: piece)
                    + ";" )
            return offset + 2
        case .hidePiece:
            let piece = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "hide piece",
                operands: (piece, "piece") )
            output.printStatement(
                "hide " + context.pieceName(for: piece)
                    + ";" )
            return offset + 2
            
        case .cachePiece:
            let piece = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "cache piece",
                operands: (piece, "piece") )
            output.printStatement(
                "cache " + context.pieceName(for: piece)
                    + ";" )
            return offset + 2
        case .dontCachePiece:
            let piece = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "dont cache piece",
                operands: (piece, "piece") )
            output.printStatement(
                "dont-cache " + context.pieceName(for: piece)
                    + ";" )
            return offset + 2
            
        case .dontShadow:
            let piece = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "dont shadow piece",
                operands: (piece, "piece") )
            output.printStatement(
                "dont-shadow " + context.pieceName(for: piece)
                    + ";" )
            return offset + 2
            
        case .movePieceNow:
            let piece = code[offset + 1]
            let axis = code[offset + 2]
            let target = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "move piece now",
                operands: (piece, "piece"), (axis, "axis") )
            output.printStatement(
                "move " + context.pieceName(for: piece)
                    + " to " + context.axisName(for: axis)
                    + " " + target.linearValue(with: context)
                    + " now"
                    + ";" )
            return offset + 3
            
        case .turnPieceNow:
            let piece = code[offset + 1]
            let axis = code[offset + 2]
            let target = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "turn piece now",
                operands: (piece, "piece"), (axis, "axis") )
            output.printStatement(
                "turn " + context.pieceName(for: piece)
                    + " to " + context.axisName(for: axis)
                    + " " + target.angularValue(with: context)
                    + " now"
                    + ";" )
            return offset + 3
            
        case .dontShade:
            let piece = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "dont shade piece",
                operands: (piece, "piece") )
            output.printStatement(
                "dont-shade " + context.pieceName(for: piece)+";"
                    + ";" )
            return offset + 2
            
        case .emitSfx:
            let piece = code[offset + 1]
            let sfx = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "emit sfx from piece",
                operands: (piece, "piece") )
            output.printStatement(
                "emit-sfx " + sfx.expand(with: context, style: .sfx)
                    + " from " + context.pieceName(for: piece)
                    + ";" )
            return offset + 2
            
        case .waitForTurn:
            let piece = code[offset + 1]
            let axis = code[offset + 2]
            output.printInstruction(
                instruction, at: offset, description: "wait for turn",
                operands: (piece, "piece"), (axis, "axis") )
            output.printStatement(
                "wait-for-turn " + context.pieceName(for: piece)
                    + " around " + context.axisName(for: axis)
                    + ";" )
            return offset + 3
            
        case .waitForMove:
            let piece = code[offset + 1]
            let axis = code[offset + 2]
            output.printInstruction(
                instruction, at: offset, description: "wait for move",
                operands: (piece, "piece"), (axis, "axis") )
            output.printStatement(
                "wait-for-move " + context.pieceName(for: piece)
                    + " along " + context.axisName(for: axis)
                    + ";" )
            return offset + 3
            
        case .sleep:
            let time = context.stack.pop()
            output.printInstruction(instruction, at: offset, description: "sleep")
            output.printStatement(
                "sleep " + time.expand(with: context)
                    + ";" )
            return offset + 1
            
        case .pushImmediate:
            let value = code[offset + 1]
            context.stack.append(.constant(value))
            output.printInstruction(
                instruction, at: offset, description: "stack push value",
                operands: (value, "value") )
            return offset + 2
            
        case .pushLocal:
            let index = code[offset + 1]
            context.stack.append(.local(index))
            output.printInstruction(
                instruction, at: offset, description: "stack push local",
                operands: (index, "index") )
            return offset + 2
            
        case .pushStatic:
            let index = code[offset + 1]
            context.stack.append(.`static`(index))
            output.printInstruction(
                instruction, at: offset, description: "stack push static",
                operands: (index, "index") )
            return offset + 2
            
        case .stackAllocate:
            output.printInstruction(instruction, at: offset, description: "allocate local")
            return offset + 1
            
        case .setLocal:
            let index = code[offset + 1]
            let value = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "set local variable",
                operands: (index, "index") )
            output.printStatement(StackItem.local(index).expand(with: context) + " = " + value.expand(with: context) + ";")
            return offset + 2
            
        case .setStatic:
            let index = code[offset + 1]
            let value = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "set static variable",
                operands: (index, "index") )
            output.printStatement(StackItem.static(index).expand(with: context) + " = " + value.expand(with: context) + ";")
            return offset + 2
            
        case .popStack:
            output.printInstruction(instruction, at: offset, description: "stack pop")
            return offset + 1
            
        case .add:
            return binaryOperator(.add, for: instruction, at: offset, context: &context, output: output)
        case .subtract:
            return binaryOperator(.subtract, for: instruction, at: offset, context: &context, output: output)
        case .multiply:
            return binaryOperator(.multiply, for: instruction, at: offset, context: &context, output: output)
        case .divide:
            return binaryOperator(.divide, for: instruction, at: offset, context: &context, output: output)
        case .bitwiseAnd:
            return binaryOperator(.bitwiseAnd, for: instruction, at: offset, context: &context, output: output)
        case .bitwiseOr:
            return binaryOperator(.bitwiseOr, for: instruction, at: offset, context: &context, output: output)
            
        case .unknown1, .unknown2, .unknown3:
            output.printInstruction(instruction, at: offset, description: "Unknown Instruction")
            output.printStatement("// Unknown instruction (0x\(String(instruction.rawValue, radix: 16))")
            return offset + 1
            
        case .random:
            let max = context.stack.pop()
            let min = context.stack.pop()
            context.stack.append(.random(min,max))
            output.printInstruction(instruction, at: offset, description: "random")
            return offset + 1
            
        case .getUnitValue:
            let what = context.stack.pop()
            context.stack.append(.unitValue(what))
            output.printInstruction(instruction, at: offset, description: "get unit-value")
            return offset + 1
            
        case .getFunctionResult:
            let params: [StackItem] = [ context.stack.pop(), context.stack.pop(), context.stack.pop(), context.stack.pop() ].reversed()
            let what = context.stack.pop()
            context.stack.append(.function(what, params))
            output.printInstruction(instruction, at: offset, description: "get function result")
            return offset + 1
            
        case .lessThan:
            return binaryOperator(.lessThan, for: instruction, at: offset, context: &context, output: output)
        case .lessThanOrEqual:
            return binaryOperator(.lessThanOrEqual, for: instruction, at: offset, context: &context, output: output)
        case .greaterThan:
            return binaryOperator(.greaterThan, for: instruction, at: offset, context: &context, output: output)
        case .greaterThanOrEqual:
            return binaryOperator(.greaterThanOrEqual, for: instruction, at: offset, context: &context, output: output)
        case .equal:
            return binaryOperator(.equal, for: instruction, at: offset, context: &context, output: output)
        case .notEqual:
            return binaryOperator(.notEqual, for: instruction, at: offset, context: &context, output: output)
            
        case .and:
            return binaryOperator(.and, for: instruction, at: offset, context: &context, output: output)
        case .or:
            return binaryOperator(.or, for: instruction, at: offset, context: &context, output: output)
            
        case .not:
            return unaryOperator(.not, for: instruction, at: offset, context: &context, output: output)
            
        case .startScript:
            let module = code[offset + 1]
            let params = context.stack.pop(count: code[offset + 2]).reversed()
            output.printInstruction(
                instruction, at: offset, description: "start script",
                operands: (module, "module"), (code[offset + 2], "parameter count") )
            output.printStatement(
                "start-script"
                    + " "+context.moduleName(for: module)
                    + "(\(params.map({ $0.expand(with: context) }).joined(separator: ", ")))"
                    + ";" )
            return offset + 3
            
        case .callScript:
            let module = code[offset + 1]
            let params = context.stack.pop(count: code[offset + 2]).reversed()
            output.printInstruction(
                instruction, at: offset, description: "call script",
                operands: (module, "module"), (code[offset + 2], "parameter count") )
            output.printStatement(
                "call-script"
                    + " "+context.moduleName(for: module)
                    + "(\(params.map({ $0.expand(with: context) }).joined(separator: ", ")))"
                    + ";" )
            return offset + 3
            
        case .jumpToOffset:
            let joffset = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "jump to offset",
                operands: (joffset, "offset") )
            return offset + 2
            
        case .`return`:
            output.printInstruction(instruction, at: offset, description: "return")
            output.printStatement(
                "return \(context.stack.pop().expand(with: context))"
                    + ";" )
            return offset + 1
            
        case .jumpToOffsetIfFalse:
            let joffset = code[offset + 1]
            let condition = context.stack.pop()
            output.printInstruction(
                instruction, at: offset, description: "jump to offset if false",
                operands: (joffset, "offset") )
            if checkForWhile(at: offset, in: code) {
                output.printStatement("while (" + condition.expand(with: context, style: .boolean) + ")")
            }
            else {
                output.printStatement("if (" + condition.expand(with: context, style: .boolean) + ")")
            }
            output.addScope(until: Int(joffset))
            return offset + 2
            
        case .signal:
            let signal = context.stack.pop()
            output.printInstruction(instruction, at: offset, description: "send signal")
            output.printStatement(
                "signal " + signal.expand(with: context)
                    + ";" )
            return offset + 1
            
        case .setSignalMask:
            let signal = context.stack.pop()
            output.printInstruction(instruction, at: offset, description: "set signal mask")
            output.printStatement(
                "set-signal-mask " + signal.expand(with: context)
                    + ";" )
            return offset + 1
            
        case .explode:
            let piece = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "explode",
                operands: (piece, "piece") )
            output.printStatement(
                "explode"
                    + " "+context.pieceName(for: piece)
                    + " type \(context.stack.pop().expand(with: context, style: .explode))"
                    + ";" )
            return offset + 2
            
        case .playSound:
            let sound = code[offset + 1]
            output.printInstruction(
                instruction, at: offset, description: "play sound",
                operands: (sound, "sound") )
            output.printStatement(
                "// play-sound"
                    + " "+String(sound)
                    + ";" )
            return offset + 2
            
        case .mapCommand:
            let param1 = code[offset + 1]
            let param2 = code[offset + 2]
            output.printInstruction(
                instruction, at: offset, description: "map command?",
                operands: (param1, "param1"), (param2, "param2") )
            output.printStatement(
                "// map-command"
                    + " "+String(param1)
                    + " "+String(param2)
                    + ";" )
            return offset + 3
            
        case .setUnitValue:
            let param = context.stack.pop()
            let what = context.stack.pop()
            let s: String
            if case .constant(let index) = what, let f = UnitScript.UnitValue(rawValue: index) { s = f.scriptIdentifier }
            else { s = what.expand(with: context) }
            output.printInstruction(instruction, at: offset, description: "set unit-value")
            output.printStatement(
                "set " + s
                    + " to " + param.expand(with: context)
                    + ";" )
            return offset + 1
            
        case .attachUnit:
            let something = context.stack.pop()
            let piece = context.stack.pop()
            let unit = context.stack.pop()
            output.printInstruction(instruction, at: offset, description: "attach unit")
            output.printStatement(
                "attach-unit " + unit.expand(with: context)
                    + " to " + piece.expand(with: context, style: .piece)
                    + ";" + " // " + something.expand(with: context) )
            return offset + 1
            
        case .dropUnit:
            let unit = context.stack.pop()
            output.printInstruction(instruction, at: offset, description: "drop unit")
            output.printStatement(
                "drop-unit " + unit.expand(with: context)
                    + ";" )
            return offset + 1
        }
    }
    
    static func checkForWhile(at offset: Int, in code: UnitScript.Code) -> Bool {
        let joffset = Int(code[offset + 1])
        
        // The jumpToOffsetIfFalse target must be ahead of the input offset.
        guard joffset > offset else { return false }
        
        // Check if the instruction just before the jumpToOffsetIfFalse target is a jumpToOffset
        guard let instruction = UnitScript.Opcode(rawValue: code[joffset - 2]), instruction == .jumpToOffset else { return false }
        
        // If the jumpToOffset target must be the input offset of before (for stack filling).
        guard code[joffset - 1] <= offset else { return false }
        
        // It's probably a while loop!
        return true
    }
    
    static func binaryOperator(_ op: StackBinaryOperator, for instruction: UnitScript.Opcode, at offset: UnitScript.Code.Index, context: inout DecodeContext, output: OutputFormatter) -> UnitScript.Code.Index {
        let rhs = context.stack.pop()
        let lhs = context.stack.pop()
        context.stack.append(.binaryOperator(op, lhs, rhs))
        output.printInstruction(instruction, at: offset, description: "binary operator " + op.symbol)
        return offset + 1
    }
    
    static func unaryOperator(_ op: StackUnaryOperator, for instruction: UnitScript.Opcode, at offset: UnitScript.Code.Index, context: inout DecodeContext, output: OutputFormatter) -> UnitScript.Code.Index {
        let rhs = context.stack.pop()
        context.stack.append(.unaryOperator(op, rhs))
        output.printInstruction(instruction, at: offset, description: "unary operator " + op.symbol)
        return offset + 1
    }
    
}

// MARK:- Script Identifiers

extension UnitScript.Axis {
    var scriptIdentifier: String {
        switch self {
        case .x:                return "x-axis"
        case .y:                return "y-axis"
        case .z:                return "z-axis"
        }
    }
}

extension UnitScript.UnitValue {
    var scriptIdentifier: String {
        switch self {
        case .activation:       return "ACTIVATION"
        case .standingMoveOrders: return "STANDINGMOVEORDERS"
        case .standingFireOrders: return "STANDINGFIREORDERS"
        case .health:           return "HEALTH"
        case .inBuildStance:    return "INBUILDSTANCE"
        case .busy:             return "BUSY"
        case .pieceXZ:          return "PIECE_XZ"
        case .pieceY:           return "PIECE_Y"
        case .unitXZ:           return "UNIT_XZ"
        case .unitY:            return "UNIT_Y"
        case .unitHeight:       return "UNIT_HEIGHT"
        case .xzAtan:           return "XZ_ATAN"
        case .xzHypot:          return "XZ_HYPOT"
        case .atan:             return "ATAN"
        case .hypot:            return "HYPOT"
        case .groundHeight:     return "GROUND_HEIGHT"
        case .buildPercentLeft: return "BUILD_PERCENT_LEFT"
        case .yardOpen:         return "YARD_OPEN"
        case .buggerOff:        return "BUGGER_OFF"
        case .armored:          return "ARMORED"
        }
    }
}

extension UnitScript.ExplodeType {
    var scriptIdentifier: String {
        switch self {
        case .shatter:          return "SHATTER"
        case .explodeOnHit:     return "EXPLODE_ON_HIT"
        case .fall:             return "FALL"
        case .smoke:            return "SMOKE"
        case .fire:             return "FIRE"
        case .bitmapOnly:       return "BITMAPONLY"
        case .bitmap1:          return "BITMAP1"
        case .bitmap2:          return "BITMAP2"
        case .bitmap3:          return "BITMAP3"
        case .bitmap4:          return "BITMAP4"
        case .bitmap5:          return "BITMAP5"
        case .bitmapNuke:       return "BITMAPNUKE"
        case .bitmapMask:       return "BITMAPMASK"
        }
    }
}

private extension UnitScript.SfxType {
    var scriptIdentifier: String {
        switch self {
        case .vtol:             return "SFXTYPE_VTOL"
        case .thrust:           return "SFXTYPE_THRUST"
        case .wake1:            return "SFXTYPE_WAKE1"
        case .wake2:            return "SFXTYPE_WAKE2"
        case .reverseWake1:     return "SFXTYPE_REVERSEWAKE1"
        case .reverseWake2:     return "SFXTYPE_REVERSEWAKE2"
        case .pointBased:       return "SFXTYPE_POINTBASED"
        case .whiteSmoke:       return "SFXTYPE_WHITESMOKE"
        case .blackSmoke:       return "SFXTYPE_BLACKSMOKE"
        case .subBubbles:       return "SFXTYPE_SUBBUBBLES"
        }
    }
}

// MARK:- StackItem

extension CobDecompile {
    
    typealias StackValue = UnitScript.CodeUnit
    
    enum StackItem {
        case constant(StackValue)
        case local(StackValue)
        case `static`(StackValue)
        indirect case binaryOperator(StackBinaryOperator, StackItem, StackItem)
        indirect case unaryOperator(StackUnaryOperator, StackItem)
        case underflow
        indirect case random(StackItem, StackItem)
        indirect case unitValue(StackItem)
        indirect case function(StackItem,[StackItem])
    }
    
    struct StackBinaryOperator: Equatable {
        var symbol: String
        var precedence: Int
        
        static let add                  = StackBinaryOperator(symbol: "+",  precedence: 6)
        static let subtract             = StackBinaryOperator(symbol: "-",  precedence: 6)
        static let multiply             = StackBinaryOperator(symbol: "*",  precedence: 5)
        static let divide               = StackBinaryOperator(symbol: "/",  precedence: 5)
        static let bitwiseAnd           = StackBinaryOperator(symbol: "&",  precedence: 11)
        static let bitwiseOr            = StackBinaryOperator(symbol: "|",  precedence: 13)
        static let lessThan             = StackBinaryOperator(symbol: "<",  precedence: 9)
        static let lessThanOrEqual      = StackBinaryOperator(symbol: "<=", precedence: 9)
        static let greaterThan          = StackBinaryOperator(symbol: ">",  precedence: 9)
        static let greaterThanOrEqual   = StackBinaryOperator(symbol: ">=", precedence: 9)
        static let equal                = StackBinaryOperator(symbol: "==", precedence: 10)
        static let notEqual             = StackBinaryOperator(symbol: "!=", precedence: 10)
        static let and                  = StackBinaryOperator(symbol: "&&", precedence: 14)
        static let or                   = StackBinaryOperator(symbol: "||", precedence: 15)
    }
    
    struct StackUnaryOperator: Equatable {
        var symbol: String
        var precedence: Int
        
        static let not                  = StackUnaryOperator(symbol: "!",  precedence: 3)
    }
    
}

private extension Array where Element == CobDecompile.StackItem {
    
    mutating func pop() -> CobDecompile.StackItem {
        if count > 0 { return removeLast() }
        else { return .underflow }
    }
    
    mutating func pop(count: CobDecompile.StackValue) -> [CobDecompile.StackItem] {
        return (0 ..< count).map { _ in pop() }
    }
    
}

// MARK:- StackItem Expansion

extension CobDecompile.StackItem {
    
    func expand(with context: CobDecompile.DecodeContext, style: ValueStyle = .normal) -> String {
        switch self {
            
        case .constant(let v):
            switch style {
            case .normal:   return String(v)
            case .linear:   return String(Double(v) / LINEAR_CONSTANT)
            case .angular:  return String(Double(v) / ANGULAR_CONSTANT)
            case .boolean:  return (v != 0) ? "TRUE" : "FALSE"
            case .piece:    return context.pieceName(for: v)
            case .explode:  return UnitScript.ExplodeType(rawValue: v)?.scriptIdentifier ?? String(v)
            case .sfx:      return UnitScript.SfxType(rawValue: v)?.scriptIdentifier ?? String(v)
            }
            
        case .local(let i):
            guard let identifier = context.localVariables[safe: Int(i)] else {
                return "local\(i+1)"
            }
            return identifier
            
        case .`static`(let i):
            guard let identifier = context.staticVariables[safe: Int(i)] else {
                return "static\(i+1)"
            }
            return identifier
            
        case .underflow: return "UNDERFLOW"
            
        case let .binaryOperator(op, lhs, rhs):
            if let sfx = sfxPointBasedExpression(style: style) { return sfx }
            let style = stripBoolean(ifNonBooleanOp: op, style: style)
            let left = lhs.expand(with: context, style: style).wrapped(lhs.precedence > op.precedence)
            let right = rhs.expand(with: context, style: style).wrapped(rhs.precedence > op.precedence)
            return "\(left) \(op.symbol) \(right)"
            
        case let .unaryOperator(op, rhs):
            let right = rhs.expand(with: context, style: style).wrapped(rhs.precedence > op.precedence)
            return "\(op.symbol)\(right)"
            
        case let .random(min, max):
            return "rand("+min.expand(with: context)+", "+max.expand(with: context)+")"
            
        case let .unitValue(what):
            guard case .constant(let index) = what,
                let uv = UnitScript.UnitValue(rawValue: index)
                else { return "get unit-value[" + what.expand(with: context) + "]" }
            return "get " + uv.scriptIdentifier
            
        case let .function(what, params):
            let paramsString = "(" + params.map({ $0.expand(with: context) }).joined(separator: ", ") + ")"
            guard case .constant(let index) = what,
                let f = UnitScript.UnitValue(rawValue: index)
                else { return "get function[" + what.expand(with: context) + "]" + paramsString }
            return "get " + f.scriptIdentifier + paramsString
            
        }
    }
    
    enum ValueStyle {
        case normal
        case linear
        case angular
        case boolean
        case piece
        case explode
        case sfx
    }
    
    func linearValue(with context: CobDecompile.DecodeContext) -> String {
        return "[" + expand(with: context, style: .linear) + "]"
    }
    
    func angularValue(with context: CobDecompile.DecodeContext) -> String {
        return "<" + expand(with: context, style: .angular) + ">"
    }
    
    var isLeaf: Bool {
        switch self {
        case .constant, .local, .`static`: return true
        case .underflow: return true
        case .binaryOperator: return false
        case .unaryOperator: return false
        case .random: return true
        case .unitValue: return false
        case .function: return true
        }
    }
    
    var precedence: Int {
        switch self {
        case .constant, .local, .`static`: return 1
        case .underflow: return 1
        case .binaryOperator(let op,_,_): return op.precedence
        case .unaryOperator(let op,_): return op.precedence
        case .random: return 2
        case .unitValue: return 20
        case .function: return 2
        }
    }
    
    func stripBoolean(ifNonBooleanOp op: CobDecompile.StackBinaryOperator, style: ValueStyle) -> ValueStyle {
        guard case .boolean = style else { return style }
        switch op {
        case .and, .or: return .boolean
        default: return .normal
        }
    }
    
    func sfxPointBasedExpression(style: ValueStyle) -> String? {
        // Early out; only continue if the desired output style if SFX.
        guard style == .sfx else { return nil }
        
        // Is this a bitwise-or operator?
        guard case let .binaryOperator(op, lhs, rhs) = self else { return nil }
        guard op == .bitwiseOr else { return nil }
        
        // Only the form of (X | Y) is allowed (whe X and Y are constant values).
        guard case let .constant(lhsValue) = lhs else { return nil }
        guard case let .constant(rhsValue) = rhs else { return nil }
        
        // Either the left of the right value shoud be SFXTYPE_POINTBASED (eg 256).
        // Extract the value for the other side.
        let pointBased = UnitScript.SfxType.pointBased.rawValue
        let type: CobDecompile.StackValue
        if lhsValue == pointBased { type = rhsValue }
        else if rhsValue == pointBased { type = lhsValue }
        else { return nil }
        
        // Try to init a valid SfxType with (256 | value).
        guard let sfx = UnitScript.SfxType(rawValue: type | pointBased) else { return nil }
        
        // We've made it! Return the string to use in place of "(256 | x)".
        return sfx.scriptIdentifier
    }
    
}

private extension String {
    func wrapped(_ condition: Bool) -> String {
        return condition ? "(\(self))" : self
    }
}

// MARK:- Hints

extension CobDecompile {
    
    struct ModuleParameterHint {
        
        var moduleName: String
        var parameters: [String]
        var locals: [String]
        
        init(moduleName: String, parameters: [String] = [], locals: [String] = []) {
            self.moduleName = moduleName
            self.parameters = parameters
            self.locals = locals
        }
        
    }
    
    static let ModuleParameterHints = [
        ModuleParameterHint(moduleName: "SetSpeed", parameters: ["the_speed"]),
        ModuleParameterHint(moduleName: "SetMaxReloadTime", parameters: ["time"]),
        ModuleParameterHint(moduleName: "SweetSpot", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "AimFromPrimary", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "QueryPrimary", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "AimPrimary", parameters: ["heading", "pitch"]),
        ModuleParameterHint(moduleName: "AimFromSecondary", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "QuerySecondary", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "AimSecondary", parameters: ["heading", "pitch"]),
        ModuleParameterHint(moduleName: "AimFromTertiary", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "QueryTertiary", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "AimTertiary", parameters: ["heading", "pitch"]),
        ModuleParameterHint(moduleName: "QueryNanoPiece", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "QueryBuildInfo", parameters: ["piecenum"]),
        ModuleParameterHint(moduleName: "QueryLandingPad", parameters: ["piece1", "piece2"]),
        ModuleParameterHint(moduleName: "Killed", parameters: ["severity", "corpsetype"]),
        ModuleParameterHint(moduleName: "HitByWeapon", parameters: ["anglex", "anglez"]),
        ModuleParameterHint(moduleName: "RockUnit", parameters: ["anglex", "anglez"]),
        ModuleParameterHint(moduleName: "RequestState", parameters: ["requestedstate"], locals: ["actualstate"]),
        ModuleParameterHint(moduleName: "SmokeUnit", locals: ["healthpercent", "sleeptime", "smoketype", "choice"]),
        ModuleParameterHint(moduleName: "HelpScale", parameters: ["scale"]),
        ]
    
    static func Hints(forModule named: String) -> ModuleParameterHint? {
        if let hint = ModuleParameterHints.first(where: { h in h.moduleName.caseInsensitiveCompare(named) == .orderedSame }) { return hint }
        else { return nil }
    }
    
}
