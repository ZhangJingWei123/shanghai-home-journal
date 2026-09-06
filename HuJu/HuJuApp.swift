import SwiftUI

@main
struct HuJuApp: App {
    @StateObject private var store: PropertyStore
    @StateObject private var authentication = AuthenticationStore()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        _store = StateObject(
            wrappedValue: PropertyStore(
                loadsSampleData: arguments.contains("-loadSampleData")
                    || arguments.contains("-uiTestAuthenticated")
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .environmentObject(store)
                .environmentObject(authentication)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .tint(HuJuTheme.green)
        }
    }
}
