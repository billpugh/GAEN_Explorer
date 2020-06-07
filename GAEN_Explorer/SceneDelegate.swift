//
//  SceneDelegate.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import Combine
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    @State var showingSheet = false

    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            // Handle URL
            guard url.pathExtension == "diagk" else { return }
            _ = LocalStore.shared.importData(from: url) {
                _ in
            }

            // WXApi.handleOpen(url, delegate: AppDelegate.shared)
        }
    }

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView().environmentObject(LocalStore.shared).environmentObject(ExposureFramework.shared)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_: UIScene) {
        print("scene did disconnect")
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_: UIScene) {
        print("scene did become active")
        ExposureFramework.shared.objectWillChange.send()
        if let shortcutItem = shortcutItemToProcess {
            print("Process \(shortcutItem)")
            shortcutItemToProcess = nil
        }
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_: UIScene) {
        print("scene did resign active")
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_: UIScene) {
        print("scene did enter foreground")
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_: UIScene) {
        print("scene did enter background")
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func windowScene(_: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler _: @escaping (Bool) -> Void) {
        shortcutItemToProcess = shortcutItem
        print("Got shortcut \(shortcutItem)")
        // Handle actions based on shortcutItem.type
    }
}
