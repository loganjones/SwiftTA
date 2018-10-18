//
//  GameManager.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/8/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


/**
 I'm not a big fan of manager objects. Consider this a temporary means-to-an-end for getting the update thread up and working.
 */
class GameManager: ScriptMachine {
    
    let loadedState: GameState
    unowned var renderer: GameRenderer
    
    private var thread: Thread? = nil
    private var isRunningUpdateThread = false
    private let updateRate: GameFloat = 1.0 / 60.0
    
    private var objects: [GameObjectId: GameObject] = [:]
    
    init(state: GameState, renderer: GameRenderer) {
        loadedState = state
        self.renderer = renderer
        
        // TEMP
        if let unit = randomStartingUnit() {
            let id: GameObjectId = 1
            let startPosition = Point2f(state.startPosition)
            let instance = UnitInstance(unit, position: Vertex3f(xy: startPosition))
            instance.scriptContext.startScript("Create")
            objects[id] = .unit(instance)
        }
    }
    
    func start() {
        isRunningUpdateThread = true
        let thread = Thread(block: {
            [weak self] in
            let updateRate = Double(self?.updateRate ?? 0)
            while let self = self, self.isRunningUpdateThread {
                let start = getCurrentTime()
                self.update()
                Thread.sleep(forTimeInterval: start + updateRate - getCurrentTime())
            }
        })
        thread.name = "Update Thread"
        thread.start()
        self.thread = thread
    }
    
    func stop() {
        isRunningUpdateThread = false
        thread = nil
    }
    
    private func update() {
        for (id, object) in objects {
            switch object {
            case let .unit(instance): updateUnit(instance, id)
            case .feature: () // No update needed
            }
        }
        constructView()
    }
    
    private func updateUnit(_ unit: UnitInstance, _ id: GameObjectId) {
        //guard let type = loadedState.units[unit.type] else { continue }
        
        var updated = unit
        updated.scriptContext.run(for: updated.modelInstance, on: self)
        updated.scriptContext.applyAnimations(to: &updated.modelInstance, for: updateRate)
        objects[id] = .unit(updated)
    }
    
    private func constructView() {
        var viewables: [GameViewObject] = []
        for (_, object) in objects {
            switch object {
            case let .unit(instance):
                viewables.append(.unit(GameViewUnit(instance)))
            default:
                ()
            }
        }
        renderer.viewState.objects = viewables
    }
    
    // TEMP
    
    func getTime() -> Double {
        return getCurrentTime()
    }
    
    private func randomStartingUnit() -> UnitData? {
        if let taUnitName = ["armcom", "corcom"].randomElement(), let taUnit = loadedState.units[UnitTypeId(named: taUnitName)] {
            return taUnit
        }
        else if let takUnitName = ["araking", "tarnecro", "vermage", "zonhunt", "cresage"].randomElement(), let takUnit = loadedState.units[UnitTypeId(named: takUnitName)] {
            return takUnit
        }
        else {
            return nil
        }
    }
    
}

extension GameState {
    
    func generateInitialViewState(viewportSize: Size2<Int>) -> GameViewState {
        
//        // TEMP
//        var startingObjects: [GameViewObject] = []
//
//        if let unit = randomStartingUnit() {
//            startingObjects.append(.unit(GameViewUnit(name: unit.info.name.lowercased(),
//                                                      position: Vertex3(Double(startPosition.x), Double(startPosition.y), 0),
//                                                      orientation: .zero,
//                                                      pose: UnitModel.Instance(for: unit.model))))
//        }
        
        return GameViewState(viewport: Rect4f(viewport(ofSize: viewportSize, centeredOn: startPosition, in: map)),
                             objects: [])
    }
    
}

// MARK:- Objects

struct GameObjectId: ExpressibleByIntegerLiteral, Equatable, Hashable, CustomStringConvertible {
    private let value: Int
    init(integerLiteral value: Int) {
        self.value = value
    }
    var hashValue: Int { return value }
    var description: String { return "Object(\(value))" }
}

enum GameObject {
    case feature(FeatureInstance)
    case unit(UnitInstance)
}

struct FeatureInstance {
    let type: FeatureTypeId
    var worldPosition: Vertex3f
}

struct UnitInstance {
    
    let type: UnitTypeId
    var worldPosition: Vertex3f
    var orientation: Vector3f
    var modelInstance: UnitModel.Instance
    var scriptContext: UnitScript.Context
    
    enum Status {
        case baking(Health)
        case alive(Health)
        case dead
    }
    var status: Status
    
}

extension UnitInstance {
    init(_ unit: UnitData, position: Vertex3f = .zero, orientation: Vector3f = .zero) {
        type = UnitTypeId(for: unit.info)
        worldPosition = position
        self.orientation = orientation
        modelInstance = UnitModel.Instance(for: unit.model)
        scriptContext = try! UnitScript.Context(unit.script, unit.model)
        status = .alive(Health(value: 100, total: 100))
    }
}

struct Health {
    var value: Int
    var total: Int
    var percentage: Float { return (Float(value) / Float(total)).clamped(to: 0...1) }
}
