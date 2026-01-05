import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPlayerPicker = false
    @State private var showingQueue = false

    private var queue: MAPlayerQueue? {
        appModel.activeQueue
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        if let currentQueue = queue, let item = currentQueue.currentItem {
                            Spacer()
                                .frame(height: 20)

                            artworkView(item: item, geometry: geometry)
                            trackInfoView(item: item)
                            ProgressSection(queue: currentQueue)
                                .padding(.horizontal, 24)
                            PlaybackControlsSection(queue: currentQueue)
                                .padding(.horizontal, 24)
                            VolumeSection()
                                .padding(.horizontal, 24)
                            PlayerOutputButton(showingPlayerPicker: $showingPlayerPicker)
                                .padding(.horizontal, 24)

                            Spacer()
                                .frame(height: 20)
                        } else {
                            Spacer()
                            ContentUnavailableView(
                                "Nothing Playing",
                                systemImage: "music.note",
                                description: Text("Select a track to play")
                            )
                            Spacer()
                        }
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("PLAYING FROM")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(appModel.activeQueue?.displayName ?? "Library")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingQueue = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingPlayerPicker) {
                SpeakerGroupSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingQueue) {
                QueueView()
            }
        }
    }

    @ViewBuilder
    private func artworkView(item: MAQueueItem, geometry: GeometryProxy) -> some View {
        let artworkURL =
            item.image?.resolvedPath
            ?? item.mediaItem?.artworkPath
            ?? currentPlayerMediaURL

        let size = max(0, min(geometry.size.width - 48, 340))

        ArtworkView(
            urlString: artworkURL,
            baseURL: appModel.settings.serverURL
        )
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    private var currentPlayerMediaURL: String? {
        guard let selectedID = appModel.selectedPlayerID else { return nil }
        let player = appModel.players.first { $0.playerID == selectedID }
        return player?.currentMedia?.imageURL
    }

    @ViewBuilder
    private func trackInfoView(item: MAQueueItem) -> some View {
        VStack(spacing: 6) {
            Text(item.mediaItem?.name ?? item.name)
                .font(.title2.weight(.bold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(item.mediaItem?.artistName ?? "")
                .font(.title3)
                .foregroundStyle(.pink)
                .lineLimit(1)

            if let albumName = item.mediaItem?.albumName, !albumName.isEmpty {
                Text(albumName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Progress Section

private struct ProgressSection: View {
    @EnvironmentObject private var appModel: AppModel
    let queue: MAPlayerQueue

    @State private var isScrubbing = false
    @State private var scrubValue: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            progressBar
            timeLabels
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary)
                    .frame(width: geometry.size.width * displayProgress, height: 4)

                Circle()
                    .fill(Color.primary)
                    .frame(width: isScrubbing ? 16 : 12, height: isScrubbing ? 16 : 12)
                    .offset(
                        x: max(0, geometry.size.width * displayProgress - (isScrubbing ? 8 : 6))
                    )
                    .animation(.easeInOut(duration: 0.15), value: isScrubbing)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isScrubbing {
                            isScrubbing = true
                            scrubValue = progressValue
                        }
                        let newValue = value.location.x / geometry.size.width
                        scrubValue = min(1, max(0, newValue))
                    }
                    .onEnded { _ in
                        let seekTime = scrubValue * Double(queue.currentItem?.duration ?? 0)
                        Task {
                            await appModel.seek(to: seekTime)
                        }
                        isScrubbing = false
                    }
            )
        }
        .frame(height: 20)
    }

    private var displayProgress: CGFloat {
        isScrubbing ? scrubValue : progressValue
    }

    private var displayTime: Double {
        if isScrubbing {
            return scrubValue * Double(queue.currentItem?.duration ?? 0)
        }
        return queue.elapsedTime
    }

    private var timeLabels: some View {
        HStack {
            Text(formatTime(displayTime))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            Text("-\(formatTime(displayRemainingTime))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var progressValue: CGFloat {
        guard let duration = queue.currentItem?.duration, duration > 0 else { return 0 }
        let progress = queue.elapsedTime / Double(duration)
        return min(1, max(0, progress))
    }

    private var remainingTime: Double {
        guard let duration = queue.currentItem?.duration else { return 0 }
        return max(0, Double(duration) - queue.elapsedTime)
    }

    private var displayRemainingTime: Double {
        guard let duration = queue.currentItem?.duration else { return 0 }
        return max(0, Double(duration) - displayTime)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Playback Controls Section

private struct PlaybackControlsSection: View {
    @EnvironmentObject private var appModel: AppModel
    let queue: MAPlayerQueue

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                shuffleButton
                previousButton
                playPauseButton
                nextButton
                repeatButton
            }
        }
    }

    private var shuffleButton: some View {
        Button {
            Task { await appModel.setShuffle(enabled: !queue.shuffleEnabled) }
        } label: {
            Image(systemName: "shuffle")
                .font(.title3)
                .foregroundColor(queue.shuffleEnabled ? .pink : .secondary)
        }
    }

    private var previousButton: some View {
        Button {
            Task { await appModel.previousTrack() }
        } label: {
            Image(systemName: "backward.fill")
                .font(.title)
                .foregroundColor(.primary)
        }
    }

    private var playPauseButton: some View {
        Button {
            Task { await appModel.togglePlayPause() }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 72, height: 72)

                Image(systemName: queue.state == .playing ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(Color(.systemBackground))
                    .offset(x: queue.state == .playing ? 0 : 2)
            }
        }
    }

    private var nextButton: some View {
        Button {
            Task { await appModel.nextTrack() }
        } label: {
            Image(systemName: "forward.fill")
                .font(.title)
                .foregroundColor(.primary)
        }
    }

    private var repeatButton: some View {
        Button {
            Task { await appModel.cycleRepeatMode() }
        } label: {
            Image(systemName: repeatIcon)
                .font(.title3)
                .foregroundColor(queue.repeatMode == .off ? .secondary : .pink)
        }
    }

    private var repeatIcon: String {
        switch queue.repeatMode {
        case .one:
            return "repeat.1"
        default:
            return "repeat"
        }
    }
}

// MARK: - Volume Section

private struct VolumeSection: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var volume: Double = 50

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(value: $volume, in: 0...100) { editing in
                if !editing {
                    Task { await setVolume() }
                }
            }
            .tint(.primary)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            loadVolume()
        }
        .onChange(of: appModel.selectedPlayerID) { _, _ in
            loadVolume()
        }
    }

    private func loadVolume() {
        guard let selectedID = appModel.selectedPlayerID else { return }
        guard let player = appModel.players.first(where: { $0.playerID == selectedID }) else {
            return
        }
        if let level = player.volumeLevel {
            volume = Double(level)
        }
    }

    private func setVolume() async {
        guard let api = appModel.api,
            let playerID = appModel.selectedPlayerID
        else { return }
        do {
            try await api.executeVoid(
                command: "players/cmd/volume_set",
                args: [
                    "player_id": .string(playerID),
                    "volume_level": .int(Int(volume)),
                ]
            )
        } catch {
            // Silently fail volume changes
        }
    }
}

