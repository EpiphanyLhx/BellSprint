import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct ClassBellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView().environmentObject(appState)
        } label: {
            Image(systemName: appState.isEnabled ? "bell.fill" : "bell.slash.fill")
        }
        .menuBarExtraStyle(.window)
        
        Window("铃声设置", id: "settings") {
            ContentView().environmentObject(appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 620, height: 680)
    }
}
