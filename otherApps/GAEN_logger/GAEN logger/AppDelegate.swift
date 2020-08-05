//
//  AppDelegate.swift
//  GAEN logger
//
//  Created by Bill on 6/1/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView().environmentObject(LocalState.shared)

        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.center()
        window.title = "GAEN Logger"
        window.setFrameAutosaveName("Main Window")
        Scanner.shared.hello()
        window.contentView = NSHostingView(rootView: contentView)

        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_: Notification) {
        // Insert code here to tear down your application
    }
}
