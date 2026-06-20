import SwiftUI

/// The primary three-region layout: translucent sidebar, content area, and a
/// floating glass player bar pinned to the bottom of the window.
struct MainSplitView: View {
    @EnvironmentObject private var app: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
            } detail: {
                NavigationStack(path: $app.navigationPath) {
                    detailContent
                        .navigationDestination(for: Album.self) { album in
                            AlbumDetailView(album: album)
                        }
                        .navigationDestination(for: Artist.self) { artist in
                            ArtistDetailView(artist: artist)
                        }
                        .navigationDestination(for: Playlist.self) { playlist in
                            PlaylistDetailView(playlist: playlist)
                        }
                }
                // Reserve space so the floating bar never covers content.
                .safeAreaPadding(.bottom, 96)
            }
            .navigationTitle(app.selectedSection?.title ?? "NavidromeMac")

            PlayerControlBar()
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch app.selectedSection {
        case .albums:
            AlbumGridView()
        case .artists:
            ArtistGridView()
        case .playlists:
            PlaylistListView()
        case .search:
            SearchView()
        case .none:
            ContentUnavailablePlaceholder(
                title: "Select a Section",
                systemImage: "sidebar.left",
                message: "Choose a library section from the sidebar."
            )
        }
    }
}

/// Lightweight stand-in for `ContentUnavailableView` that also compiles on
/// macOS 14 (where the system view's availability differs).
struct ContentUnavailablePlaceholder: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
