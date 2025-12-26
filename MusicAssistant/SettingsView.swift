import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var providerCount: Int = 0
    @State private var playerCount: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                // Configuration Section
                Section("Configuration") {
                    NavigationLink {
                        ProvidersConfigView()
                            .environmentObject(appModel)
                    } label: {
                        Label {
                            HStack {
                                Text("Providers")
                                Spacer()
                                if providerCount > 0 {
                                    Text("\(providerCount)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "puzzlepiece.extension")
                                .foregroundStyle(.blue)
                        }
                    }

                    NavigationLink {
                        PlayersConfigView()
                            .environmentObject(appModel)
                    } label: {
                        Label {
                            HStack {
                                Text("Players")
                                Spacer()
                                if playerCount > 0 {
                                    Text("\(playerCount)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "speaker.wave.2")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Server Section
                Section("Server") {
                    TextField(
                        "Server URL",
                        text: Binding(
                            get: { appModel.settings.serverURLString },
                            set: { appModel.settings.serverURLString = $0 }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                    if let serverURL = appModel.settings.serverURL {
                        LabeledContent("Connected To", value: serverURL.host ?? "Unknown")
                    }
                }

                // Session Section
                Section("Session") {
                    if appModel.isSignedIn {
                        HStack {
                            Label("Signed In", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                        }

                        Button("Sign Out", role: .destructive) {
                            appModel.signOut()
                        }
                    } else {
                        Label("Not Signed In", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                // Debug Section
                Section("Debug") {
                    if let queue = appModel.activeQueue {
                        LabeledContent("Active Queue", value: queue.displayName)
                        LabeledContent("Queue State", value: queue.state.rawValue.capitalized)
                        LabeledContent("Queue Items", value: "\(queue.items)")
                    } else {
                        LabeledContent("Active Queue", value: "None")
                    }

                    LabeledContent("Players Online", value: "\(appModel.players.count)")
                    LabeledContent("Providers Loaded", value: "\(providerCount)")
                }

                // About Section
                Section("About") {
                    LabeledContent("App Version", value: appVersion)

                    Link(destination: URL(string: "https://music-assistant.io")!) {
                        HStack {
                            Label("Music Assistant Website", systemImage: "globe")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/music-assistant")!) {
                        HStack {
                            Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await loadCounts()
            }
            .refreshable {
                await loadCounts()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func loadCounts() async {
        guard let api = appModel.api else { return }

        do {
            let providers = try await api.getProviderConfigs()
            let players = try await api.getPlayerConfigs()

            await MainActor.run {
                providerCount = providers.count
                playerCount = players.count
            }
        } catch {
            // Silently fail - counts will just show 0
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppModel())
}
