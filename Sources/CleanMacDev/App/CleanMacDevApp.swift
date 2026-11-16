// SomAt Dev - Clean Mac Dev
// A small macOS app that shows developer cache sizes and cleans what you pick.
// MIT License. See LICENSE.

import SwiftUI

@main
struct CleanMacDevApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("SomAt Dev - Clean Mac Dev") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 620)
        }
        .defaultSize(width: 880, height: 920)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Rescan") { model.scan() }
                    .keyboardShortcut("r")
            }
        }
    }
}

/// Quits the app when its window is closed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
