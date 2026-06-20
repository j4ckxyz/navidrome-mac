import SwiftUI

/// Preferences pane (⌘,). Lets the user review the active server, re-test the
/// connection, tune playback defaults, and sign out.
struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var engine: AudioPlayerEngine

    var body: some View {
        TabView {
            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }

            playbackTab
                .tabItem { Label("Playback", systemImage: "speaker.wave.2") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
    }

    // MARK: - Server

    private var serverTab: some View {
        Form {
            Section("Connection") {
                if let config = app.serverConfig {
                    LabeledContent("Name", value: config.displayName)
                    LabeledContent("Server", value: config.baseURL.absoluteString)
                    LabeledContent("Username", value: config.username)
                    LabeledContent("Status") {
                        Label(
                            app.isConnected ? "Connected" : "Disconnected",
                            systemImage: app.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(app.isConnected ? .green : .red)
                    }
                } else {
                    Text("Not configured. Use the connect screen to add a server.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Button("Refresh Library") {
                        Task { await app.loadLibrary() }
                    }
                    .disabled(!app.isConnected)

                    Spacer()

                    Button("Sign Out", role: .destructive) {
                        app.disconnect()
                    }
                    .disabled(app.serverConfig == nil)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Playback

    private var playbackTab: some View {
        Form {
            Section("Defaults") {
                Picker("Default Album Sort", selection: $app.albumSort) {
                    ForEach(AlbumSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }

                Toggle("Shuffle new queues", isOn: $engine.isShuffled)

                Picker("Repeat", selection: $engine.repeatMode) {
                    Text("Off").tag(RepeatMode.off)
                    Text("All").tag(RepeatMode.all)
                    Text("One").tag(RepeatMode.one)
                }
            }

            Section("Volume") {
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: $engine.volume, in: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.white, Color.accentColor)
            Text("NavidromeMac")
                .font(.title2.weight(.semibold))
            Text("A native macOS client for Navidrome / Subsonic.")
                .foregroundStyle(.secondary)
            Text("Built with SwiftUI for macOS 26 Tahoe.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
