import SwiftUI

/// Native translucent sidebar listing the library sections and the user's
/// playlists. Uses the system sidebar material for the Tahoe glass look.
struct SidebarView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        List(selection: $app.selectedSection) {
            Section("Library") {
                ForEach(LibrarySection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }

            if !app.playlists.isEmpty {
                Section("Playlists") {
                    ForEach(app.playlists) { playlist in
                        Button {
                            app.navigationPath.append(playlist)
                        } label: {
                            Label(playlist.name, systemImage: "music.note.list")
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .safeAreaInset(edge: .bottom) {
            if let config = app.serverConfig {
                serverFooter(config)
            }
        }
    }

    private func serverFooter(_ config: ServerConfig) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(app.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(config.displayName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(config.username)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
