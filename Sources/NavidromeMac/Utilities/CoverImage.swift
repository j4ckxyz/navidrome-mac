import SwiftUI

/// Loads cover art for a Subsonic `coverArt` id. Because the authenticated URL
/// is produced by the `NavidromeAPIClient` actor, the URL is resolved
/// asynchronously and then handed to `AsyncImage` for fetching + caching.
struct CoverImage: View {
    @EnvironmentObject private var app: AppState

    let coverArt: String?
    var size: Int = 300
    var cornerRadius: CGFloat = 10

    @State private var url: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.quaternary)

            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: coverArt) {
            url = await app.coverURL(coverArt, size: size)
        }
    }

    private var placeholder: some View {
        Image(systemName: "music.note")
            .font(.system(size: CGFloat(size) / 6, weight: .light))
            .foregroundStyle(.secondary)
    }
}
