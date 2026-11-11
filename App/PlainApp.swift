import SwiftUI

@main
struct PlainApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        Window("Plain", id: "main") {
            ContentView()
                .frame(width: 420, height: 460)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    // There is nothing to do in the background: closing the window quits.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
#endif
