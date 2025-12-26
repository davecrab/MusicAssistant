import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingNowPlaying = false
    @State private var selectedTab: Tab = .library

    enum Tab: Hashable {
        case library
        case browse
        case players
        case search
        case settings
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.library)

                BrowseView()
                    .tabItem { Label("Browse", systemImage: "square.grid.2x2") }
                    .tag(Tab.browse)

                PlayersView()
                    .tabItem { Label("Players", systemImage: "hifispeaker.2") }
                    .tag(Tab.players)

                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(Tab.search)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(Tab.settings)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 70)
            }

            // Always visible Mini Player
            VStack(spacing: 0) {
                MiniPlayerView(
                    queue: appModel.activeQueue,
                    onTap: { showingNowPlaying = true }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 55)  // Standard tab bar height
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .fullScreenCover(isPresented: $showingNowPlaying) {
            NowPlayingView()
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().standardAppearance = appearance
        }
    }
}
