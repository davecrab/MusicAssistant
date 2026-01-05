import Combine
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var settings = AppSettings()
    @Published private(set) var authProviders: [AuthProvider] = []

    @Published private(set) var players: [MAPlayer] = []
    @Published private(set) var activeQueue: MAPlayerQueue?

    @Published var selectedPlayerID: String?
    @Published var isBusy: Bool = false
    @Published var lastError: String?

    /// Connection state for showing connecting banner
    @Published private(set) var connectionState: ConnectionState = .disconnected

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting

        var isConnected: Bool {
            self == .connected
        }

        var showBanner: Bool {
            self == .connecting || self == .reconnecting
        }

        var message: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting to server..."
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting..."
            }
        }
    }

    private var pollTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var wasConnectedBeforeBackground = false

    private let localPlayerID: String
    private let localPlayerName: String
    private let localPlayback = LocalPlaybackManager()
    private var localQueue: MAPlayerQueue?

    private lazy var nowPlaying = NowPlayingBridge(
        onPlayPause: { [weak self] in await self?.togglePlayPause() },
        onNext: { [weak self] in await self?.nextTrack() },
        onPrevious: { [weak self] in await self?.previousTrack() },
        onSeek: { [weak self] position in await self?.seek(to: position) }
    )

    var api: MusicAssistantAPI? {
        guard let baseURL = settings.serverURL else { return nil }
        return MusicAssistantAPI(baseURL: baseURL, token: settings.token)
    }

    var isSignedIn: Bool { settings.token != nil && settings.serverURL != nil }

    init() {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        localPlayerID = "ios-device:\(deviceID)"
        localPlayerName = "This \(UIDevice.current.model)"

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.restartPollingIfNeeded()
            }
            .store(in: &cancellables)

        localPlayback.onItemFinished = { [weak self] in
            Task { await self?.nextTrack() }
        }
        localPlayback.$elapsedTime
            .sink { [weak self] _ in
                self?.syncLocalQueueFromPlayback()
            }
            .store(in: &cancellables)
        localPlayback.$playbackState
            .sink { [weak self] _ in
                self?.syncLocalQueueFromPlayback()
                self?.syncLocalPlayerFromPlayback()
            }
            .store(in: &cancellables)

        restartPollingIfNeeded()

        // Observe app lifecycle for background/foreground transitions
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppDidBecomeActive()
                }
            }
            .store(in: &cancellables)
    }

    private func handleAppWillResignActive() {
        wasConnectedBeforeBackground = connectionState == .connected
    }

    private func handleAppDidBecomeActive() {
        guard isSignedIn else { return }
        // If we were connected before going to background, show reconnecting
        if wasConnectedBeforeBackground {
            connectionState = .reconnecting
        } else if connectionState == .disconnected {
            connectionState = .connecting
        }
        // Trigger an immediate refresh
        Task {
            await refresh()
        }
    }

    func loadAuthProviders() async {
        guard let api else { return }
        do {
            let providers = try await api.authProviders()
            authProviders = providers
        } catch {
            authProviders = [AuthProvider(id: "builtin", name: "Built-in")]
        }
    }

    func signIn(providerID: String, username: String, password: String) async {
        guard let api else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await api.login(
                providerID: providerID, username: username, password: password)
            settings.token = result.token
            lastError = nil
            connectionState = .connecting
            restartPollingIfNeeded()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func signOut() {
        settings.token = nil
        players = []
        activeQueue = nil
        selectedPlayerID = nil
        connectionState = .disconnected
        localPlayback.stop()
        nowPlaying.setActive(false)
        restartPollingIfNeeded()
    }

    func refresh() async {
        guard let api, isSignedIn else { return }

        // Set connecting state if not already connected
        if connectionState == .disconnected {
            connectionState = .connecting
        } else if connectionState == .connected {
            // Don't show reconnecting for quick refreshes
        }

        do {
            let serverPlayers = try await api.execute(
                command: "players/all", args: [:], as: [MAPlayer].self)

            let fetchedLocalQueue = try await api.executeOptional(
                command: "player_queues/get",
                args: ["queue_id": .string(localPlayerID)],
                as: MAPlayerQueue.self
            )
            localQueue = fetchedLocalQueue.map { mergedLocalQueue($0) }

            var mergedPlayers = serverPlayers
            mergedPlayers.insert(makeLocalDevicePlayer(), at: 0)
            self.players = mergedPlayers

            if selectedPlayerID == nil {
                selectedPlayerID = localPlayerID
            }

            if let playerID = selectedPlayerID {
                if isLocalDevicePlayer(playerID) {
                    if let queue = localQueue {
                        activeQueue = queue
                        nowPlaying.setBaseURL(settings.serverURL)
                        nowPlaying.update(queue: queue)
                    } else {
                        activeQueue = nil
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                    }
                } else {
                    let queue = try await api.executeOptional(
                        command: "player_queues/get_active_queue",
                        args: ["player_id": .string(playerID)],
                        as: MAPlayerQueue.self
                    )
                    activeQueue = queue
                    // Update base URL for artwork loading
                    nowPlaying.setBaseURL(settings.serverURL)
                    if let queue {
                        nowPlaying.update(queue: queue)
                    } else {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                    }
                }
            }

            lastError = nil
            connectionState = .connected
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors - these are expected during polling and app transitions
            if let urlError = error as? URLError, urlError.code == .cancelled {
                // Don't show cancelled errors to the user, but still handle connection state
                if connectionState == .connected {
                    connectionState = .reconnecting
                }
                return
            }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            // If we were connected, show reconnecting; otherwise stay in connecting
            if connectionState == .connected {
                connectionState = .reconnecting
            }
        }
    }

    func togglePlayPause() async {
        if isLocalDevicePlayer(selectedPlayerID) {
            if localPlayback.playbackState == .idle, let item = activeQueue?.currentItem {
                await startLocalPlayback(item: item)
                return
            }
            localPlayback.togglePlayPause()
            syncLocalQueueFromPlayback()
            return
        }

        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/play_pause", args: ["queue_id": .string(queueID)])
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func nextTrack() async {
        if isLocalDevicePlayer(selectedPlayerID) {
            guard let api else { return }
            do {
                try await api.executeVoid(
                    command: "player_queues/next", args: ["queue_id": .string(localPlayerID)])
                await refresh()
                if let item = activeQueue?.currentItem {
                    await startLocalPlayback(item: item)
                }
            } catch {
                // Suppress NSURLErrorCancelled (-999) errors
                if let urlError = error as? URLError, urlError.code == .cancelled { return }
                lastError =
                    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            }
            return
        }

        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/next", args: ["queue_id": .string(queueID)])
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func previousTrack() async {
        if isLocalDevicePlayer(selectedPlayerID) {
            guard let api else { return }
            do {
                try await api.executeVoid(
                    command: "player_queues/previous", args: ["queue_id": .string(localPlayerID)])
                await refresh()
                if let item = activeQueue?.currentItem {
                    await startLocalPlayback(item: item)
                }
            } catch {
                // Suppress NSURLErrorCancelled (-999) errors
                if let urlError = error as? URLError, urlError.code == .cancelled { return }
                lastError =
                    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            }
            return
        }

        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/previous", args: ["queue_id": .string(queueID)])
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func setShuffle(enabled: Bool) async {
        guard let api,
            let queueID =
                (isLocalDevicePlayer(selectedPlayerID) ? localPlayerID : activeQueue?.queueID)
        else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/shuffle",
                args: ["queue_id": .string(queueID), "shuffle_enabled": .bool(enabled)]
            )
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func seek(to seconds: Double) async {
        if isLocalDevicePlayer(selectedPlayerID) {
            localPlayback.seek(to: seconds)
            syncLocalQueueFromPlayback()
            return
        }

        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/seek",
                args: ["queue_id": .string(queueID), "position": .int(Int(seconds))]
            )
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func cycleRepeatMode() async {
        guard let api,
            let queueID =
                (isLocalDevicePlayer(selectedPlayerID) ? localPlayerID : activeQueue?.queueID)
        else { return }
        let current = activeQueue?.repeatMode ?? .off
        let next: MARepeatMode =
            switch current {
            case .off: .all
            case .all: .one
            case .one: .off
            case .unknown: .off
            }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/repeat",
                args: ["queue_id": .string(queueID), "repeat_mode": .string(next.rawValue)]
            )
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func groupPlayers(targetPlayerID: String, childPlayerIDs: [String]) async {
        if isLocalDevicePlayer(targetPlayerID)
            || childPlayerIDs.contains(where: { isLocalDevicePlayer($0) })
        {
            lastError = "Grouping is not supported with the iOS device player."
            return
        }
        guard let api else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await api.executeVoid(
                command: "players/cmd/group_many",
                args: [
                    "target_player": .string(targetPlayerID),
                    "child_player_ids": .array(childPlayerIDs.map { .string($0) }),
                ]
            )
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func ungroupPlayers(playerIDs: [String]) async {
        if playerIDs.contains(where: { isLocalDevicePlayer($0) }) {
            lastError = "Grouping is not supported with the iOS device player."
            return
        }
        guard let api else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await api.executeVoid(
                command: "players/cmd/ungroup_many",
                args: ["player_ids": .array(playerIDs.map { .string($0) })]
            )
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func setVolume(playerID: String, level: Int) async {
        if isLocalDevicePlayer(playerID) {
            lastError = "Volume control is not supported for the iOS device player."
            return
        }
        guard let api else { return }
        do {
            _ = try await api.executeVoid(
                command: "players/cmd/volume_set",
                args: [
                    "player_id": .string(playerID),
                    "volume_level": .int(level),
                ]
            )
            await refresh()
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func playMedia(uri: String, queueID: String? = nil) async {
        guard let api else { return }
        let targetQueueID =
            queueID ?? (isLocalDevicePlayer(selectedPlayerID) ? localPlayerID : selectedPlayerID)
            ?? players.first?.playerID
        guard let targetQueueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/play_media",
                args: [
                    "queue_id": .string(targetQueueID),
                    "media": .array([.string(uri)]),
                ]
            )
            await refresh()
            if isLocalDevicePlayer(selectedPlayerID), let item = activeQueue?.currentItem {
                await startLocalPlayback(item: item)
            }
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    // Play a single track
    func playTrack(_ track: MATrack) async {
        guard let uri = track.uri else { return }
        await playMedia(uri: uri)
    }

    /// Play an album
    func playAlbum(_ album: MAAlbum, shuffle: Bool = false) async {
        guard let api else { return }
        guard let uri = album.uri else { return }
        let targetQueueID =
            (isLocalDevicePlayer(selectedPlayerID) ? localPlayerID : selectedPlayerID)
            ?? players.first?.playerID
        guard let targetQueueID else { return }

        do {
            _ = try await api.executeVoid(
                command: "player_queues/play_media",
                args: [
                    "queue_id": .string(targetQueueID),
                    "media": .array([.string(uri)]),
                    "option": .string("replace"),
                ]
            )
            if shuffle {
                _ = try await api.executeVoid(
                    command: "player_queues/shuffle",
                    args: [
                        "queue_id": .string(targetQueueID),
                        "shuffle_enabled": .bool(true),
                    ]
                )
            }
            await refresh()
            if isLocalDevicePlayer(selectedPlayerID), let item = activeQueue?.currentItem {
                await startLocalPlayback(item: item)
            }
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    // Play a playlist
    func playPlaylist(_ playlist: MAPlaylist, shuffle: Bool = false) async {
        guard let api else { return }
        guard let uri = playlist.uri else { return }
        let targetQueueID =
            (isLocalDevicePlayer(selectedPlayerID) ? localPlayerID : selectedPlayerID)
            ?? players.first?.playerID
        guard let targetQueueID else { return }

        do {
            _ = try await api.executeVoid(
                command: "player_queues/play_media",
                args: [
                    "queue_id": .string(targetQueueID),
                    "media": .array([.string(uri)]),
                    "option": .string("replace"),
                ]
            )
            if shuffle {
                _ = try await api.executeVoid(
                    command: "player_queues/shuffle",
                    args: [
                        "queue_id": .string(targetQueueID),
                        "shuffle_enabled": .bool(true),
                    ]
                )
            }
            await refresh()
            if isLocalDevicePlayer(selectedPlayerID), let item = activeQueue?.currentItem {
                await startLocalPlayback(item: item)
            }
        } catch {
            // Suppress NSURLErrorCancelled (-999) errors
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    // Play a radio station
    func playRadio(_ station: MARadio) async {
        guard let uri = station.uri else { return }
        await playMedia(uri: uri)
    }

    private func restartPollingIfNeeded() {
        pollTask?.cancel()
        pollTask = nil

        guard isSignedIn else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            nowPlaying.setActive(true)
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func isLocalDevicePlayer(_ playerID: String?) -> Bool {
        playerID == localPlayerID
    }

    private func makeLocalDevicePlayer() -> MAPlayer {
        let title = localQueue?.currentItem?.mediaItem?.name ?? localQueue?.currentItem?.name
        let artist = localQueue?.currentItem?.mediaItem?.artistName
        let album = localQueue?.currentItem?.mediaItem?.albumName
        let imageURL =
            localQueue?.currentItem?.image?.resolvedPath
            ?? localQueue?.currentItem?.mediaItem?.artworkPath

        let currentMedia: MAPlayerMedia? =
            title == nil && artist == nil && album == nil && imageURL == nil
            ? nil
            : MAPlayerMedia(
                uri: localQueue?.currentItem?.mediaItem?.uri ?? "",
                title: title,
                artist: artist,
                album: album,
                imageURL: imageURL,
                duration: localQueue?.currentItem?.duration
            )

        return MAPlayer(
            playerID: localPlayerID,
            name: localPlayerName,
            available: true,
            playbackState: localPlayback.playbackState,
            volumeLevel: nil,
            volumeMuted: nil,
            groupMembers: [],
            syncedTo: nil,
            activeGroup: nil,
            currentMedia: currentMedia,
            type: "ios_device",
            icon: "mdi-cellphone"
        )
    }

    private func mergedLocalQueue(_ queue: MAPlayerQueue) -> MAPlayerQueue {
        MAPlayerQueue(
            queueID: queue.queueID,
            active: queue.active,
            displayName: queue.displayName,
            available: queue.available,
            items: queue.items,
            shuffleEnabled: queue.shuffleEnabled,
            repeatMode: queue.repeatMode,
            currentIndex: queue.currentIndex,
            elapsedTime: localPlayback.elapsedTime,
            state: localPlayback.playbackState,
            currentItem: queue.currentItem
        )
    }

    private func syncLocalQueueFromPlayback() {
        guard let queue = localQueue else { return }
        let mergedQueue = MAPlayerQueue(
            queueID: queue.queueID,
            active: queue.active,
            displayName: queue.displayName,
            available: queue.available,
            items: queue.items,
            shuffleEnabled: queue.shuffleEnabled,
            repeatMode: queue.repeatMode,
            currentIndex: queue.currentIndex,
            elapsedTime: localPlayback.elapsedTime,
            state: localPlayback.playbackState,
            currentItem: queue.currentItem
        )
        localQueue = mergedQueue
        if isLocalDevicePlayer(selectedPlayerID) {
            activeQueue = mergedQueue
            nowPlaying.update(queue: mergedQueue)
        }
    }

    private func syncLocalPlayerFromPlayback() {
        guard players.contains(where: { $0.playerID == localPlayerID }) else { return }
        if let index = players.firstIndex(where: { $0.playerID == localPlayerID }) {
            players[index] = makeLocalDevicePlayer()
        }
    }

    private func startLocalPlayback(item: MAQueueItem) async {
        guard let baseURL = settings.serverURL, let token = settings.token else { return }

        guard let streamURL = await resolveStreamURL(baseURL: baseURL, token: token, item: item)
        else {
            lastError = "Unable to start playback: could not resolve a stream URL."
            return
        }

        localPlayback.play(url: streamURL, startPosition: nil)
        syncLocalQueueFromPlayback()
        syncLocalPlayerFromPlayback()
    }

    private func resolveStreamURL(
        baseURL: URL,
        token: String,
        item: MAQueueItem
    ) async -> URL? {
        var candidates: [URL] = []
        let queueID = item.queueID.isEmpty ? localPlayerID : item.queueID

        let basePaths: [String] = [
            "/stream/\(queueID)/\(item.queueItemID)",
            "/stream/\(item.queueItemID)",
        ]

        var extendedPaths = basePaths
        if let details = item.streamDetails, !details.provider.isEmpty, !details.itemID.isEmpty {
            extendedPaths.append("/stream/\(details.provider)/\(details.itemID)")
            extendedPaths.append("/music/stream/\(details.provider)/\(details.itemID)")
        }

        for path in extendedPaths {
            var url = baseURL
            url.append(path: path)
            candidates.append(url)

            if let urlWithToken = url.appendingQueryItem(name: "token", value: token) {
                candidates.append(urlWithToken)
            }
            if let urlWithAccessToken = url.appendingQueryItem(name: "access_token", value: token) {
                candidates.append(urlWithAccessToken)
            }
        }

        for url in candidates {
            if await isReachableStreamURL(url: url, token: token) {
                return url
            }
        }
        return nil
    }

    private func isReachableStreamURL(url: URL, token: String) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("bytes=0-1", forHTTPHeaderField: "Range")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<400).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
