//
//  AppDelegate.swift
//  SwiftTA iOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        startLoading()
        return true
    }
    
    func startLoading() {
        DispatchQueue(label: "Loading").async {
            do {
                guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw RuntimeError("No Documents directory?!")
                }
                let taDir = try URL(resolvingAliasFileAt: documents.appendingPathComponent("Total Annihilation", isDirectory: true))
                
                let state = try GameState.loadStuff(from: taDir, mapName: "Coast to Coast")
                DispatchQueue.main.async {
                    self.proceedWithLoaded(state)
                }
            }
            catch {
                print("Loading phase failed with error: \(error)")
            }
        }
    }
    
    func proceedWithLoaded(_ state: GameState) {
        let vc = GameViewController(state)
        window?.rootViewController = vc
    }

}
