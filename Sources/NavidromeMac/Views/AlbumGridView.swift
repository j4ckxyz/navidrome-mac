import SwiftUI

/// Scrollable, resizable grid of album covers — the heart of the library view.
struct AlbumGridView: View {
    @EnvironmentObject private var app: AppState

    private let columns = [GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 20)]

    var body: some View {
        Group {
            if app.isLoadingLibrary && app.albums.isEmpty {
                ProgressView("Loading albums…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if app.albums.isEmpty {
                ContentUnavailablePlaceholder(
                    title: "No Albums",
                    systemImage: "square.stack",
                    message: "Your library appears to be empty, or it is still scanning on the server."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(app.albums) { album in
                            AlbumCell(album: album)
                                .onTapGesture { app.navigationPath.append(album) }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .toolbar { sortToolbar }
    }

    @ToolbarContentBuilder
    private var sortToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Picker("Sort", selection: $app.albumSort) {
                ForEach(AlbumSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

/// A single album tile: artwork, hover play affordance, title and subtitle.
struct AlbumCell: View {
    @EnvironmentObject private var app: AppState
    let album: Album

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CoverImage(coverArt: album.coverArt, size: 400, cornerRadius: 12)
                    .aspectRatio(1, contentMode: .fit)

                if isHovering {
                    Button {
                        app.playAlbum(album)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .padding(12)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: .black.opacity(isHovering ? 0.35 : 0.18),
                    radius: isHovering ? 14 : 8, y: 6)
            .scaleEffect(isHovering ? 1.02 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(album.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) { isHovering = hovering }
        }
        .contextMenu {
            Button("Play") { app.playAlbum(album) }
            Button("Show Album") { app.navigationPath.append(album) }
        }
    }
}
