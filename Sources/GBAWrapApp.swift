import SwiftUI

@main
struct GBAWrapApp: App {
    @StateObject private var emulator = Emulator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(emulator)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
