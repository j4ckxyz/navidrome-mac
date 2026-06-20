import SwiftUI

/// Full-window onboarding shown until a server connection is established.
struct ConnectView: View {
    @EnvironmentObject private var app: AppState

    @State private var displayName = "My Navidrome"
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            // Soft accent-tinted gradient backdrop for the glass card to float on.
            LinearGradient(
                colors: [Color.accentColor.opacity(0.35), Color.black.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.white, Color.accentColor)
                    Text("Connect to Navidrome")
                        .font(.largeTitle.weight(.semibold))
                    Text("Enter your server details to stream your library.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    labeledField("Name", text: $displayName, prompt: "My Navidrome")
                    labeledField("Server URL", text: $address, prompt: "https://music.example.com")
                        .textContentType(.URL)
                    labeledField("Username", text: $username, prompt: "username")
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(width: 360)

                if let error = app.connectionError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .frame(width: 360)
                }

                Button {
                    connect()
                } label: {
                    HStack {
                        if app.isConnecting { ProgressView().controlSize(.small) }
                        Text(app.isConnecting ? "Connecting…" : "Connect")
                            .frame(maxWidth: .infinity)
                    }
                    .frame(width: 360)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(!canConnect || app.isConnecting)
            }
            .padding(40)
            .glassPanel(cornerRadius: 28, material: .ultraThinMaterial)
            .frame(maxWidth: 460)
        }
    }

    private var canConnect: Bool {
        !address.isEmpty && !username.isEmpty && !password.isEmpty && URL(string: address) != nil
    }

    private func labeledField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func connect() {
        guard let url = URL(string: address) else { return }
        let config = ServerConfig(displayName: displayName, baseURL: url, username: username)
        Task { await app.connect(config: config, password: password) }
    }
}
