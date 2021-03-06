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
public class GameManager: ScriptMachine {
    
    public let loadedState: GameState
    public unowned var renderer: GameRenderer
    
    private var thread: Thread? = nil
    private var isRunningUpdateThread = false
    private let updateRate: GameFloat = 1.0 / 30.0
    
    private let objectSyncQueue = DispatchQueue(label: "GameObjectUpdates")
    private var objectIdGenerator = GameObjectIdGenerator()
    private var objects: [GameObjectId: GameObject] = [:]
    
    private var userState = UserState()
    
    private let inputSyncQueue = DispatchQueue(label: "GameInput")
    private var inputQueue = [GameInput]()
    
    public init(state: GameState, renderer: GameRenderer) {
        loadedState = state
        self.renderer = renderer
        
        // TEMP
        if let unit = randomStartingUnit() {
            let id = objectIdGenerator.generate()
            let startPosition = Point2f(state.startPosition)
            let height = state.map.heightMap.height(atWorldPosition: startPosition)
            let instance = UnitInstance(unit, position: Vertex3f(xy: startPosition, z: height))
            instance.scriptContext.startScript("Create")
            objects[id] = .unit(instance)
        }
        
        objectSyncQueue.asyncAfter(deadline: .now() + 2, execute: self.TEMP_spawn)
    }
    
    public func start() {
        isRunningUpdateThread = true
        let thread = Thread(block: {
            [weak self] in
            let updateRate = Double(self?.updateRate ?? 0)
            while let self = self, self.isRunningUpdateThread {
                let start = getCurrentTime()
                self.objectSyncQueue.sync {
                    self.update()
                }
                Thread.sleep(forTimeInterval: start + updateRate - getCurrentTime())
            }
        })
        thread.name = "Update Thread"
        thread.start()
        self.thread = thread
    }
    
    public func stop() {
        isRunningUpdateThread = false
        thread = nil
    }
    
    public func enqueueInput(_ input: GameInput) {
        inputSyncQueue.sync {
            inputQueue.append(input)
        }
    }
    
    private func update() {
        let viewState = renderer.viewState
        
        let queue = inputSyncQueue.sync { () -> [GameInput] in
            let current = inputQueue
            inputQueue = []
            return current
        }
        processInput(queue, viewState)
        
        for (id, object) in objects {
            switch object {
            case let .unit(instance): updateUnit(instance, id)
            case .feature: () // No update needed
            }
        }
        constructView()
    }
    
    private func processInput(_ inputQueue: [GameInput], _ viewState: GameViewState) {
        for i in inputQueue {
            switch i {
            case let .click(input):
                if input.button == 0 && input.state == .up {
                    if let found = firstUnit(underCursorAt: input.cursorLocation, in: viewState) {
                        userState.selection = [found.id]
                        userState.inputMode = .move
                    }
                    else if !userState.selection.isEmpty {
                        let unitId = userState.selection.first!
                        TEMP_startMoving(unitId, to: input.cursorLocation, in: viewState)
                    }
                }
                else if input.button == 1 && input.state == .up {
                    userState.selection = []
                    userState.inputMode = .select
                }
            case .key:
                break
            }
        }
    }
    
    private func firstUnit(underCursorAt location: Point2f, in viewState: GameViewState) -> (id: GameObjectId, instance: UnitInstance)? {
        for (id, object) in objects {
            switch object {
            case let .unit(instance):
                if TEMP_unit(instance, isUnderCursorAt: location, in: viewState) {
                    return (id, instance)
                }
            default:
                ()
            }
        }
        return nil
    }
    
    private func updateUnit(_ unit: UnitInstance, _ id: GameObjectId) {
        //guard let type = loadedState.units[unit.type] else { continue }
        
        var updated = unit
        updated.scriptContext.run(for: updated.modelInstance, on: self)
        updated.scriptContext.applyAnimations(to: &updated.modelInstance, for: updateRate)
        updated.applyMovement(loadedState.map)
        objects[id] = .unit(updated)
    }
    
    private func constructView() {
        let userState = self.userState
        var viewState = renderer.viewState
        
        let cursorPos = viewState.cursorLocation
        var cursor: Cursor
        
        switch userState.inputMode {
        case .select:
            cursor = .normal
        case .move:
            cursor = .move
        }
        
        var viewables: [GameViewObject] = []
        for (id, object) in objects {
            switch object {
            case let .unit(instance):
                viewables.append(.unit(GameViewUnit(instance, isSelected: userState.selection.contains(id))))
                if TEMP_unit(instance, isUnderCursorAt: cursorPos, in: viewState) {
                    cursor = .select
                }
            default:
                ()
            }
        }
        viewState.objects = viewables
        viewState.cursorType = cursor
        
        renderer.viewState = viewState
    }
    
