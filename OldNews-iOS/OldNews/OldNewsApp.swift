import SwiftUI

@main
struct OldNewsApp: App {
    @StateObject private var model = OldNewsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(OldNewsTheme.accent)
        }
    }
}
