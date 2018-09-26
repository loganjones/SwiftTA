//
//  main.swift
//  SwiftTA
//
//  Created by Logan Jones on 9/21/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation
import Cglfw


class GameBox {
    var renderer: GameRenderer
    
    init(_ renderer: GameRenderer) {
        self.renderer = renderer
    }
}

struct FrameRate {
    var tRot0 = -1.0
    var tRate0 = -1.0
    var frames = 0
    
    init() { }
    
    mutating func sample(_ t: Double) -> Double {
        
        if tRot0 < 0.0 {
            tRot0 = t
        }
        
        let dt = t - tRot0
        tRot0 = t
        
        frames += 1
        
        if tRate0 < 0.0 {
            tRate0 = t
        }
        if t - tRate0 >= 5 {
            let seconds = t - tRate0
            let fps = GLfloat(frames) / GLfloat(seconds)
            print("\(frames) frames in \(seconds) seconds = \(fps) FPS")
            tRate0 = t
            frames = 0
        }
        
        return dt
    }
    
}


/* return current time (in seconds) */
func current_time() -> Double
{
    var tv = timeval()
    var tz = timezone()
    gettimeofday(&tv, &tz)
    return Double(tv.tv_sec) + (Double(tv.tv_usec) / 1000000.0)
}

func glfwSetGameContext(_ game: GameBox, for window: OpaquePointer?) {
    glfwSetWindowUserPointer(window, Unmanaged.passUnretained(game).toOpaque())
}

func glfwGetGameContext(for window: OpaquePointer?) -> GameBox {
    guard let p = glfwGetWindowUserPointer(window) else {
        fatalError("No game context set for window!?")
    }
    return Unmanaged.fromOpaque(p).takeUnretainedValue()
}


/* new window size or exposure */
func reshape(window: OpaquePointer?, to viewportSize: Size2D)
{
    let game = glfwGetGameContext(for: window)
    
    game.renderer.viewState.viewport.size = CGSize(viewportSize)
    
    glViewport(0, 0, GLsizei(viewportSize.width), GLsizei(viewportSize.height))
}

func keyboardKey(event: (key: Int32, scancode: Int32, action: Int32, mods: Int32), in window: OpaquePointer?) {
    let game = glfwGetGameContext(for: window)
    
    switch (event.action, event.key) {
        
    case (GLFW_PRESS,  GLFW_KEY_LEFT): fallthrough
    case (GLFW_REPEAT, GLFW_KEY_LEFT):
        game.renderer.viewState.viewport.origin.x -= 8.0
        
    case (GLFW_PRESS,  GLFW_KEY_RIGHT): fallthrough
    case (GLFW_REPEAT, GLFW_KEY_RIGHT):
        game.renderer.viewState.viewport.origin.x += 8.0
        
    case (GLFW_PRESS,  GLFW_KEY_UP): fallthrough
    case (GLFW_REPEAT, GLFW_KEY_UP):
        game.renderer.viewState.viewport.origin.y -= 8.0
        
    case (GLFW_PRESS,  GLFW_KEY_DOWN): fallthrough
    case (GLFW_REPEAT, GLFW_KEY_DOWN):
        game.renderer.viewState.viewport.origin.y += 8.0
        
    case (GLFW_PRESS, GLFW_KEY_ESCAPE):
        glfwSetWindowShouldClose(window, GL_TRUE)
        
    default:
        ()
    }
}


func main() {
    
    glfwSetErrorCallback() { (error, description) in
        fputs(description, stderr)
    }
    
    if glfwInit() == 0 {
        exit(EXIT_FAILURE)
    }
    
    glfwWindowHint(GLFW_SAMPLES, 4)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE)
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
    
    let initialWindowSize = Size2D(1024, 768)
    guard let window = glfwCreateWindow(
        Int32(initialWindowSize.width),
        Int32(initialWindowSize.height),
        "SwiftTA", nil, nil)
        else {
            glfwTerminate()
            exit(EXIT_FAILURE)
    }
    
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)
    
    let game: GameBox
    do {
        let fm = FileManager.default
        
        let taDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Total Annihilation", isDirectory: true)
//            .appendingPathComponent("Total Annihilation Kingdoms", isDirectory: true)
        print("Total Annihilation directory: \(taDir)")
        
        let gameState = try GameState(loadFrom: taDir, mapName: "Coast to Coast")
//                let gameState = try GameState(loadFrom: taDir, mapName: "Dark Side")
//                let gameState = try GameState(loadFrom: taDir, mapName: "Great Divide")
//                let gameState = try GameState(loadFrom: taDir, mapName: "King of the Hill")
//                let gameState = try GameState(loadFrom: taDir, mapName: "Ring Atoll")
//                let gameState = try GameState(loadFrom: taDir, mapName: "Two Continents")
        
//                let gameState = try GameState(loadFrom: taDir, mapName: "Athri Cay")
//                let gameState = try GameState(loadFrom: taDir, mapName: "Black Heart Jungle")
//                let gameState = try GameState(loadFrom: taDir, mapName: "The Old Riverbed")
//                let gameState = try GameState(loadFrom: taDir, mapName: "Two Castles")

        let initialViewState = GameViewState(viewport: viewport(ofSize: initialWindowSize, centeredOn: gameState.startPosition, in: gameState.map))
        
        guard let renderer = OpenglCore3Renderer(loadedState: gameState, viewState: initialViewState)
            else {
                throw RuntimeError("Failed to initialize renderer.")
        }
        
        game = GameBox(renderer)
    }
    catch {
        print("Failed to load GameState: \(error)")
        glfwTerminate()
        exit(EXIT_FAILURE)
    }
    
    glfwSetGameContext(game, for: window)
    
    glfwSetKeyCallback(window) {
        (win, key, scancode, action, mods) in
        keyboardKey(event: (key, scancode, action, mods), in: win)
    }
    glfwSetWindowSizeCallback(window) {
        (win, width, height) in
        reshape(window: win, to: Size2D(Int(width), Int(height)))
    }
    
    reshape(window: window, to: initialWindowSize)
    var frameRate = FrameRate()
    
    while glfwWindowShouldClose(window) == 0 {
        
        let dt = frameRate.sample(current_time())
        
        game.renderer.drawFrame()
        
        glfwSwapBuffers(window)
        glfwPollEvents()
    }
    
    glfwDestroyWindow(window)
    glfwTerminate()
    exit(EXIT_SUCCESS)
}


main()
