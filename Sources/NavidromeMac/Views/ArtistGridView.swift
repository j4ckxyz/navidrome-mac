import SwiftUI

/// Grid of artists with circular artwork.
struct ArtistGridView: View {
    @EnvironmentObject private var app: AppState

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)]

    var body: some View {
        Group {
            if app.isLoadingLibrary && app.artists.isEmpty {
                ProgressView("Loading artists…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if app.artists.isEmpty {
                ContentUnavailablePlaceholder(
                    title: "No Artists",
                    systemImage: "music.mic",
                    message: "No artists were found in your library."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(app.artists) { artist in
                            ArtistCell(artist: artist)
                                .onTapGesture { app.navigationPath.append(artist) }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

struct ArtistCell: View {
    let artist: Artist
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 10) {
            CoverImage(coverArt: artist.coverArt, size: 400, cornerRadius: 200)
                .frame(width: 130, height: 130)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(isHovering ? 0.3 : 0.15),
                        radius: isHovering ? 12 : 6, y: 4)
                .scaleEffect(isHovering ? 1.03 : 1.0)

            VStack(spacing: 2) {
                Text(artist.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let count = artist.albumCount {
                    Text("\(count) album\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) { isHovering = hovering }
        }
    }
}

/// Artist page: header plus a grid of the artist's albums.
struct ArtistDetailView: View {
    @EnvironmentObject private var app: AppState

    let artist: Artist
    @State private var loaded: Artist?
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 20)]
    private var albums: [Album] { loaded?.albums ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20) {
                    CoverImage(coverArt: artist.coverArt, size: 400, cornerRadius: 200)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 6) {
                        Text(artist.name).font(.largeTitle.weight(.bold))
                        Text("\(albums.count) album\(albums.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(albums) { album in
                            AlbumCell(album: album)
                                .onTapGesture { app.navigationPath.append(album) }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(artist.name)
        .task {
            loaded = await app.api.getArtistSafe(id: artist.id)
            isLoading = false
        }
    }
}

private extension NavidromeAPIClient {
    /// Non-throwing convenience used by the artist page.
    func getArtistSafe(id: String) async -> Artist? {
        try? await getArtist(id: id)
    }
}
