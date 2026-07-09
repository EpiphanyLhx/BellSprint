import SwiftUI

@main
struct ClassBellApp: App {
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
