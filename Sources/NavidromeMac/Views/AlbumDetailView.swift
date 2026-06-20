import SwiftUI

/// Detailed album page: large artwork header, transport buttons and a numbered
/// track list. Tracks are fetched lazily on appearance.
struct AlbumDetailView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var engine: AudioPlayerEngine

    let album: Album
    @State private var loaded: Album?
    @State private var isLoading = true

    private var songs: [Track] { loaded?.songs ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                trackList
            }
            .padding(24)
        }
        .navigationTitle(album.name)
        .task {
            loaded = await app.fullAlbum(album)
            isLoading = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 24) {
            CoverImage(coverArt: album.coverArt, size: 600, cornerRadius: 16)
                .frame(width: 220, height: 220)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

            VStack(alignment: .leading, spacing: 8) {
                Text(album.name)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)

                if let artist = album.artist {
                    Text(artist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text(metadataLine)
                    .font(.callout)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 12) {
                    Button {
                        engine.play(tracks: songs, startAt: 0)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(minWidth: 90)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(songs.isEmpty)

                    Button {
                        if !engine.isShuffled { engine.toggleShuffle() }
                        engine.play(tracks: songs, startAt: 0)
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(minWidth: 90)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(songs.isEmpty)
                }
                .padding(.top, 6)
            }
            Spacer()
        }
    }

    private var metadataLine: String {
        var parts: [String] = []
        if let year = album.year { parts.append(String(year)) }
        if let genre = album.genre, !genre.isEmpty { parts.append(genre) }
        let count = album.songCount ?? songs.count
        parts.append("\(count) song\(count == 1 ? "" : "s")")
        return parts.joined(separator: " · ")
    }

    // MARK: - Tracks

    @ViewBuilder
    private var trackList: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity).padding()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        index: index + 1,
                        isCurrent: engine.currentTrack?.id == track.id
                    ) {
                        engine.play(tracks: songs, startAt: index)
                    }
                    if index < songs.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .glassCard(cornerRadius: 12)
        }
    }
}
