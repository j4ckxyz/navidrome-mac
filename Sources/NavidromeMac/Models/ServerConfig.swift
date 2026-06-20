import Foundation

/// Connection details for a Navidrome / Subsonic compatible server.
///
/// The password is never persisted in plaintext alongside this struct — the
/// `NavidromeAPIClient` derives a per-request salted token (the Subsonic
/// "token + salt" auth scheme) so the raw password only lives in the Keychain.
struct ServerConfig: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    /// Base URL of the server, e.g. `https://music.example.com`.
    var baseURL: URL
    var username: String

    /// The client identifier reported to the server (shows up in Navidrome's
    /// active-clients list).
    var clientName: String

    init(
        id: UUID = UUID(),
        displayName: String,
        baseURL: URL,
        username: String,
        clientName: String = "NavidromeMac"
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.username = username
        self.clientName = clientName
    }
}

extension ServerConfig {
    /// A placeholder used before the user has configured a real server.
    static let empty = ServerConfig(
        displayName: "",
        baseURL: URL(string: "https://demo.navidrome.org")!,
        username: ""
    )
}
