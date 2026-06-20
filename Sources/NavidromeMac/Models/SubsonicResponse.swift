import Foundation

/// Every Subsonic JSON payload is wrapped in a top-level `"subsonic-response"`
/// object. `SubsonicEnvelope` decodes that wrapper; the concrete `Body` carries
/// whatever endpoint-specific container we expect.
struct SubsonicEnvelope<Body: Decodable>: Decodable {
    let response: Body

    enum CodingKeys: String, CodingKey {
        case response = "subsonic-response"
    }
}

/// Fields common to *every* `subsonic-response`. Decoded first so that an API
/// error (`status == "failed"`) can be surfaced before attempting to read the
/// endpoint payload.
struct SubsonicStatus: Decodable {
    struct Inner: Decodable {
        let status: String
        let version: String?
        let error: SubsonicError?
    }

    let inner: Inner

    enum CodingKeys: String, CodingKey {
        case inner = "subsonic-response"
    }

    var isOK: Bool { inner.status == "ok" }
    var error: SubsonicError? { inner.error }
}

/// The Subsonic error sub-object (`{ "code": 40, "message": "..." }`).
struct SubsonicError: Decodable, Error, LocalizedError {
    let code: Int
    let message: String?

    var errorDescription: String? {
        if let message { return "Server error \(code): \(message)" }
        return "Server error \(code)"
    }
}

// MARK: - Endpoint payload containers

struct PingContainer: Decodable {
    let status: String
    let version: String?
    let type: String?
    let serverVersion: String?
    let error: SubsonicError?
}

struct ArtistsContainer: Decodable {
    struct Artists: Decodable {
        let index: [ArtistIndex]?
    }
    let status: String
    let artists: Artists?
    let error: SubsonicError?
}

struct ArtistContainer: Decodable {
    let status: String
    let artist: Artist?
    let error: SubsonicError?
}

struct AlbumListContainer: Decodable {
    struct AlbumList2: Decodable {
        let album: [Album]?
    }
    let status: String
    let albumList2: AlbumList2?
    let error: SubsonicError?
}

struct AlbumContainer: Decodable {
    let status: String
    let album: Album?
    let error: SubsonicError?
}

struct PlaylistsContainer: Decodable {
    struct Playlists: Decodable {
        let playlist: [Playlist]?
    }
    let status: String
    let playlists: Playlists?
    let error: SubsonicError?
}

struct PlaylistContainer: Decodable {
    let status: String
    let playlist: Playlist?
    let error: SubsonicError?
}

struct SearchContainer: Decodable {
    struct SearchResult3: Decodable {
        let artist: [Artist]?
        let album: [Album]?
        let song: [Track]?
    }
    let status: String
    let searchResult3: SearchResult3?
    let error: SubsonicError?
}
