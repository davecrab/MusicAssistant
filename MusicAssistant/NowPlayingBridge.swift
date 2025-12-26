import Foundation
import MediaPlayer
import UIKit

@MainActor
final class NowPlayingBridge {
    private let onPlayPause: () async -> Void
    private let onNext: () async -> Void
    private let onPrevious: () async -> Void

    private var isActive = false

    init(
        onPlayPause: @escaping () async -> Void,
        onNext: @escaping () async -> Void,
        onPrevious: @escaping () async -> Void
    ) {
        self.onPlayPause = onPlayPause
        self.onNext = onNext
        self.onPrevious = onPrevious
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
        } else {
            MPRemoteCommandCenter.shared().togglePlayPauseCommand.removeTarget(nil)
            MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(nil)
            MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(nil)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }

    func update(queue: MAPlayerQueue) {
        guard let item = queue.currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = item.mediaItem?.name ?? item.name
        info[MPMediaItemPropertyArtist] = item.mediaItem?.metadata.artist
        info[MPMediaItemPropertyAlbumTitle] = item.mediaItem?.metadata.album

        if let duration = item.duration {
            info[MPMediaItemPropertyPlaybackDuration] = Double(duration)
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = queue.elapsedTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = (queue.state == .playing) ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

