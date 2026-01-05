import AVFoundation
import Combine
import Foundation

final class LocalPlaybackManager: ObservableObject {
    @Published private(set) var playbackState: MAPlaybackState = .idle
    @Published private(set) var elapsedTime: Double = 0
    @Published private(set) var duration: Double?

    var onItemFinished: (() -> Void)?

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var cancellables: Set<AnyCancellable> = []

    deinit {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }

    func play(url: URL, startPosition: Double? = nil) {
        do {
            try configureAudioSession()
        } catch {
            print("Failed to configure audio session: \(error)")
        }

        removeTimeObserver()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        let avPlayer = AVPlayer(playerItem: item)
        player = avPlayer
        addTimeObserver(to: avPlayer)

        if let startPosition {
            seek(to: startPosition)
        }

        avPlayer.play()
        DispatchQueue.main.async { [weak self] in
            self?.playbackState = .playing
        }

        item.publisher(for: \.duration)
            .sink { [weak self] time in
                guard let self else { return }
                if time.isIndefinite || time.isNegativeInfinity || time.isPositiveInfinity {
                    DispatchQueue.main.async { self.duration = nil }
                } else {
                    let dur = time.seconds.isFinite ? time.seconds : nil
                    DispatchQueue.main.async { self.duration = dur }
                }
            }
            .store(in: &cancellables)
    }

    func play() {
        guard let player else { return }
        player.play()
        DispatchQueue.main.async { [weak self] in self?.playbackState = .playing }
    }

    func pause() {
        guard let player else { return }
        player.pause()
        DispatchQueue.main.async { [weak self] in self?.playbackState = .paused }
    }

    func stop() {
        player?.pause()
        player = nil
        removeTimeObserver()
        DispatchQueue.main.async { [weak self] in
            self?.playbackState = .idle
            self?.elapsedTime = 0
            self?.duration = nil
        }
    }

    func togglePlayPause() {
        switch playbackState {
        case .playing:
            pause()
        case .paused:
            play()
        case .idle, .unknown:
            break
        }
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 1_000)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        DispatchQueue.main.async { [weak self] in self?.elapsedTime = seconds }
    }

    private func addTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 2)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if seconds.isFinite {
                self.elapsedTime = seconds
            }
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken, let player {
            player.removeTimeObserver(token)
        }
        timeObserverToken = nil
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true, options: [])
    }

    @objc
    private func playerItemDidFinish() {
        DispatchQueue.main.async { [weak self] in
            self?.playbackState = .paused
            self?.onItemFinished?()
        }
    }
}
