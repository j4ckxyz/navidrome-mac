import Foundation
import AVFoundation
import Combine

enum RepeatMode: String, CaseIterable {
    case off, all, one

    var systemImage: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

/// AVPlayer-backed streaming engine. Owns the play queue, exposes observable
/// playback state to SwiftUI, and bridges to the system Now Playing /
/// remote-command infrastructure via `NowPlayingManager`.
@MainActor
final class AudioPlayerEngine: ObservableObject {

    // MARK: - Published state

    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex: Int? = nil
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isBuffering = false

    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffled = false
    @Published var volume: Float = 1.0 {
        didSet { player.volume = volume }
    }

    var currentTrack: Track? {
        guard let i = currentIndex, queue.indices.contains(i) else { return nil }
        return queue[i]
    }

    var hasNext: Bool {
        guard let i = currentIndex else { return false }
        return repeatMode != .off || i < queue.count - 1
    }

    var hasPrevious: Bool {
        guard let i = currentIndex else { return false }
        return repeatMode != .off || i > 0
    }

    // MARK: - Private

    private let player = AVPlayer()
    private let api: NavidromeAPIClient
    private weak var nowPlaying: NowPlayingManager?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    /// Original, un-shuffled order so we can restore it when shuffle is toggled.
    private var orderedQueue: [Track] = []

    init(api: NavidromeAPIClient, nowPlaying: NowPlayingManager? = nil) {
        self.api = api
        self.nowPlaying = nowPlaying
        player.volume = volume
        addPeriodicTimeObserver()
    }

    func attach(nowPlaying: NowPlayingManager) {
        self.nowPlaying = nowPlaying
        nowPlaying.bind(engine: self)
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    // MARK: - Queue control

    /// Replace the queue with `tracks` and begin playing at `startIndex`.
    func play(tracks: [Track], startAt startIndex: Int = 0) {
        guard !tracks.isEmpty else { return }
        orderedQueue = tracks
        queue = isShuffled ? shuffled(tracks, keeping: startIndex) : tracks
        let index = isShuffled ? 0 : startIndex
        loadAndPlay(index: index)
    }

    /// Append a single track to the end of the queue.
    func enqueue(_ track: Track) {
        orderedQueue.append(track)
        queue.append(track)
        if currentIndex == nil { loadAndPlay(index: queue.count - 1) }
    }

    func playPauseToggle() {
        guard currentTrack != nil else { return }
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard currentTrack != nil else { return }
        player.play()
        isPlaying = true
        nowPlaying?.updatePlaybackState()
    }

    func pause() {
        player.pause()
        isPlaying = false
        nowPlaying?.updatePlaybackState()
    }

    func next() {
        guard let i = currentIndex else { return }
        if i < queue.count - 1 {
            loadAndPlay(index: i + 1)
        } else if repeatMode == .all {
            loadAndPlay(index: 0)
        } else {
            stop()
        }
    }

    func previous() {
        // Mirror the familiar behaviour: restart the track if we're >3s in,
        // otherwise step backwards.
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard let i = currentIndex else { return }
        if i > 0 {
            loadAndPlay(index: i - 1)
        } else if repeatMode == .all {
            loadAndPlay(index: queue.count - 1)
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = seconds
                self?.nowPlaying?.updatePlaybackState()
            }
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentIndex = nil
        currentTime = 0
        duration = 0
        nowPlaying?.clear()
    }

    func toggleShuffle() {
        isShuffled.toggle()
        guard let current = currentTrack else {
            queue = isShuffled ? orderedQueue.shuffled() : orderedQueue
            return
        }
        if isShuffled {
            queue = shuffled(orderedQueue, pinningFirst: current)
            currentIndex = 0
        } else {
            queue = orderedQueue
            currentIndex = orderedQueue.firstIndex(of: current)
        }
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: - Loading

    private func loadAndPlay(index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        let track = queue[index]
        isBuffering = true

        Task {
            do {
                let url = try await api.streamURL(for: track.id)
                let item = AVPlayerItem(url: url)
                observeEnd(of: item)
                player.replaceCurrentItem(with: item)
                player.play()
                isPlaying = true
                isBuffering = false
                duration = Double(track.duration ?? 0)
                await nowPlaying?.update(track: track, api: api)
                nowPlaying?.updatePlaybackState()
                try? await api.scrobble(id: track.id, submission: false)
            } catch {
                isBuffering = false
                isPlaying = false
            }
        }
    }

    // MARK: - Observation

    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                if let itemDuration = self.player.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
            }
        }
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let track = self.currentTrack {
                    try? await self.api.scrobble(id: track.id, submission: true)
                }
                if self.repeatMode == .one, let i = self.currentIndex {
                    self.loadAndPlay(index: i)
                } else {
                    self.next()
                }
            }
        }
    }

    // MARK: - Shuffle helpers

    private func shuffled(_ tracks: [Track], keeping startIndex: Int) -> [Track] {
        guard tracks.indices.contains(startIndex) else { return tracks.shuffled() }
        return shuffled(tracks, pinningFirst: tracks[startIndex])
    }

    private func shuffled(_ tracks: [Track], pinningFirst pinned: Track) -> [Track] {
        var rest = tracks.filter { $0 != pinned }
        rest.shuffle()
        return [pinned] + rest
    }
}
