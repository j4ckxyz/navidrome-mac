import Foundation

/// A single playable song returned by the Subsonic API (`getAlbum`,
/// `getPlaylist`, `search3`, …).
///
/// Subsonic returns many optional fields; everything that isn't guaranteed is
/// modelled as optional so decoding never fails on a sparse payload.
struct Track: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let album: String?
    let albumId: String?
    let artist: String?
    let artistId: String?
    let coverArt: String?

    let track: Int?
    let discNumber: Int?
    let year: Int?
    let genre: String?

    let duration: Int?      // seconds
    let bitRate: Int?       // kbps
    let size: Int?          // bytes
    let suffix: String?     // e.g. "flac"
    let contentType: String?
    let path: String?

    var starred: String?    // ISO date string when the song is starred

    enum CodingKeys: String, CodingKey {
        case id, title, album, albumId, artist, artistId, coverArt
        case track, discNumber, year, genre
        case duration, bitRate, size, suffix, contentType, path
        case starred
    }

    /// A user-presentable "m:ss" string for the track length.
    var formattedDuration: String {
        Self.format(seconds: duration ?? 0)
    }

    var isStarred: Bool { starred != nil }

    static func format(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
