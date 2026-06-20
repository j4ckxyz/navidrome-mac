import SwiftUI

/// The persistent, floating glass transport bar pinned to the bottom of the
/// window. Reflects and drives `AudioPlayerEngine`.
struct PlayerControlBar: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var engine: AudioPlayerEngine

    /// Local scrubbing state so dragging the slider doesn't fight the periodic
    /// time observer until the user lets go.
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        HStack(spacing: 16) {
            nowPlayingInfo
                .frame(width: 240, alignment: .leading)

            transportControls

            scrubber

            secondaryControls
                .frame(width: 200, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 22)
        .frame(maxWidth: 1100)
        .opacity(engine.currentTrack == nil ? 0.92 : 1)
    }

    // MARK: - Now playing (left)

    private var nowPlayingInfo: some View {
        HStack(spacing: 12) {
            CoverImage(coverArt: engine.currentTrack?.coverArt, size: 120, cornerRadius: 8)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.currentTrack?.title ?? "Not Playing")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(engine.currentTrack?.artist ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Transport (center)

    private var transportControls: some View {
        HStack(spacing: 18) {
            Button { engine.previous() } label: {
                Image(systemName: "backward.fill")
            }
            .disabled(!engine.hasPrevious)

            Button { engine.playPauseToggle() } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial, in: Circle())
            }
            .disabled(engine.currentTrack == nil)

            Button { engine.next() } label: {
                Image(systemName: "forward.fill")
            }
            .disabled(!engine.hasNext)
        }
        .buttonStyle(.plain)
        .font(.title3)
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        HStack(spacing: 8) {
            Text(Track.format(seconds: Int(displayedTime)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : engine.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(engine.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubValue = engine.currentTime
                    } else {
                        engine.seek(to: scrubValue)
                        isScrubbing = false
                    }
                }
            )
            .controlSize(.small)
            .disabled(engine.currentTrack == nil)

            Text(Track.format(seconds: Int(engine.duration)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
        .frame(minWidth: 220)
    }

    private var displayedTime: Double {
        isScrubbing ? scrubValue : engine.currentTime
    }

    // MARK: - Secondary controls (right)

    private var secondaryControls: some View {
        HStack(spacing: 14) {
            Button { engine.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(engine.isShuffled ? Color.accentColor : .secondary)
            }

            Button { engine.cycleRepeatMode() } label: {
                Image(systemName: engine.repeatMode.systemImage)
                    .foregroundStyle(engine.repeatMode == .off ? .secondary : Color.accentColor)
            }

            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $engine.volume, in: 0...1)
                    .controlSize(.mini)
                    .frame(width: 70)
            }
        }
        .buttonStyle(.plain)
    }
}
