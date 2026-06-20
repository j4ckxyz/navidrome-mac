import Foundation
import SwiftUI
import Combine

/// Top-level sidebar destinations.
enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case albums
    case artists
    case playlists
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .albums:    return "Albums"
        case .artists:   return "Artists"
        case .playlists: return "Playlists"
        case .search:    return "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .albums:    return "square.stack"
        case .artists:   return "music.mic"
        case .playlists: return "music.note.list"
        case .search:    return "magnifyingglass"
        }
    }
}

/// Albums can be sorted by any of the Subsonic list types.
enum AlbumSort: String, CaseIterable, Identifiable {
    case alphabeticalByName
    case alphabeticalByArtist
    case newest
    case recent
    case frequent
    case starred
    case random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabeticalByName:   return "Name"
        case .alphabeticalByArtist: return "Artist"
        case .newest:               return "Recently Added"
        case .recent:               return "Recently Played"
        case .frequent:             return "Most Played"
        case .starred:              return "Favourites"
        case .random:               return "Random"
        }
    }
}

/// The single source of truth shared across the UI. Owns the network client,
/// the audio engine and the Now Playing bridge, and caches fetched library
/// data.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Services

    let api = NavidromeAPIClient()
    let nowPlaying = NowPlayingManager()
    let engine: AudioPlayerEngine

    // MARK: - Connection

    @Published var serverConfig: ServerConfig?
    @Published var isConnected = false
    @Published var connectionError: String?
    @Published var isConnecting = false

    // MARK: - Navigation

    @Published var selectedSection: LibrarySection? = .albums
    @Published var selectedPlaylistID: String?
    @Published var navigationPath = NavigationPath()

    // MARK: - Library

    @Published var albums: [Album] = []
    @Published var artists: [Artist] = []
    @Published var playlists: [Playlist] = []
    @Published var albumSort: AlbumSort = .alphabeticalByName {
        didSet { Task { await loadAlbums() } }
    }
    @Published var isLoadingLibrary = false
    @Published var libraryError: String?

    // MARK: - Search

    @Published var searchTerm = ""
    @Published var searchResults = NavidromeAPIClient.SearchResults(artists: [], albums: [], songs: [])
    @Published var isSearching = false

    private var searchTask: Task<Void, Never>?
    private let defaultsKey = "NavidromeMac.serverConfig"

    init() {
        self.engine = AudioPlayerEngine(api: api, nowPlaying: nowPlaying)
        engine.attach(nowPlaying: nowPlaying)
    }

    // MARK: - Lifecycle

    /// Restore a saved server configuration (if any) and attempt to connect.
    func bootstrap() async {
        guard let config = loadSavedConfig(),
              let password = KeychainHelper.read(account: config.username) else {
            return
        }
        serverConfig = config
        await connect(config: config, password: password, persist: false)
    }

    /// Authenticate against the server and, on success, load the library.
    func connect(config: ServerConfig, password: String, persist: Bool = true) async {
        isConnecting = true
        connectionError = nil
        await api.configure(config, password: password)

        do {
            try await api.ping()
            isConnected = true
            serverConfig = config
            if persist {
                saveConfig(config)
                KeychainHelper.save(password, account: config.username)
            }
            await loadLibrary()
        } catch {
            isConnected = false
            connectionError = error.localizedDescription
        }
        isConnecting = false
    }

    func disconnect() {
        if let username = serverConfig?.username {
            KeychainHelper.delete(account: username)
        }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        engine.stop()
        isConnected = false
        serverConfig = nil
        albums = []
        artists = []
        playlists = []
    }

    // MARK: - Library loading

    func loadLibrary() async {
        isLoadingLibrary = true
        libraryError = nil
        async let a: Void = loadAlbums()
        async let b: Void = loadArtists()
        async let c: Void = loadPlaylists()
        _ = await (a, b, c)
        isLoadingLibrary = false
    }

    func loadAlbums() async {
        do {
            albums = try await api.getAlbumList(type: albumSort.rawValue, size: 500)
        } catch {
            libraryError = error.localizedDescription
        }
    }

    func loadArtists() async {
        do {
            artists = try await api.getArtists()
        } catch {
            libraryError = error.localizedDescription
        }
    }

    func loadPlaylists() async {
        do {
            playlists = try await api.getPlaylists()
        } catch {
            libraryError = error.localizedDescription
        }
    }

    /// Fetch the full track list for an album (lazily; grid cells only have
    /// metadata).
    func fullAlbum(_ album: Album) async -> Album? {
        do {
            return try await api.getAlbum(id: album.id)
        } catch {
            libraryError = error.localizedDescription
            return nil
        }
    }

    func fullPlaylist(id: String) async -> Playlist? {
        do {
            return try await api.getPlaylist(id: id)
        } catch {
            libraryError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Playback helpers

    /// Resolve and start an album from its first track.
    func playAlbum(_ album: Album, startAt index: Int = 0) {
        Task {
            guard let full = await fullAlbum(album), let songs = full.songs else { return }
            engine.play(tracks: songs, startAt: index)
        }
    }

    func playPlaylist(id: String) {
        Task {
            guard let full = await fullPlaylist(id: id), let songs = full.entries else { return }
            engine.play(tracks: songs, startAt: 0)
        }
    }

    func toggleStar(track: Track) {
        Task { try? await api.setStarred(!track.isStarred, id: track.id) }
    }

    // MARK: - Search

    /// Debounced search invoked as the user types.
    func search(_ term: String) {
        searchTask?.cancel()
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = .init(artists: [], albums: [], songs: [])
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            isSearching = true
            do {
                let results = try await api.search(trimmed)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                libraryError = error.localizedDescription
            }
            isSearching = false
        }
    }

    // MARK: - Cover art

    /// Synchronous best-effort cover URL for use in `AsyncImage`.
    func coverURL(_ coverArt: String?, size: Int = 300) async -> URL? {
        await api.coverArtURL(coverArt, size: size)
    }

    // MARK: - Persistence

    private func saveConfig(_ config: ServerConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func loadSavedConfig() -> ServerConfig? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(ServerConfig.self, from: data)
    }
}
