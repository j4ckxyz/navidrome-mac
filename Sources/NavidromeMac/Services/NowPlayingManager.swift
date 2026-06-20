import Foundation
import MediaPlayer
import AppKit

/// Bridges the audio engine to the system: populates Control Centre / the Now
/// Playing widget (`MPNowPlayingInfoCenter`) and wires the hardware media keys
/// and Control Centre transport buttons (`MPRemoteCommandCenter`).
@MainActor
final class NowPlayingManager: ObservableObject {

    private weak var engine: AudioPlayerEngine?
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private var artworkCache: [String: MPMediaItemArtwork] = [:]

    init() {
        configureRemoteCommands()
    }

    /// Called once by the engine after construction to close the reference loop.
    func bind(engine: AudioPlayerEngine) {
        self.engine = engine
    }

    // MARK: - Remote command centre (media keys + Control Centre)

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // Handlers may fire on a background thread, so each one hops back to the
        // main actor before touching the (@MainActor) audio engine.
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.engine?.resume() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.engine?.pause() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.engine?.playPauseToggle() }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.engine?.next() }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.engine?.previous() }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.engine?.seek(to: event.positionTime) }
            return .success
        }
    }

    // MARK: - Now Playing info

    /// Push static metadata for a newly-started track, loading artwork async.
    func update(track: Track, api: NavidromeAPIClient) async {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist ?? "",
            MPMediaItemPropertyAlbumTitle: track.album ?? "",
            MPMediaItemPropertyPlaybackDuration: Double(track.duration ?? 0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0
        ]
        if let artwork = await loadArtwork(for: track, api: api) {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = .playing
    }

    /// Refresh the dynamic fields (elapsed time, play/pause, rate) without
    /// rebuilding artwork.
    func updatePlaybackState() {
        guard let engine else { return }
        var info = infoCenter.nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = engine.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = engine.isPlaying ? 1.0 : 0.0
        info[MPMediaItemPropertyPlaybackDuration] = engine.duration
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = engine.isPlaying ? .playing : .paused
    }

    func clear() {
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
    }

    // MARK: - Artwork

    private func loadArtwork(for track: Track, api: NavidromeAPIClient) async -> MPMediaItemArtwork? {
        guard let coverArt = track.coverArt else { return nil }
        if let cached = artworkCache[coverArt] { return cached }
        guard let url = await api.coverArtURL(coverArt, size: 600) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data) else { return nil }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            artworkCache[coverArt] = artwork
            return artwork
        } catch {
            return nil
        }
    }
}
