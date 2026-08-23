import SwiftUI

@main
struct HuJuApp: App {
    @StateObject private var store = PropertyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(HuJuTheme.green)
        }
    }
}
