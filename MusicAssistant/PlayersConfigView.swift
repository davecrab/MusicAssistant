import SwiftUI

// MARK: - Players Config List View

struct PlayersConfigView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var playerConfigs: [MAPlayerConfig] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    var filteredConfigs: [MAPlayerConfig] {
        var configs = playerConfigs.sorted { $0.displayName < $1.displayName }

        if !searchText.isEmpty {
            configs = configs.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return configs
    }

    var body: some View {
        content
        .navigationTitle("Players")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadPlayers() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable {
            await loadPlayers()
        }
        .task {
            await loadPlayers()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading players...")
        } else if let error = errorMessage {
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") {
                    Task { await loadPlayers() }
                }
            }
        } else if playerConfigs.isEmpty {
            ContentUnavailableView {
                Label("No Players", systemImage: "speaker.slash")
            } description: {
                Text(
                    "No player configurations found. Add a player provider to discover players."
                )
            }
        } else {
            List {
                // Stats Section
                Section {
                    HStack {
                        Label("Total Players", systemImage: "speaker.wave.2")
                        Spacer()
                        Text("\(playerConfigs.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Enabled", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(playerConfigs.filter { $0.enabled }.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                // Players List
                Section {
                    ForEach(filteredConfigs) { config in
                        NavigationLink(destination: EditPlayerConfigView(playerConfig: config))
                        {
                            PlayerConfigRow(
                                config: config,
                                player: appModel.players.first(where: {
                                    $0.playerID == config.playerID
                                }))
                        }
                    }
                } header: {
                    Text("Players")
                }
            }
            .searchable(text: $searchText, prompt: "Search players")
        }
    }

    private func loadPlayers() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            playerConfigs = try await api.getPlayerConfigs()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Player Config Row

struct PlayerConfigRow: View {
    let config: MAPlayerConfig
    let player: MAPlayer?

    var body: some View {
        HStack(spacing: 12) {
            // Player Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(playerColor.opacity(0.15))

                Image(systemName: playerIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(playerColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.displayName)
                        .font(.headline)

                    if !config.enabled {
                        Text("Disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    // Provider
                    Text(config.provider)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Availability status
                    if let player = player {
                        if player.available {
                            Label("Available", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Unavailable", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Label("Offline", systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Player state indicator
            if let player = player, player.playbackState == .playing {
                Image(systemName: "waveform")
                    .foregroundStyle(.green)
                    .symbolEffect(.variableColor.iterative)
            }
        }
        .padding(.vertical, 4)
        .opacity(config.enabled ? 1.0 : 0.6)
    }

    private var playerIcon: String {
        if let type = player?.type {
            switch type {
            case "group": return "speaker.wave.2.fill"
            case "stereo_pair": return "speaker.2.fill"
            default: return "speaker.wave.2"
            }
        }
        return "speaker.wave.2"
    }

    private var playerColor: Color {
        switch config.provider.lowercased() {
        case "sonos": return .orange
        case "chromecast": return .blue
        case "airplay": return .gray
        case "slimproto": return .green
        case "snapcast": return .purple
        case "hass": return .cyan
        case "bluesound": return .indigo
        default: return .accentColor
        }
    }
}

// MARK: - Edit Player Config View

struct EditPlayerConfigView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let playerConfig: MAPlayerConfig

    @State private var configEntries: [MAConfigEntry] = []
    @State private var values: [String: AnyCodable] = [:]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    var player: MAPlayer? {
        appModel.players.first(where: { $0.playerID == playerConfig.playerID })
    }

    var body: some View {
        content
        .navigationTitle("Player Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveConfig() }
                }
                .disabled(isSaving)
            }
        }
        .overlay {
            if isSaving {
                ProgressView("Saving...")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .confirmationDialog(
            "Remove Player",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task { await deletePlayer() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Are you sure you want to remove \(playerConfig.displayName)? This cannot be undone."
            )
        }
        .task {
            await loadConfigEntries()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading configuration...")
        } else if let error = errorMessage {
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") {
                    Task { await loadConfigEntries() }
                }
            }
        } else {
            Form {
                // Player Info Header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.accentColor.opacity(0.15))

                            Image(systemName: playerIcon)
                                .font(.system(size: 30))
                                .foregroundStyle(Color.accentColor)
                        }
                        .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(playerConfig.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Provider: \(playerConfig.provider)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let player = player {
                                HStack {
                                    Circle()
                                        .fill(player.available ? .green : .orange)
                                        .frame(width: 8, height: 8)
                                    Text(player.available ? "Available" : "Unavailable")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Current State (if player is available)
                if let player = player, player.available {
                    Section("Current State") {
                        LabeledContent(
                            "Playback State", value: player.playbackState.rawValue.capitalized)

                        if let volume = player.volumeLevel {
                            LabeledContent("Volume", value: "\(volume)%")
                        }

                        if player.volumeMuted == true {
                            Label("Muted", systemImage: "speaker.slash.fill")
                                .foregroundStyle(.orange)
                        }

                        if let currentMedia = player.currentMedia {
                            LabeledContent(
                                "Now Playing", value: currentMedia.title ?? "Unknown")
                        }
                    }
                }

                // Config Entries
                ConfigEntriesFormView(
                    entries: configEntries,
                    values: $values,
                    onAction: handleAction
                )

                // Actions Section
                Section {
                    // Enable/Disable toggle
                    Button {
                        Task { await toggleEnabled() }
                    } label: {
                        Label(
                            playerConfig.enabled ? "Disable Player" : "Enable Player",
                            systemImage: playerConfig.enabled ? "pause.circle" : "play.circle"
                        )
                    }

                    if canDelete {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Remove Player", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var playerIcon: String {
        if let type = player?.type {
            switch type {
            case "group": return "speaker.wave.2.fill"
            case "stereo_pair": return "speaker.2.fill"
            default: return "speaker.wave.2"
            }
        }
        return "speaker.wave.2"
    }

    private var canDelete: Bool {
        // Group players can typically be deleted
        if let type = player?.type, type == "group" {
            return true
        }
        // Check if provider supports removing players
        // For now, we'll show the option and let the API handle errors
        return false
    }

    private func loadConfigEntries(action: String? = nil) async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            isLoading = false
            return
        }

        isLoading = action == nil
        errorMessage = nil

        do {
            configEntries = try await api.getPlayerConfigEntries(
                playerID: playerConfig.playerID,
                action: action,
                values: action != nil ? values : nil
            )

            // Initialize values from entries
            for entry in configEntries {
                if values[entry.key] == nil {
                    values[entry.key] = entry.value ?? entry.defaultValue
                }
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleAction(_ action: String) {
        Task {
            await loadConfigEntries(action: action)
        }
    }

    private func saveConfig() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            return
        }

        isSaving = true

        do {
            _ = try await api.savePlayerConfig(
                playerID: playerConfig.playerID,
                values: values
            )

            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleEnabled() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            return
        }

        isSaving = true

        do {
            var newValues = values
            newValues["enabled"] = AnyCodable(!playerConfig.enabled)

            _ = try await api.savePlayerConfig(
                playerID: playerConfig.playerID,
                values: newValues
            )

            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deletePlayer() async {
        guard let api = appModel.api else {
            errorMessage = "Not connected to server"
            return
        }

        do {
            try await api.removePlayerConfig(playerID: playerConfig.playerID)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlayersConfigView()
            .environmentObject(AppModel())
    }
}
