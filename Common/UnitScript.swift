//
//  UnitScript.swift
//  TAassets
//
//  Created by Logan Jones on 4/30/17.
//  Copyright © 2017 Logan Jones. All rights reserved.
//

import Foundation

struct UnitScript {
    
    typealias CodeUnit = Int32
    typealias Code = Array<CodeUnit>
    
    var modules: [Module]
    var code: Code
    var numberOfStaticVariables: Int
    var pieces: [String]
    
    init<File>(contentsOf file: File) throws
        where File: FileReadHandle
    {
        let fileData = file.readDataToEndOfFile()
        let script = fileData.withUnsafeBytes { UnitScript.loadScript(from: $0) }
        
        code = script.code
        modules = zip(script.moduleNames, script.moduleOffsets).map(Module.init)
        numberOfStaticVariables = script.staticCount
        pieces = script.pieceNames
        
        for moduleIndex in modules.indices {
            var codeIndex = Int(modules[moduleIndex].offset)
            var count = 0
            while (code[codeIndex] == Opcode.stackAllocate.rawValue) { count += 1; codeIndex += 1 }
            modules[moduleIndex].localCount = count
        }
    }
    
    struct Module {
        var name: String
        var offset: Code.Index
        var localCount: Int = 0
        
        init(name: String, offset: Code.Index) {
            self.name = name
            self.offset = offset
        }
    }
    
}

extension UnitScript {
    
    func module(named name: String) -> Module? {
        guard let index = modules.index(where: { $0.name == name })
            else { return nil }
        return modules[index]
    }
    
}

private extension UnitScript {
    
    struct ScriptData {
        var code: Code
        var moduleOffsets: [Code.Index]
        var moduleNames: [String]
        var moduleLocals: [Int]
        var pieceNames: [String]
        var staticCount: Int
    }
    
    static func loadScript(from memory: UnsafePointer<UInt8>) -> ScriptData {
        
        let header = UnsafeRawPointer(memory).bindMemory(to: TA_COB_HEADER.self, capacity: 1).pointee
        
        let code = UnsafeRawPointer(memory + Int(header.offsetToFirstModule))
            .bindMemoryBuffer(to: CodeUnit.self, capacity: Int(header.lengthOfAllModules))
        
        let moduleOffsets = UnsafeRawPointer(memory + Int(header.offsetToModulePointerArray))
            .bindMemoryBuffer(to: UInt32.self, capacity: Int(header.numberOfModules))
        
        let moduleNames = UnitScript.collectStrings(at: Int(header.offsetToModuleNameOffsetArray), in: memory, count: Int(header.numberOfModules))
        let pieceNames = UnitScript.collectStrings(at: Int(header.offsetToPieceNameOffsetArray), in: memory, count: Int(header.numberOfPieces))
        
        let locals = determineLocalCounts(of: moduleOffsets, in: code)
        
        return ScriptData(code: Array(code) ,
                          moduleOffsets: moduleOffsets.map(Int.init) ,
                          moduleNames: moduleNames,
                          moduleLocals: locals,
                          pieceNames: pieceNames,
                          staticCount: Int(header.numberOfStaticVars))
    }
    
    static func collectStrings(at offset: Int, in memory: UnsafePointer<UInt8>, count: Int = 1) -> [String] {
        
        var strings: [String] = []
        strings.reserveCapacity(count)
        
        let offsets = UnsafeRawPointer(memory + offset)
            .bindMemoryBuffer(to: UInt32.self, capacity: count)
        
        for offset in offsets {
            let string = String(cString: memory + offset)
            strings.append(string)
        }
        
        return strings
    }
    
    static func determineLocalCounts<M,C>(of modules: M, in code: C) -> [Int]
        where M: Sequence, M.Iterator.Element == UInt32, C: Collection, C.Iterator.Element == CodeUnit, C.Index == Int {
            return modules.map {
                var i = Int($0)
                var count = 0
                while (code[i] == Opcode.stackAllocate.rawValue) { count += 1; i += 1 }
                return count
            }
    }
    
}

extension UnitScript {
    