// MARK: - Player Output Button

private struct PlayerOutputButton: View {
    @EnvironmentObject private var appModel: AppModel
    @Binding var showingPlayerPicker: Bool

    var body: some View {
        Button {
            showingPlayerPicker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: playerIcon)
                        .font(.body)
                        .foregroundStyle(.pink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPlayer?.name ?? "Select Speaker")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    if let player = selectedPlayer, !player.groupMembers.isEmpty {
                        Text("\(player.groupMembers.count + 1) speakers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var selectedPlayer: MAPlayer? {
        guard let selectedID = appModel.selectedPlayerID else { return nil }
        return appModel.players.first { $0.playerID == selectedID }
    }

    private var playerIcon: String {
        guard let player = selectedPlayer else { return "hifispeaker" }

        if !player.groupMembers.isEmpty {
            return "hifispeaker.2.fill"
        }

        switch player.type?.lowercased() {
        case "ios_device":
            return "iphone"
        case "airplay":
            return "airplayaudio"
        case "chromecast", "cast":
            return "tv.fill"
        default:
            return "hifispeaker.fill"
        }
    }
}

// MARK: - Queue View

private struct QueueView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var queueItems: [MAQueueItem] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if queueItems.isEmpty {
                    ContentUnavailableView(
                        "Queue Empty",
                        systemImage: "list.bullet",
                        description: Text("Add some tracks to the queue")
                    )
                } else {
                    queueList
                }
            }
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await loadQueue()
            }
        }
    }

    private var queueList: some View {
        List {
            ForEach(Array(queueItems.enumerated()), id: \.element.id) { index, item in
                QueueItemRow(
                    item: item,
                    isPlaying: index == appModel.activeQueue?.currentIndex
                )
            }
        }
        .listStyle(.plain)
    }

    private func loadQueue() async {
        guard let api = appModel.api,
            let queueID = appModel.activeQueue?.queueID
        else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await api.execute(
                command: "player_queues/items",
                args: ["queue_id": .string(queueID)],
                as: [MAQueueItem].self
            )
            queueItems = items
        } catch {
            // Silently fail
        }
    }
}

// MARK: - Queue Item Row

private struct QueueItemRow: View {
    @EnvironmentObject private var appModel: AppModel
    let item: MAQueueItem
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(
                urlString: item.image?.resolvedPath ?? item.mediaItem?.artworkPath,
                baseURL: appModel.settings.serverURL,
                cornerRadius: 4
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.mediaItem?.name ?? item.name)
                    .font(.body)
                    .foregroundStyle(isPlaying ? .pink : .primary)
                    .lineLimit(1)

                Text(item.mediaItem?.artistName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isPlaying {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.pink)
                    .symbolEffect(.variableColor.iterative)
            } else if let duration = item.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
