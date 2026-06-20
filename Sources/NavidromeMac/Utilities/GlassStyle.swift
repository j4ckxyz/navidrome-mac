import SwiftUI

/// Reusable "Liquid Glass" surface treatments for macOS 26 Tahoe.
///
/// We lean on SwiftUI's system materials (`.ultraThinMaterial`, etc.) which the
/// compositor renders with Tahoe's translucent, light-reactive glass look.
/// These are deliberately SDK-agnostic so the project also builds on macOS 14+.
/// On Tahoe you can additionally layer the native `.glassEffect(...)` modifier
/// at call sites where you want the reflective specular highlight.
extension View {

    /// A floating, rounded glass panel — used by the player bar and pop-overs.
    func glassPanel(cornerRadius: CGFloat = 20, material: Material = .ultraThinMaterial) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }

    /// A subtle inset card used for grid cells on hover.
    func glassCard(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
    }
}
