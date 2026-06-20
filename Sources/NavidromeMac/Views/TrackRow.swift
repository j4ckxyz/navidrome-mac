import SwiftUI

/// One row in a track listing. Shows the track number (or an animated "playing"
/// indicator for the current track), title/artist, a star toggle and duration.
struct TrackRow: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var engine: AudioPlayerEngine

    let track: Track
    let index: Int
    let isCurrent: Bool
    var showArtist: Bool = false
    let onPlay: () -> Void

    @State private var isHovering = false
    @State private var starred: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Leading number / now-playing indicator.
            ZStack {
                if isCurrent && engine.isPlaying {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.accentColor)
                        .symbolEffectPulse()
                } else if isHovering {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.primary)
                } else {
                    Text("\(index)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(width: 24)
            .font(.callout)

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                if showArtist, let artist = track.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                starred.toggle()
                app.toggleStar(track: track)
            } label: {
                Image(systemName: starred ? "star.fill" : "star")
                    .foregroundStyle(starred ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || starred ? 1 : 0)

            Text(track.formattedDuration)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onPlay)
        .onHover { isHovering = $0 }
        .onAppear { starred = track.isStarred }
        .contextMenu {
            Button("Play") { onPlay() }
            Button("Add to Queue") { engine.enqueue(track) }
            Divider()
            Button(starred ? "Remove Favourite" : "Add to Favourites") {
                starred.toggle()
                app.toggleStar(track: track)
            }
        }
    }
}

// MARK: - Symbol-effect shim

private extension View {
    /// `.symbolEffect(.pulse)` is macOS 14+, but the variant signatures differ
    /// across SDKs; this wrapper keeps call sites tidy and degrades gracefully.
    @ViewBuilder
    func symbolEffectPulse() -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.pulse, options: .repeating)
        } else {
            self
        }
    }
}
