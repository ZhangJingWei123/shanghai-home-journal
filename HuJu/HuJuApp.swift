import SwiftUI

@main
struct HuJuApp: App {
    @StateObject private var store: PropertyStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        _store = StateObject(
            wrappedValue: PropertyStore(
                loadsSampleData: arguments.contains("-loadSampleData")
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .tint(HuJuTheme.green)
        }
    }
}
