//
//  AppDelegate.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func applicationDidBecomeActive(_: UIApplication) {
        print("did become active")
    }

    func applicationWillResignActive(_: UIApplication) {
        print("applicationWillResignActive")
    }

    func applicationWillEnterForeground(_: UIApplication) {
        print("applicationWillEnterForeground")
    }

    func applicationDidFinishLaunching(_: UIApplication) {
        print("did FinishLaunching")
    }

    func applicationDidEnterBackground(_: UIApplication) {
        print("did enter background")
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        print("Called didFinishLaunchingWithOptions")
        if let shortCut = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] {
            print("Using shortcut \(shortCut) of type \(type(of: shortCut))")
        }

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("Called foo 1")
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
        print("Called foo 2")
    }
}
