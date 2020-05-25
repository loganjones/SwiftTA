//
//  AppDelegate.swift
//  SwiftTA iOS
//
//  Created by Logan Jones on 5/20/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import UIKit
import SwiftTA_Core

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        startLoading()
        return true
    }
    
    func startLoading() {
        DispatchQueue(label: "Loading").async {
            do {
                guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw RuntimeError("No Documents directory?!")
                }
                
                let state = try GameState(testLoadFromDocumentsDirectory: documents)
                
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
