import SwiftUI
import UIKit

@MainActor
struct RootView: View {
    private let dependencies: AppDependencies
    @Bindable private var store: StoopBookStore

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        Chrome.apply()
    }

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                tabShell
            } else {
                OnboardingScreen(dependencies: dependencies)
            }
        }
        .environment(store)
        .tint(AppTheme.accent)
    }

    private var tabShell: some View {
        TabView(selection: $store.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    screen(for: tab)
                }
                .tabItem {
                    Label(tab.label, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .background(AppTheme.paper)
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab.id {
        case AppTab.readings.id:
            ReadingsScreen(dependencies: dependencies)
        case AppTab.maps.id:
            PlacesScreen(dependencies: dependencies)
        case AppTab.settings.id:
            SettingsScreen(dependencies: dependencies)
        default:
            KitsHubScreen(dependencies: dependencies)
        }
    }
}

/// The system chrome is part of the same world as the page: paper surfaces, a
/// self-coloured edge instead of a hard divider, and ink for the current tab.
enum Chrome {
    static func apply() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(AppTheme.paper)
        tabBar.shadowColor = UIColor(AppTheme.edge)

        for layout in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            layout.normal.iconColor = UIColor(AppTheme.inkSoft)
            layout.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.inkSoft)]
            layout.selected.iconColor = UIColor(AppTheme.ink)
            layout.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.ink)]
        }

        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let navBar = UINavigationBarAppearance()
        navBar.configureWithOpaqueBackground()
        navBar.backgroundColor = UIColor(AppTheme.paper)
        navBar.shadowColor = UIColor(AppTheme.edge)
        navBar.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.ink)]

        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar
        UINavigationBar.appearance().compactAppearance = navBar
    }
}

#Preview("Onboarding") {
    RootView(dependencies: .preview())
}

#Preview("Tabs") {
    let dependencies = AppDependencies.preview()
    dependencies.store.completeOnboarding()
    return RootView(dependencies: dependencies)
}