    // TEMP
    
    public func getTime() -> Double {
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
    
    private func TEMP_spawn() {
        guard let unitType = randomStartingUnit() else { return }
        
        let id = objectIdGenerator.generate()
        let startPosition = Point2f( GameFloat.random(in: 0...300), GameFloat.random(in: 0...GameFloat(loadedState.map.resolution.height)) )
        let height = loadedState.map.heightMap.height(atWorldPosition: startPosition)
        print("Spawning \(unitType.info.name) at \(startPosition), height: \(height)")
        let instance = UnitInstance(unitType, position: Vertex3f(xy: startPosition, z: height))
        instance.scriptContext.startScript("Create")
        objects[id] = .unit(instance)
        objectSyncQueue.asyncAfter(deadline: .now() + 1) { self.TEMP_startMoving(id) }
        
        objectSyncQueue.asyncAfter(deadline: .now() + 3, execute: self.TEMP_spawn)
    }
    
    private func TEMP_startMoving(_ id: GameObjectId) {
        guard let obj = objects[id], case var .unit(unit) = obj else { return }
        
        let w = 1000 as GameFloat//GameFloat(loadedState.map.resolution.width)
        let y = unit.worldPosition.y
        let endPosition = Point2f( GameFloat.random(in: (w - 200)..<w), y)
        unit.TEMP_waypoint = endPosition
        
        unit.scriptContext.startScript("StartMoving")
        objects[id] = .unit(unit)
    }
    
    private func TEMP_unit(_ unit: UnitInstance, isUnderCursorAt location: Point2f, in viewState: GameViewState) -> Bool {
        let bb = viewState.worldToScreen(unit)
        return bb.enclosingRect.contains(location) && bb.contains(location)
    }
    
    private func TEMP_startMoving(_ id: GameObjectId, to cursorLocation: Point2f, in viewState: GameViewState) {
        guard let obj = objects[id], case var .unit(unit) = obj else { return }
        
        let cursorInViewport = viewState.screenToViewport(cursorLocation)
        let worldPosition = loadedState.map.heightMap.worldPosition(forViewPosition: cursorInViewport)
        unit.TEMP_waypoint = worldPosition.xy
        
        unit.scriptContext.startScript("StartMoving")
        objects[id] = .unit(unit)
    }
    
}

public extension GameState {
    
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

public extension GameViewState {
    
    func worldPositionToScreen(_ worldPosition: Point3f) -> Point2f {
        let inViewport = (worldPosition.xy - Vector2f(0, worldPosition.z / 2.0)) - viewport.origin
        let scaled = inViewport * (screenSize / viewport.size)
        return scaled
    }
    
    func worldToScreen(_ unit: UnitInstance) -> BoundingBox2Df {
        let inViewport = (unit.worldPosition.xy - Vector2f(0, unit.worldPosition.z / 2.0)) - viewport.origin
        let scale = screenSize / viewport.size
        let scaledPosition = inViewport * scale
        let scaledSize = Size2f(unit.type.info.footprint * 16) * scale
        let direction = Vector2f(unit.modelInstance.orientation.z.cosine, unit.modelInstance.orientation.z.sine)
        return BoundingBox2Df(center: scaledPosition, size: scaledSize, orientation: direction)
    }
    
    func worldToScreen(_ unit: GameViewUnit) -> BoundingBox2Df {
        let inViewport = (unit.position.xy - Vector2f(0, unit.position.z / 2.0)) - viewport.origin
        let scale = screenSize / viewport.size
        let scaledPosition = inViewport * scale
        let scaledSize = Size2f(unit.type.info.footprint * 16) * scale
        let direction = Vector2f(unit.orientation.z.cosine, unit.orientation.z.sine)
        return BoundingBox2Df(center: scaledPosition, size: scaledSize, orientation: direction)
    }
    
