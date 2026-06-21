import SwiftUI

/// Grid/list of the user's playlists shown for the Playlists section.
struct PlaylistListView: View {
    @EnvironmentObject private var app: AppState

    private let columns = [GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 20)]

    var body: some View {
        Group {
            if app.isLoadingLibrary && app.playlists.isEmpty {
                ProgressView("Loading playlists…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if app.playlists.isEmpty {
                ContentUnavailablePlaceholder(
                    title: "No Playlists",
                    systemImage: "music.note.list",
                    message: "Create a playlist in Navidrome and it will appear here."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(app.playlists) { playlist in
                            PlaylistCell(playlist: playlist)
                                .onTapGesture { app.navigationPath.append(playlist) }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

struct PlaylistCell: View {
    @EnvironmentObject private var app: AppState
    let playlist: Playlist
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CoverImage(coverArt: playlist.coverArt, size: 400, cornerRadius: 12)
                    .aspectRatio(1, contentMode: .fit)
                if isHovering {
                    Button {
                        app.playPlaylist(id: playlist.id)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .padding(12)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
            }
            .shadow(color: .black.opacity(isHovering ? 0.3 : 0.15),
                    radius: isHovering ? 12 : 6, y: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(playlist.subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) { isHovering = hovering }
        }
    }
}

/// Playlist page with the full ordered track list.
struct PlaylistDetailView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var engine: AudioPlayerEngine

    let playlist: Playlist
    @State private var loaded: Playlist?
    @State private var isLoading = true

    private var songs: [Track] { loaded?.entries ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom, spacing: 24) {
                    CoverImage(coverArt: playlist.coverArt, size: 600, cornerRadius: 16)
                        .frame(width: 200, height: 200)
                        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(playlist.name).font(.largeTitle.weight(.bold)).lineLimit(2)
                        if let comment = playlist.comment, !comment.isEmpty {
                            Text(comment).foregroundStyle(.secondary)
                        }
                        Text(playlist.subtitle).font(.callout).foregroundStyle(.tertiary)

                        HStack(spacing: 12) {
                            Button {
                                engine.play(tracks: songs, startAt: 0)
                            } label: {
                                Label("Play", systemImage: "play.fill").frame(minWidth: 90)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(songs.isEmpty)

                            Button {
                                if !engine.isShuffled { engine.toggleShuffle() }
                                engine.play(tracks: songs, startAt: 0)
                            } label: {
                                Label("Shuffle", systemImage: "shuffle").frame(minWidth: 90)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(songs.isEmpty)
                        }
                        .padding(.top, 6)
                    }
                    Spacer()
                }

                Divider()

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.offset) { index, track in
                            TrackRow(
                                track: track,
                                index: index + 1,
                                isCurrent: engine.currentTrack?.id == track.id,
                                showArtist: true
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
            .padding(24)
        }
        .navigationTitle(playlist.name)
        .task {
            loaded = await app.fullPlaylist(id: playlist.id)
            isLoading = false
        }
    }
}
