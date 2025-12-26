import SwiftUI

struct PlayersView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingGroupBuilder = false

    var body: some View {
        NavigationStack {
            List {
                // Active Player Section
                activePlayerSection

                // Available Players Section
                availablePlayersSection

                // Unavailable Players Section
                unavailablePlayersSection
            }
            .navigationTitle("Players")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGroupBuilder = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showingGroupBuilder) {
                SpeakerGroupSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .refreshable {
                await appModel.refresh()
            }
        }
    }

    @ViewBuilder
    private var activePlayerSection: some View {
        if let selectedID = appModel.selectedPlayerID {
            if let selectedPlayer = appModel.players.first(where: { $0.playerID == selectedID }) {
                Section {
                    ActivePlayerCard(player: selectedPlayer)
                } header: {
                    Text("Now Playing On")
                }
            }
        }
    }

    @ViewBuilder
    private var availablePlayersSection: some View {
        Section {
            let availablePlayers = appModel.players.filter { $0.available }

            if availablePlayers.isEmpty {
                ContentUnavailableView(
                    "No Players Available",
                    systemImage: "hifispeaker.slash",
                    description: Text("Make sure your players are powered on and connected.")
                )
            } else {
                ForEach(availablePlayers) { player in
                    PlayerRow(
                        player: player,
                        isSelected: player.playerID == appModel.selectedPlayerID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appModel.selectedPlayerID = player.playerID
                        Task { await appModel.refresh() }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !player.groupMembers.isEmpty || player.syncedTo != nil {
                            Button("Ungroup") {
                                Task {
                                    await appModel.ungroupPlayers(playerIDs: [player.playerID])
                                }
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        } header: {
            Text("Available Players")
        }
    }

    @ViewBuilder
    private var unavailablePlayersSection: some View {
        let unavailablePlayers = appModel.players.filter { !$0.available }

        if !unavailablePlayers.isEmpty {
            Section {
                ForEach(unavailablePlayers) { player in
                    HStack {
                        Image(systemName: iconForPlayer(player))
                            .foregroundStyle(.tertiary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.name)
                                .foregroundStyle(.secondary)

                            Text("Unavailable")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Unavailable")
            }
        }
    }

    private func iconForPlayer(_ player: MAPlayer) -> String {
        if !player.groupMembers.isEmpty {
            return "hifispeaker.2"
        }

        switch player.type?.lowercased() {
        case "airplay":
            return "airplayaudio"
        case "chromecast", "cast":
            return "tv"
        default:
            return "hifispeaker"
        }
    }
}

// MARK: - Active Player Card

private struct ActivePlayerCard: View {
    @EnvironmentObject private var appModel: AppModel
    let player: MAPlayer
    @State private var volume: Double = 50

    var body: some View {
        VStack(spacing: 16) {
            // Player info
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: iconForPlayer)
                        .font(.title2)
                        .foregroundStyle(.pink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name)
                        .font(.headline)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(player.playbackState.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !player.groupMembers.isEmpty {
                        Text("\(player.groupMembers.count + 1) speakers in group")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                }

                Spacer()
            }

            // Volume slider
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: $volume, in: 0...100) { editing in
                        if !editing {
                            Task {
                                await appModel.setVolume(
                                    playerID: player.playerID,
                                    level: Int(volume)
                                )
                            }
                        }
                    }
                    .tint(.pink)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(Int(volume))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            if let level = player.volumeLevel {
                volume = Double(level)
            }
        }
        .onChange(of: player.volumeLevel) { _, newValue in
            if let newValue {
                volume = Double(newValue)
            }
        }
    }

    private var iconForPlayer: String {
        if !player.groupMembers.isEmpty {
            return "hifispeaker.2.fill"
        }

        switch player.type?.lowercased() {
        case "airplay":
            return "airplayaudio"
        case "chromecast", "cast":
            return "tv.fill"
        default:
            return "hifispeaker.fill"
        }
    }

    private var statusColor: Color {
        switch player.playbackState {
        case .playing:
            return .green
        case .paused:
            return .orange
        case .idle, .unknown:
            return .secondary
        }
    }
}

// MARK: - Player Row

private struct PlayerRow: View {
    @EnvironmentObject private var appModel: AppModel
    let player: MAPlayer
    let isSelected: Bool
    @State private var volume: Double = 50

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Player icon
                Image(systemName: iconForPlayer)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .pink : .primary)
                    .frame(width: 32)

                // Player info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(player.name)
                            .font(.body)
                            .foregroundStyle(isSelected ? .pink : .primary)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.pink)
                        }
                    }

                    HStack(spacing: 8) {
                        statusIndicator
                        groupIndicator
                    }
                }

                Spacer()

                // Volume indicator
                volumeIndicator
            }

            // Volume control (only for selected player)
            if isSelected {
                volumeSlider
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            if let level = player.volumeLevel {
                volume = Double(level)
            }
        }
        .onChange(of: player.volumeLevel) { _, newValue in
            if let newValue {
                volume = Double(newValue)
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(player.playbackState.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var groupIndicator: some View {
        if !player.groupMembers.isEmpty {
            Text("• \(player.groupMembers.count + 1) speakers")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if player.syncedTo != nil {
            Text("• Grouped")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var volumeIndicator: some View {
        if let volumeLevel = player.volumeLevel {
            HStack(spacing: 4) {
                Image(systemName: volumeIcon(for: volumeLevel))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(volumeLevel)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var volumeSlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Slider(value: $volume, in: 0...100) { editing in
                if !editing {
                    Task {
                        await appModel.setVolume(
                            playerID: player.playerID,
                            level: Int(volume)
                        )
                    }
                }
            }
            .tint(.pink)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
        .padding(.top, 4)
    }

    private func volumeIcon(for level: Int) -> String {
        if level == 0 {
            return "speaker.slash.fill"
        } else if level > 50 {
            return "speaker.wave.3.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    private var iconForPlayer: String {
        if !player.groupMembers.isEmpty {
            return "hifispeaker.2.fill"
        }

        switch player.type?.lowercased() {
        case "airplay":
            return "airplayaudio"
        case "chromecast", "cast":
            return "tv.fill"
        default:
            return "hifispeaker.fill"
        }
    }

    private var statusColor: Color {
        switch player.playbackState {
        case .playing:
            return .green
        case .paused:
            return .orange
        case .idle, .unknown:
            return .secondary
        }
    }
}
