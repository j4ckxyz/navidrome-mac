import Foundation

/// A playlist from `getPlaylists` / `getPlaylist`.
///
/// `getPlaylist` populates `entries` (the Subsonic `entry` array); the listing
/// endpoint returns only metadata.
struct Playlist: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let comment: String?
    let owner: String?
    let `public`: Bool?
    let songCount: Int?
    let duration: Int?
    let created: String?
    let changed: String?
    let coverArt: String?

    /// Populated only by `getPlaylist`.
    var entries: [Track]?

    enum CodingKeys: String, CodingKey {
        case id, name, comment, owner, songCount, duration, created, changed, coverArt
        case `public`
        case entries = "entry"
    }

    var subtitle: String {
        let count = songCount ?? entries?.count ?? 0
        return "\(count) song\(count == 1 ? "" : "s")"
    }
}
