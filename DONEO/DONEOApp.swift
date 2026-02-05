import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Image(systemName: "folder.fill")
                Text("Projects")
            }
            .tag(0)

            NavigationStack {
                ActivityView()
            }
            .tabItem {
                Image(systemName: "bell.fill")
                Text("Activity")
            }
            .tag(1)

            NavigationStack {
                CallsPlaceholderView()
            }
            .tabItem {
                Image(systemName: "phone.fill")
                Text("Calls")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .tag(3)
        }
    }
}

// MARK: - Calls Placeholder

struct CallsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "phone.fill",
            description: Text("Voice and video calls will be available in a future update")
        )
        .navigationTitle("Calls")
    }
}

// MARK: - App

@main
struct DONEOApp: App {
    @State private var showOnboarding = false
    @State private var hasCheckedAuth = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCheckedAuth {
                    // Loading state
                    ProgressView()
                        .onAppear {
                            checkAuth()
                        }
                } else if showOnboarding {
                    OnboardingContainerView { projectName, projectDescription in
                        if let name = projectName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            let currentUser = MockDataService.shared.currentUser
                            let newProject = Project(
                                name: name,
                                description: projectDescription,
                                members: [currentUser],
                                lastActivity: Date(),
                                lastActivityPreview: "Project created"
                            )
                            MockDataService.shared.projects.insert(newProject, at: 0)
                        }
                        showOnboarding = false
                    }
                } else {
                    MainTabView()
                }
            }
        }
    }

    private func checkAuth() {
        // For demo purposes, show onboarding only on first launch
        // In production, check AuthManager.shared.isAuthenticated
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        if !hasLaunched {
            showOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        } else {
            showOnboarding = false
        }

        hasCheckedAuth = true
    }
}
