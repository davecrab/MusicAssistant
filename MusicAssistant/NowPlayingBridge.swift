import Foundation
import MediaPlayer
import UIKit

@MainActor
final class NowPlayingBridge {
    private let onPlayPause: () async -> Void
    private let onNext: () async -> Void
    private let onPrevious: () async -> Void
    private let onSeek: (Double) async -> Void

    private var isActive = false
    private var currentArtworkURL: String?
    private var artworkCache: [String: MPMediaItemArtwork] = [:]
    private var baseURL: URL?

    init(
        onPlayPause: @escaping () async -> Void,
        onNext: @escaping () async -> Void,
        onPrevious: @escaping () async -> Void,
        onSeek: @escaping (Double) async -> Void = { _ in }
    ) {
        self.onPlayPause = onPlayPause
        self.onNext = onNext
        self.onPrevious = onPrevious
        self.onSeek = onSeek
    }

    func setBaseURL(_ url: URL?) {
        baseURL = url
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active

        if active {
            let commandCenter = MPRemoteCommandCenter.shared()

            commandCenter.playCommand.isEnabled = true
            commandCenter.pauseCommand.isEnabled = true
            commandCenter.togglePlayPauseCommand.isEnabled = true
            commandCenter.nextTrackCommand.isEnabled = true
            commandCenter.previousTrackCommand.isEnabled = true
            commandCenter.changePlaybackPositionCommand.isEnabled = true

            commandCenter.playCommand.addTarget { [weak self] _ in
                guard let self else { return .commandFailed }
                Task { await self.onPlayPause() }
                return .success
            }
            commandCenter.pauseCommand.addTarget { [weak self] _ in
                guard let self else { return .commandFailed }
                Task { await self.onPlayPause() }
                return .success
            }
            commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
                guard let self else { return .commandFailed }
                Task { await self.onPlayPause() }
                return .success
            }
            commandCenter.nextTrackCommand.addTarget { [weak self] _ in
                guard let self else { return .commandFailed }
                Task { await self.onNext() }
                return .success
            }
            commandCenter.previousTrackCommand.addTarget { [weak self] _ in
                guard let self else { return .commandFailed }
                Task { await self.onPrevious() }
                return .success
            }
            commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
                guard let self,
                    let positionEvent = event as? MPChangePlaybackPositionCommandEvent
                else { return .commandFailed }
                Task { await self.onSeek(positionEvent.positionTime) }
                return .success
            }
        } else {
            let commandCenter = MPRemoteCommandCenter.shared()
            commandCenter.playCommand.removeTarget(nil)
            commandCenter.pauseCommand.removeTarget(nil)
            commandCenter.togglePlayPauseCommand.removeTarget(nil)
            commandCenter.nextTrackCommand.removeTarget(nil)
            commandCenter.previousTrackCommand.removeTarget(nil)
            commandCenter.changePlaybackPositionCommand.removeTarget(nil)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            currentArtworkURL = nil
        }
    }

    func update(queue: MAPlayerQueue) {
        guard let item = queue.currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            currentArtworkURL = nil
            return
        }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = item.mediaItem?.name ?? item.name
        info[MPMediaItemPropertyArtist] =
            item.mediaItem?.metadata.artist ?? item.mediaItem?.artistName
        info[MPMediaItemPropertyAlbumTitle] =
            item.mediaItem?.metadata.album ?? item.mediaItem?.albumName

        if let duration = item.duration {
            info[MPMediaItemPropertyPlaybackDuration] = Double(duration)
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = queue.elapsedTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = (queue.state == .playing) ? 1.0 : 0.0

        // Get artwork URL from queue item or media item
        let artworkPath = item.image?.resolvedPath ?? item.mediaItem?.artworkPath

        // Check if we have cached artwork for this URL
        if let artworkPath, let cachedArtwork = artworkCache[artworkPath] {
            info[MPMediaItemPropertyArtwork] = cachedArtwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load artwork asynchronously if URL changed
        if artworkPath != currentArtworkURL {
            currentArtworkURL = artworkPath
            if let artworkPath {
                Task {
                    await loadArtwork(path: artworkPath)
                }
            }
        }
    }

    private func loadArtwork(path: String) async {
        // Check cache first
        if artworkCache[path] != nil {
            return
        }

        guard let imageURL = resolveImageURL(path: path) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard let image = UIImage(data: data) else { return }

            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }

            // Cache the artwork
            artworkCache[path] = artwork

            // Limit cache size to prevent memory issues
            if artworkCache.count > 50 {
                // Remove oldest entries (this is a simple approach)
                let keysToRemove = Array(artworkCache.keys.prefix(10))
                for key in keysToRemove {
                    artworkCache.removeValue(forKey: key)
                }
            }

            // Update now playing info if this is still the current artwork
            if currentArtworkURL == path {
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        } catch {
            // Silently fail - artwork is optional
            print("Failed to load artwork: \(error)")
        }
    }

    private func resolveImageURL(path: String) -> URL? {
        // If it's already a full URL, use it directly
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }

        // Otherwise, construct URL from base URL
        guard let baseURL else { return nil }

        // Handle paths that start with /
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appendingPathComponent(cleanPath)
    }

    func clearArtworkCache() {
        artworkCache.removeAll()
    }
}
