import Foundation
import CryptoKit

/// Errors surfaced by the network layer.
enum NavidromeError: LocalizedError {
    case notConfigured
    case invalidURL
    case badResponse(Int)
    case server(SubsonicError)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:    return "No server configured. Open Settings (⌘,) to connect."
        case .invalidURL:       return "The server address is not a valid URL."
        case .badResponse(let c): return "Unexpected HTTP status \(c) from the server."
        case .server(let e):    return e.errorDescription
        case .decoding(let e):  return "Could not read the server response: \(e.localizedDescription)"
        case .transport(let e): return e.localizedDescription
        }
    }
}

/// Async URLSession-based client for the Subsonic REST API exposed by
/// Navidrome. Authentication uses the salted-token scheme: each request sends a
/// random `salt` and `token = md5(password + salt)` so the password is never
/// transmitted.
actor NavidromeAPIClient {
    private var config: ServerConfig?
    private var password: String?

    private let session: URLSession
    private let decoder = JSONDecoder()

    /// Subsonic protocol version this client advertises.
    private let apiVersion = "1.16.1"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Configuration

    func configure(_ config: ServerConfig, password: String) {
        self.config = config
        self.password = password
    }

    func isConfigured() -> Bool { config != nil && password != nil }

    // MARK: - Request building

    /// Build a fully-authenticated URL for the given Subsonic endpoint.
    private func makeURL(endpoint: String, query: [URLQueryItem] = []) throws -> URL {
        guard let config, let password else { throw NavidromeError.notConfigured }

        let salt = Self.randomSalt()
        let token = Self.md5(password + salt)

        var components = URLComponents(
            url: config.baseURL.appendingPathComponent("rest").appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )
        guard components != nil else { throw NavidromeError.invalidURL }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: apiVersion),
            URLQueryItem(name: "c", value: config.clientName),
            URLQueryItem(name: "f", value: "json")
        ]
        items.append(contentsOf: query)
        components?.queryItems = items

        guard let url = components?.url else { throw NavidromeError.invalidURL }
        return url
    }

    /// Build a streaming/cover-art URL (returned to callers, not fetched here).
    /// These reuse the salted-token credentials so AVPlayer / AsyncImage can hit
    /// them directly.
    func mediaURL(endpoint: String, query: [URLQueryItem]) throws -> URL {
        try makeURL(endpoint: endpoint, query: query)
    }

    // MARK: - Generic GET + decode

    private func get<Container: Decodable>(
        _ endpoint: String,
        query: [URLQueryItem] = [],
        as type: Container.Type
    ) async throws -> Container {
        let url = try makeURL(endpoint: endpoint, query: query)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw NavidromeError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NavidromeError.badResponse(http.statusCode)
        }

        // Surface a Subsonic-level failure before attempting to decode the body.
        if let status = try? decoder.decode(SubsonicStatus.self, from: data),
           !status.isOK, let error = status.error {
            throw NavidromeError.server(error)
        }

        do {
            let envelope = try decoder.decode(SubsonicEnvelope<Container>.self, from: data)
            return envelope.response
        } catch {
            throw NavidromeError.decoding(error)
        }
    }

    // MARK: - Endpoints

    /// Validate credentials. Throws on failure.
    func ping() async throws {
        let container = try await get("ping", as: PingContainer.self)
        if container.status != "ok", let error = container.error {
            throw NavidromeError.server(error)
        }
    }

    func getArtists() async throws -> [Artist] {
        let container = try await get("getArtists", as: ArtistsContainer.self)
        let indexes = container.artists?.index ?? []
        return indexes.flatMap { $0.artist }
    }

    func getArtist(id: String) async throws -> Artist? {
        let container = try await get(
            "getArtist",
            query: [URLQueryItem(name: "id", value: id)],
            as: ArtistContainer.self
        )
        return container.artist
    }

    /// `type` is a Subsonic list type: newest, recent, frequent, random,
    /// alphabeticalByName, alphabeticalByArtist, starred, …
    func getAlbumList(
        type: String = "alphabeticalByName",
        size: Int = 500,
        offset: Int = 0
    ) async throws -> [Album] {
        let container = try await get(
            "getAlbumList2",
            query: [
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "size", value: String(size)),
                URLQueryItem(name: "offset", value: String(offset))
            ],
            as: AlbumListContainer.self
        )
        return container.albumList2?.album ?? []
    }

    func getAlbum(id: String) async throws -> Album? {
        let container = try await get(
            "getAlbum",
            query: [URLQueryItem(name: "id", value: id)],
            as: AlbumContainer.self
        )
        return container.album
    }

    func getPlaylists() async throws -> [Playlist] {
        let container = try await get("getPlaylists", as: PlaylistsContainer.self)
        return container.playlists?.playlist ?? []
    }

    func getPlaylist(id: String) async throws -> Playlist? {
        let container = try await get(
            "getPlaylist",
            query: [URLQueryItem(name: "id", value: id)],
            as: PlaylistContainer.self
        )
        return container.playlist
    }

    struct SearchResults {
        var artists: [Artist]
        var albums: [Album]
        var songs: [Track]
    }

    func search(_ term: String) async throws -> SearchResults {
        let container = try await get(
            "search3",
            query: [
                URLQueryItem(name: "query", value: term),
                URLQueryItem(name: "artistCount", value: "20"),
                URLQueryItem(name: "albumCount", value: "40"),
                URLQueryItem(name: "songCount", value: "60")
            ],
            as: SearchContainer.self
        )
        return SearchResults(
            artists: container.searchResult3?.artist ?? [],
            albums: container.searchResult3?.album ?? [],
            songs: container.searchResult3?.song ?? []
        )
    }

    /// Toggle the "starred" flag for a song, album, or artist.
    func setStarred(_ starred: Bool, id: String) async throws {
        let endpoint = starred ? "star" : "unstar"
        _ = try await get(endpoint, query: [URLQueryItem(name: "id", value: id)], as: PingContainer.self)
    }

    /// Report a play to the server so Navidrome updates play counts / "recently
    /// played" and any connected Last.fm scrobbling.
    func scrobble(id: String, submission: Bool = true) async throws {
        _ = try await get(
            "scrobble",
            query: [
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "submission", value: submission ? "true" : "false")
            ],
            as: PingContainer.self
        )
    }

    // MARK: - URLs handed to AVPlayer / AsyncImage

    func streamURL(for trackID: String) throws -> URL {
        try makeURL(endpoint: "stream", query: [URLQueryItem(name: "id", value: trackID)])
    }

    /// Cover-art URL sized for retina display. `coverArt` is the opaque id from
    /// an album/track (may be `nil`).
    func coverArtURL(_ coverArt: String?, size: Int = 600) -> URL? {
        guard let coverArt else { return nil }
        return try? makeURL(
            endpoint: "getCoverArt",
            query: [
                URLQueryItem(name: "id", value: coverArt),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
    }

    // MARK: - Crypto helpers

    private static func randomSalt(length: Int = 12) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    private static func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
