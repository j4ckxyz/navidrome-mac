import Foundation

/// An artist from `getArtists` / `getArtist`.
///
/// `getArtist` populates the `albums` array; the indexed listing does not.
struct Artist: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let coverArt: String?
    let artistImageUrl: String?
    let albumCount: Int?
    var starred: String?

    /// Populated only by `getArtist`.
    var albums: [Album]?

    enum CodingKeys: String, CodingKey {
        case id, name, coverArt, artistImageUrl, albumCount, starred
        case albums = "album"
    }

    var isStarred: Bool { starred != nil }
}

/// One alphabetised bucket from `getArtists` (`{ "name": "A", "artist": [...] }`).
struct ArtistIndex: Codable, Equatable, Hashable {
    let name: String
    let artist: [Artist]

    enum CodingKeys: String, CodingKey {
        case name
        case artist
    }
}
