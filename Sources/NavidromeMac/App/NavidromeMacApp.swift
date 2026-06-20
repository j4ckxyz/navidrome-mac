import SwiftUI

@main
struct NavidromeMacApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        // MARK: Main window
        WindowGroup(id: "main") {
            RootView()
                .environmentObject(app)
                .environmentObject(app.engine)
                .frame(minWidth: 960, minHeight: 640)
                .task { await app.bootstrap() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands { PlaybackCommands(app: app, engine: app.engine) }

        // MARK: Settings (⌘,)
        Settings {
            SettingsView()
                .environmentObject(app)
                .environmentObject(app.engine)
                .frame(width: 520, height: 460)
        }

        // MARK: Menu bar extra — quick transport from the Tahoe menu bar
        MenuBarExtra {
            MenuBarView()
                .environmentObject(app)
                .environmentObject(app.engine)
        } label: {
            Image(systemName: app.engine.isPlaying ? "waveform" : "music.note")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Root container that switches between the connect/onboarding flow and the
/// full library UI depending on connection state.
struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Group {
            if app.isConnected {
                MainSplitView()
            } else {
                ConnectView()
            }
        }
        .animation(.easeInOut, value: app.isConnected)
    }
}

/// Application-menu commands, including the standard transport shortcuts.
struct PlaybackCommands: Commands {
    @ObservedObject var app: AppState
    @ObservedObject var engine: AudioPlayerEngine

    var body: some Commands {
        // Replace the default "New Window" group with playback controls.
        CommandGroup(replacing: .newItem) {}

        CommandMenu("Controls") {
            Button(engine.isPlaying ? "Pause" : "Play") {
                engine.playPauseToggle()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(engine.currentTrack == nil)

            Button("Next Track") { engine.next() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!engine.hasNext)

            Button("Previous Track") { engine.previous() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!engine.hasPrevious)

            Divider()

            Button("Shuffle") { engine.toggleShuffle() }
                .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Cycle Repeat") { engine.cycleRepeatMode() }
                .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Volume Up") {
                engine.volume = min(1, engine.volume + 0.1)
            }
            .keyboardShortcut(.upArrow, modifiers: .command)

            Button("Volume Down") {
                engine.volume = max(0, engine.volume - 0.1)
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
        }

        CommandGroup(after: .toolbar) {
            Button("Search") {
                app.selectedSection = .search
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Refresh Library") {
                Task { await app.loadLibrary() }
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