    enum Opcode: CodeUnit {
        case movePieceWithSpeed     = 0x10001000
        case turnPieceWithSpeed     = 0x10002000
        case startSpin              = 0x10003000
        case stopSpin               = 0x10004000
        case showPiece              = 0x10005000
        case hidePiece              = 0x10006000
        case cachePiece             = 0x10007000
        case dontCachePiece         = 0x10008000
        case dontShadow             = 0x1000A000
        case movePieceNow           = 0x1000B000
        case turnPieceNow           = 0x1000C000
        case dontShade              = 0x1000E000
        case emitSfx                = 0x1000F000
        case waitForTurn            = 0x10011000
        case waitForMove            = 0x10012000
        case sleep                  = 0x10013000
        case pushConstant           = 0x10021001
        case pushLocalVariable      = 0x10021002
        case pushStaticVariable     = 0x10021004
        case stackAllocate          = 0x10022000
        case setLocalVariable       = 0x10023002
        case setStaticVariable      = 0x10023004
        case popStack               = 0x10024000
        case add                    = 0x10031000
        case subtract               = 0x10032000
        case multiply               = 0x10033000
        case divide                 = 0x10034000
        case bitwiseAnd             = 0x10035000
        case bitwiseOr              = 0x10036000
        case unknown1               = 0x10039000
        case unknown2               = 0x1003A000
        case unknown3               = 0x1003B000
        case random                 = 0x10041000
        case getUnitValue           = 0x10042000
        case getFunctionResult      = 0x10043000
        case lessThan               = 0x10051000
        case lessThanOrEqual        = 0x10052000
        case greaterThan            = 0x10053000
        case greaterThanOrEqual     = 0x10054000
        case equal                  = 0x10055000
        case notEqual               = 0x10056000
        case and                    = 0x10057000
        case or                     = 0x10058000
        case not                    = 0x1005A000
        case startScript            = 0x10061000
        case callScript             = 0x10062000
        case jumpToOffset           = 0x10064000
        case `return`               = 0x10065000
        case jumpToOffsetIfFalse    = 0x10066000
        case signal                 = 0x10067000
        case setSignalMask          = 0x10068000
        case explode                = 0x10071000
        case playSound              = 0x10072000
        case mapCommand             = 0x10073000
        case setUnitValue           = 0x10082000
        case attachUnit             = 0x10083000
        case dropUnit               = 0x10084000
    }
    
    enum Axis: CodeUnit {
        case x      = 0
        case y      = 1
        case z      = 2
    }
    
    enum UnitValue: CodeUnit {
        
        /// #define ACTIVATION			1	// set or get
        case activation         = 1
        
        /// #define STANDINGMOVEORDERS	2	// set or get
        case standingMoveOrders = 2
        
        /// #define STANDINGFIREORDERS	3	// set or get
        case standingFireOrders = 3
        
        /// #define HEALTH				4	// get (0-100%)
        case health             = 4
        
        /// #define INBUILDSTANCE		5	// set or get
        case inBuildStance      = 5
        
        /// #define BUSY				6	// set or get (used by misc. special case missions like transport ships)
        case busy               = 6
        
        /// #define PIECE_XZ			7	// get
        case pieceXZ            = 7
        
        /// #define PIECE_Y				8	// get
        case pieceY             = 8
        
        /// #define UNIT_XZ				9	// get
        case unitXZ             = 9
        
        /// #define	UNIT_Y				10	// get
        case unitY              = 10
        
        /// #define UNIT_HEIGHT			11	// get
        case unitHeight         = 11
        
        /// #define XZ_ATAN				12	// get atan of packed x,z coords
        case xzAtan             = 12
        
        /// #define XZ_HYPOT			13	// get hypot of packed x,z coords
        case xzHypot            = 13
        
        /// #define ATAN				14	// get ordinary two-parameter atan
        case atan               = 14
        
        /// #define HYPOT				15	// get ordinary two-parameter hypot
        case hypot              = 15
        
        /// #define GROUND_HEIGHT		16	// get
        case groundHeight       = 16
        
        /// #define BUILD_PERCENT_LEFT	17	// get 0 = unit is built and ready, 1-100 = How much is left to build
        case buildPercentLeft   = 17
        
        /// #define YARD_OPEN			18	// set or get (change which plots we occupy when building opens and closes)
        case yardOpen           = 18
        
        /// #define BUGGER_OFF			19	// set or get (ask other units to clear the area)
        case buggerOff          = 19
        
        /// #define ARMORED				20	// set or get
        case armored            = 20
        
        // New in TA:K
        /// #define WEAPON_AIM_ABORTED	21
        /// #define WEAPON_READY		22
        /// #define WEAPON_LAUNCH_NOW	23
        /// #define FINISHED_DYING		26
        /// #define ORIENTATION			27
        /// #define IN_WATER			28
        /// #define CURRENT_SPEED		29
        /// #define MAGIC_DEATH			31
        /// #define VETERAN_LEVEL		32
        /// #define ON_ROAD				34
    }

    enum Animation {
        case setPosition(SetPosition)
        case translation(TranslationAnimation)
        case setAngle(SetAngle)
        case rotation(RotationAnimation)
        case spinUp(SpinAnimation)
        case spin(SpinAnimation)
        case spinDown(SpinAnimation)
        case show(Int)
        case hide(Int)
    }
    
    struct SetPosition {
        var piece: UnitModel.Pieces.Index
        var axis: Axis
        var target: Double
    }
    
    struct TranslationAnimation {
        var piece: UnitModel.Pieces.Index
        var axis: Axis
        var target: Double
        var velocity: Double
    }
    
    struct SetAngle {
        var piece: UnitModel.Pieces.Index
        var axis: Axis
        var target: Double
    }
    
    struct RotationAnimation {
        var piece: UnitModel.Pieces.Index
        var axis: Axis
        var target: Double
        var speed: Double
        var targetPolar: Vector2
    }
    
    struct SpinAnimation {
        var piece: UnitModel.Pieces.Index
        var axis: Axis
        var acceleration: Double
        var speed: Double
        var targetSpeed: Double
    }
    
}

extension UnitScript.UnitValue {
    var parameterCount: Int {
        switch self {
        case .unitXZ: fallthrough
        case .groundHeight: fallthrough
        case .unitHeight:
            return 1
        default:
            return 0
        }
    }
}
