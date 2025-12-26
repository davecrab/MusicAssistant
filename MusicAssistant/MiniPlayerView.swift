import SwiftUI

// MARK: - Glassed Effect Extension

extension View {
    @ViewBuilder
    func glassedEffect(in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background {
                    shape
                        .fill(.ultraThinMaterial)
                        .stroke(.primary.opacity(0.2), lineWidth: 0.7)
                }
                .clipShape(shape)
        }
    }
}

// MARK: - Mini Player View

struct MiniPlayerView: View {
    @EnvironmentObject private var appModel: AppModel
    let queue: MAPlayerQueue?
    let onTap: () -> Void

    @State private var showingSpeakerSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at top (only when playing)
            // Uses UnevenRoundedRectangle to match the parent's top corners
            // TODO: make a constant for the radius values and use across progress bar and mini player background
            if let queue, queue.currentItem != nil {
                GeometryReader { geometry in
                    let progress: CGFloat =
                        queue.currentItem?.duration.map { duration in
                            duration > 0 ? queue.elapsedTime / Double(duration) : 0
                        } ?? 0

                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20,
                        style: .continuous
                    )
                    .fill(Color(.systemGray5).opacity(0.3))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: progress > 0.95 ? 20 : 0,
                            style: .continuous
                        )
                        .fill(Color.pink)
                        .frame(width: geometry.size.width * min(1, max(0, progress)))
                    }
                }
                .frame(height: 3)
            }

            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Artwork
                    if let queue, let item = queue.currentItem {
                        ArtworkView(
                            urlString: item.image?.resolvedPath
                                ?? item.mediaItem?.artworkPath
                                ?? appModel.players.first(where: {
                                    $0.playerID == appModel.selectedPlayerID
                                })?.currentMedia?.imageURL,
                            baseURL: appModel.settings.serverURL,
                            cornerRadius: 6
                        )
                        .frame(width: 48, height: 48)
                    } else {
                        // Placeholder artwork when nothing playing
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(.systemGray5))
                                .frame(width: 48, height: 48)

                            Image(systemName: "music.note")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        if let queue, let item = queue.currentItem {
                            Text(item.mediaItem?.name ?? item.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.primary)

                            Text(item.mediaItem?.artistName ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("Not Playing")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(selectedPlayerName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    // Play/Pause button
                    Button {
                        Task { await appModel.togglePlayPause() }
                    } label: {
                        Image(
                            systemName: (queue?.state == .playing) ? "pause.fill" : "play.fill"
                        )
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(queue?.currentItem == nil)
                    .opacity(queue?.currentItem == nil ? 0.4 : 1)

                    // Next track button
                    Button {
                        Task { await appModel.nextTrack() }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(queue?.currentItem == nil)
                    .opacity(queue?.currentItem == nil ? 0.4 : 1)

                    // Speaker/AirPlay button
                    Button {
                        showingSpeakerSheet = true
                    } label: {
                        ZStack {
                            Image(systemName: speakerIcon)
                                .font(.title3)
                                .foregroundStyle(hasGroupedSpeakers ? .pink : .primary)
                                .frame(width: 36, height: 44)

                            // Badge for grouped speakers
                            if groupedSpeakerCount > 1 {
                                Text("\(groupedSpeakerCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.pink)
                                    .clipShape(Capsule())
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .glassedEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .sheet(isPresented: $showingSpeakerSheet) {
            SpeakerGroupSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var selectedPlayerName: String {
        guard let selectedID = appModel.selectedPlayerID,
            let player = appModel.players.first(where: { $0.playerID == selectedID })
        else {
            return "No Speaker Selected"
        }
        return player.name
    }

    private var hasGroupedSpeakers: Bool {
        guard let selectedID = appModel.selectedPlayerID,
            let player = appModel.players.first(where: { $0.playerID == selectedID })
        else { return false }
        return !player.groupMembers.isEmpty
    }

    private var groupedSpeakerCount: Int {
        guard let selectedID = appModel.selectedPlayerID,
            let player = appModel.players.first(where: { $0.playerID == selectedID })
        else { return 1 }
        return player.groupMembers.count + 1  // +1 for the main speaker
    }

    private var speakerIcon: String {
        guard let selectedID = appModel.selectedPlayerID,
            let player = appModel.players.first(where: { $0.playerID == selectedID })
        else {
            return "hifispeaker"
        }

        if !player.groupMembers.isEmpty {
            return "hifispeaker.2.fill"
        }

        switch player.type?.lowercased() {
        case "airplay":
            return "airplayaudio"
        case "chromecast", "cast":
            return "tv"
        case "sonos":
            return "hifispeaker"
        default:
            return "hifispeaker"
        }
    }
}

// MARK: - Speaker Group Sheet

struct SpeakerGroupSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Current Speaker Section
                if let selectedID = appModel.selectedPlayerID,
                    let selectedPlayer = appModel.players.first(where: {
                        $0.playerID == selectedID
                    })
                {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.pink.opacity(0.15))
                                    .frame(width: 44, height: 44)

                                Image(systemName: iconForPlayer(selectedPlayer))
                                    .font(.title3)
                                    .foregroundStyle(.pink)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedPlayer.name)
                                    .font(.headline)

                                if !selectedPlayer.groupMembers.isEmpty {
                                    Text(
                                        "\(selectedPlayer.groupMembers.count + 1) speakers in group"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                } else {
                                    Text("Primary Speaker")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.pink)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Playing On")
                    }
                }

                // Available Speakers to Add/Remove
                Section {
                    let otherPlayers = appModel.players.filter {
                        $0.available && $0.playerID != appModel.selectedPlayerID
                    }

                    if otherPlayers.isEmpty {
                        Text("No other speakers available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(otherPlayers) { player in
                            SpeakerToggleRow(player: player)
                        }
                    }
                } header: {
                    Text("Add Speakers")
                } footer: {
                    Text("Toggle speakers to add or remove them from the group.")
                }

                // Change Primary Speaker
                Section {
                    ForEach(appModel.players.filter { $0.available }) { player in
                        Button {
                            appModel.selectedPlayerID = player.playerID
                            Task { await appModel.refresh() }
                        } label: {
                            HStack {
                                Image(systemName: iconForPlayer(player))
                                    .foregroundStyle(.primary)
                                    .frame(width: 24)

                                Text(player.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if player.playerID == appModel.selectedPlayerID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.pink)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Select Primary Speaker")
                }
            }
            .navigationTitle("Speakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
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

// MARK: - Speaker Toggle Row

struct SpeakerToggleRow: View {
    @EnvironmentObject private var appModel: AppModel
    let player: MAPlayer

    private var isInGroup: Bool {
        guard let selectedID = appModel.selectedPlayerID,
            let selectedPlayer = appModel.players.first(where: { $0.playerID == selectedID })
        else { return false }
        return selectedPlayer.groupMembers.contains(player.playerID)
    }

    var body: some View {
        Button {
            Task { await togglePlayer() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconForPlayer)
                    .font(.title3)
                    .foregroundStyle(isInGroup ? .pink : .primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let volume = player.volumeLevel {
                        Text("Volume: \(volume)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Toggle indicator
                Image(systemName: isInGroup ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isInGroup ? .pink : .secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconForPlayer: String {
        switch player.type?.lowercased() {
        case "airplay":
            return "airplayaudio"
        case "chromecast", "cast":
            return "tv"
        default:
            return "hifispeaker"
        }
    }

    private func togglePlayer() async {
        guard let selectedID = appModel.selectedPlayerID,
            let selectedPlayer = appModel.players.first(where: { $0.playerID == selectedID })
        else { return }

        if isInGroup {
            // Remove from group
            await appModel.ungroupPlayers(playerIDs: [player.playerID])
        } else {
            // Add to group
            var newMembers = selectedPlayer.groupMembers
            newMembers.append(player.playerID)
            await appModel.groupPlayers(targetPlayerID: selectedID, childPlayerIDs: newMembers)
        }
    }
}

// MARK: - Playing Indicator

struct PlayingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.pink)
                    .frame(width: 3, height: animating ? CGFloat.random(in: 8...16) : 4)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .frame(width: 16, height: 16)
        .onAppear {
            animating = true
        }
    }
}
