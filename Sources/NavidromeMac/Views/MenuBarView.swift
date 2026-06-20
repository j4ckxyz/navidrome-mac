import SwiftUI
import AppKit

/// Compact transport surfaced from the macOS menu bar (`MenuBarExtra`). Mirrors
/// the main player so the user can control playback without raising the window.
struct MenuBarView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var engine: AudioPlayerEngine

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            transport
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 280)
    }

    private var header: some View {
        HStack(spacing: 12) {
            CoverImage(coverArt: engine.currentTrack?.coverArt, size: 120, cornerRadius: 8)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.currentTrack?.title ?? "Not Playing")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(engine.currentTrack?.artist ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let album = engine.currentTrack?.album {
                    Text(album)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Spacer()
            Button { engine.previous() } label: {
                Image(systemName: "backward.fill")
            }
            .disabled(!engine.hasPrevious)

            Button { engine.playPauseToggle() } label: {
                Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
            }
            .disabled(engine.currentTrack == nil)

            Button { engine.next() } label: {
                Image(systemName: "forward.fill")
            }
            .disabled(!engine.hasNext)
            Spacer()
        }
        .buttonStyle(.plain)
        .font(.title3)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Button { engine.toggleShuffle() } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .foregroundStyle(engine.isShuffled ? Color.accentColor : .primary)
                }
                Spacer()
                Button { engine.cycleRepeatMode() } label: {
                    Label("Repeat", systemImage: engine.repeatMode.systemImage)
                        .foregroundStyle(engine.repeatMode == .off ? .primary : Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .font(.callout)

            Divider()

            HStack {
                Button("Open NavidromeMac") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .font(.callout)
        }
    }
}