    func screenToViewport(_ screenPosition: Point2f) -> Point2f {
        let scale = viewport.size / screenSize
        return (screenPosition * scale) + viewport.origin
    }
    
}

// MARK:- Objects

public struct GameObjectId: ExpressibleByIntegerLiteral, Equatable, Hashable, CustomStringConvertible {
    private let value: Int
    public init(integerLiteral value: Int) {
        self.value = value
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
    public var description: String { return "Object(\(value))" }
}

public struct GameObjectIdGenerator {
    private let lock = DispatchSemaphore(value: 1)
    private var value = 0
    mutating func generate() -> GameObjectId {
        
        lock.wait()
        defer { lock.signal() }
        value += 1
        return GameObjectId(integerLiteral: value)
    }
}

public enum GameObject {
    case feature(FeatureInstance)
    case unit(UnitInstance)
}

public struct FeatureInstance {
    let type: FeatureTypeId
    var worldPosition: Vertex3f
}

public struct UnitInstance {
    
    let type: UnitData
    var worldPosition: Vertex3f
    var orientation: Vector3f
    
    var movementVelocity: Vector2f
    var movementDirection: Vector2f
    
    var modelInstance: UnitModel.Instance
    var scriptContext: UnitScript.Context
    
    var TEMP_waypoint: Vertex2f? = nil
    
    enum Status {
        case baking(Health)
        case alive(Health)
        case dead
    }
    var status: Status
    
}

public extension UnitInstance {
    
    init(_ unitType: UnitData, position: Vertex3f = .zero, orientation: Vector3f = .zero) {
        type = unitType
        worldPosition = position
        self.orientation = orientation
        movementVelocity = .zero
        movementDirection = Vector2f(polar: orientation.z - GameFloat.pi / 2.0, length: 1)
        modelInstance = UnitModel.Instance(for: unitType.model)
        scriptContext = try! UnitScript.Context(unitType.script, unitType.model)
        status = .alive(Health(value: 100, total: 100))
    }
    
    mutating func applyMovement(_ map: MapModel) {
        
        guard let waypoint = TEMP_waypoint else { return }
        
        let steering = computeSteering(to: waypoint)
        (movementVelocity, movementDirection) = computeVelocity(with: steering)
        
        orientation.z = movementDirection.angle + GameFloat.pi / 2.0
        worldPosition.xy += movementVelocity
        worldPosition.z = map.heightMap.height(atWorldPosition: worldPosition.xy)
        
        // TEMP - Stops movement when "near" the waypoint.
        if (waypoint - worldPosition.xy).lengthSquared < sqr(2) {
            TEMP_waypoint = nil
            movementVelocity = .zero
            scriptContext.startScript("StopMoving")
        }
    }
    
    // The code below was adapted from the nTA code base (the code there was collected from many sources); a primary root source was:
    // Steering Behaviors For Autonomous Characters by Craig W. Reynolds [https://www.red3d.com/cwr/steer/gdc99/]
    
    private func computeSteering(to target: Vertex2f) -> Vector2f {
        
        let position = worldPosition.xy
        let offset = target - position
        
        let distance = offset.length
        let slowingDistance = sqr(type.info.maxVelocity) / type.info.brakeRate
        
        let rampedSpeed = type.info.maxVelocity * distance / slowingDistance
        let clippedSpeed = min(rampedSpeed, type.info.maxVelocity)
        
        let desiredVelocity = offset * (clippedSpeed / distance)
        let steering = desiredVelocity - movementVelocity
        return steering
    }
    
    private func computeVelocity(with steering: Vector2f) -> (velocity: Vector2f, direction: Vector2f) {
        
        let steeringForce = steering.truncated(to: (movementDirection • steering) > 0 ? type.info.acceleration : type.info.brakeRate )
        let newVelocity = (movementVelocity + steeringForce).truncated(to: type.info.maxVelocity)
        let newDirection = newVelocity.normalized
        
        // If the can turn to face the new direction without exceeding its turn rate,
        // then immediately apply the new direction and velocity.
        if (movementDirection • newDirection) >= type.info.turnRate.cosine {
            return (newVelocity, newDirection)
        }
        // Otherwise, the unit needs to turn towards the new direction as much as it can.
        else {
            let turnIncrement = type.info.turnRate.negate(if: determinant(movementDirection, newDirection) < 0)
            let intermediateDirection = Vector2f(polar: movementDirection.angle + turnIncrement)
            return (intermediateDirection * newVelocity.length, intermediateDirection)
        }
    }
    
}

public struct Health {
    var value: Int
    var total: Int
    var percentage: Float { return (Float(value) / Float(total)).clamped(to: 0...1) }
}
