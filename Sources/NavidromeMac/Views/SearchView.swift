import SwiftUI

/// Unified search across artists, albums and songs (Subsonic `search3`).
struct SearchView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var engine: AudioPlayerEngine
    @FocusState private var fieldFocused: Bool

    private let albumColumns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 18)]

    private var results: NavidromeAPIClient.SearchResults { app.searchResults }
    private var isEmptyQuery: Bool {
        app.searchTerm.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
        }
        .onAppear { fieldFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search artists, albums, songs…", text: $app.searchTerm)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldFocused)
                .onChange(of: app.searchTerm) { _, newValue in
                    app.search(newValue)
                }
            if app.isSearching { ProgressView().controlSize(.small) }
            if !isEmptyQuery {
                Button {
                    app.searchTerm = ""
                    app.search("")
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var content: some View {
        if isEmptyQuery {
            ContentUnavailablePlaceholder(
                title: "Search Your Library",
                systemImage: "magnifyingglass",
                message: "Find any artist, album, or song on your server."
            )
        } else if results.artists.isEmpty && results.albums.isEmpty && results.songs.isEmpty && !app.isSearching {
            ContentUnavailablePlaceholder(
                title: "No Results",
                systemImage: "questionmark.circle",
                message: "Nothing matched “\(app.searchTerm)”."
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !results.artists.isEmpty { artistSection }
                    if !results.albums.isEmpty { albumSection }
                    if !results.songs.isEmpty { songSection }
                }
                .padding(24)
            }
        }
    }

    private var artistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Artists").font(.title2.weight(.bold))
            LazyVGrid(columns: albumColumns, spacing: 20) {
                ForEach(results.artists) { artist in
                    ArtistCell(artist: artist)
                        .onTapGesture { app.navigationPath.append(artist) }
                }
            }
        }
    }

    private var albumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Albums").font(.title2.weight(.bold))
            LazyVGrid(columns: albumColumns, spacing: 20) {
                ForEach(results.albums) { album in
                    AlbumCell(album: album)
                        .onTapGesture { app.navigationPath.append(album) }
                }
            }
        }
    }

    private var songSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Songs").font(.title2.weight(.bold))
            VStack(spacing: 0) {
                ForEach(Array(results.songs.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        index: index + 1,
                        isCurrent: engine.currentTrack?.id == track.id,
                        showArtist: true
                    ) {
                        engine.play(tracks: results.songs, startAt: index)
                    }
                    if index < results.songs.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .glassCard(cornerRadius: 12)
        }
    }
}
