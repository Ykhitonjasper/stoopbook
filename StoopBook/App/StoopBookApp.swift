import SwiftUI

@main
@MainActor
struct StoopBookApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(dependencies.store)
        }
    }
}
