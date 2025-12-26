import Combine
import Foundation
import MediaPlayer

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var settings = AppSettings()
    @Published private(set) var authProviders: [AuthProvider] = []

    @Published private(set) var players: [MAPlayer] = []
    @Published private(set) var activeQueue: MAPlayerQueue?

    @Published var selectedPlayerID: String?
    @Published var isBusy: Bool = false
    @Published var lastError: String?

    private var pollTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    private lazy var nowPlaying = NowPlayingBridge(
        onPlayPause: { [weak self] in await self?.togglePlayPause() },
        onNext: { [weak self] in await self?.nextTrack() },
        onPrevious: { [weak self] in await self?.previousTrack() }
    )

    var api: MusicAssistantAPI? {
        guard let baseURL = settings.serverURL else { return nil }
        return MusicAssistantAPI(baseURL: baseURL, token: settings.token)
    }

    var isSignedIn: Bool { settings.token != nil && settings.serverURL != nil }

    init() {
        settings.objectWillChange
            .sink { [weak self] _ in
                self?.restartPollingIfNeeded()
            }
            .store(in: &cancellables)

        restartPollingIfNeeded()
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
            restartPollingIfNeeded()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func signOut() {
        settings.token = nil
        players = []
        activeQueue = nil
        selectedPlayerID = nil
        nowPlaying.setActive(false)
        restartPollingIfNeeded()
    }

    func refresh() async {
        guard let api, isSignedIn else { return }
        do {
            let players = try await api.execute(
                command: "players/all", args: [:], as: [MAPlayer].self)
            self.players = players

            if selectedPlayerID == nil {
                selectedPlayerID = players.first?.playerID
            }

            if let playerID = selectedPlayerID {
                let queue = try await api.execute(
                    command: "player_queues/get_active_queue",
                    args: ["player_id": .string(playerID)],
                    as: MAPlayerQueue.self
                )
                activeQueue = queue
                nowPlaying.update(queue: queue)
            }

            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func togglePlayPause() async {
        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/play_pause", args: ["queue_id": .string(queueID)])
            await refresh()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func nextTrack() async {
        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/next", args: ["queue_id": .string(queueID)])
            await refresh()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func previousTrack() async {
        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/previous", args: ["queue_id": .string(queueID)])
            await refresh()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func setShuffle(enabled: Bool) async {
        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/shuffle",
                args: ["queue_id": .string(queueID), "shuffle_enabled": .bool(enabled)]
            )
            await refresh()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func seek(to seconds: Double) async {
        guard let api, let queueID = activeQueue?.queueID else { return }
        do {
            _ = try await api.executeVoid(
                command: "player_queues/seek",
                args: ["queue_id": .string(queueID), "position": .int(Int(seconds))]
            )
            await refresh()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func cycleRepeatMode() async {
        guard let api, let queueID = activeQueue?.queueID else { return }
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
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func groupPlayers(targetPlayerID: String, childPlayerIDs: [String]) async {
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
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func ungroupPlayers(playerIDs: [String]) async {
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
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func setVolume(playerID: String, level: Int) async {
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
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func playMedia(uri: String, queueID: String? = nil) async {
        guard let api else { return }
        let targetQueueID = queueID ?? selectedPlayerID ?? players.first?.playerID
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
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// Play a track
    func playTrack(_ track: MATrack) async {
        guard let uri = track.uri else { return }
        await playMedia(uri: uri)
    }

    /// Play an album
    func playAlbum(_ album: MAAlbum, shuffle: Bool = false) async {
        guard let api else { return }
        guard let uri = album.uri else { return }
        let targetQueueID = selectedPlayerID ?? players.first?.playerID
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
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// Play a playlist
    func playPlaylist(_ playlist: MAPlaylist, shuffle: Bool = false) async {
        guard let api else { return }
        guard let uri = playlist.uri else { return }
        let targetQueueID = selectedPlayerID ?? players.first?.playerID
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
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// Play a radio station
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
}
