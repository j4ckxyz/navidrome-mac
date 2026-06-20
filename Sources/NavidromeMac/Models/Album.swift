import Foundation

/// An album as returned by `getAlbumList2` / `getAlbum`.
///
/// When fetched through `getAlbum` the `songs` array is populated; in grid
/// listings (`getAlbumList2`) it is `nil`.
struct Album: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let artist: String?
    let artistId: String?
    let coverArt: String?

    let songCount: Int?
    let duration: Int?      // seconds
    let year: Int?
    let genre: String?
    let created: String?
    var starred: String?

    /// Populated only by `getAlbum`.
    var songs: [Track]?

    enum CodingKeys: String, CodingKey {
        case id, name, artist, artistId, coverArt
        case songCount, duration, year, genre, created, starred
        case songs = "song"
    }

    var isStarred: Bool { starred != nil }

    var subtitle: String {
        var parts: [String] = []
        if let artist { parts.append(artist) }
        if let year { parts.append(String(year)) }
        return parts.joined(separator: " · ")
    }
}
