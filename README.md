# NavidromeMac

A **100% native macOS client** for [Navidrome](https://www.navidrome.org/) (and
any Subsonic-API-compatible server), written in Swift + SwiftUI and styled for
the **macOS 26 "Tahoe" Liquid Glass** aesthetic.

No Electron, no web view — just AppKit/SwiftUI, `URLSession`, `AVPlayer`, and the
system `MediaPlayer` framework.

---

## Features

- **Native Subsonic/Navidrome client**
  - Token + salt authentication (`md5(password + salt)`); your password is stored
    only in the **macOS Keychain**, never on disk in plaintext.
  - Library browsing: artists, albums, playlists.
  - Unified search across artists / albums / songs (`search3`).
  - Star / unstar favourites and automatic scrobbling (`scrobble`).
- **Native audio engine**
  - `AVPlayer`-backed gapless-feeling streaming with a play queue, shuffle, and
    repeat (off / all / one).
  - Smooth seeking with a scrubber that doesn't fight the playhead.
- **Traditional Mac integration**
  - **Media keys & Control Centre** via `MPRemoteCommandCenter` /
    `MPNowPlayingInfoCenter`, including artwork, elapsed time, and transport.
  - **Menu Bar Extra** for quick play/pause/skip without raising the window.
  - Standard menu bar commands and keyboard shortcuts (see below).
- **Liquid Glass UI**
  - `NavigationSplitView` with a translucent sidebar, an adaptive album/artist
    grid, and a **floating glass player bar** built from SwiftUI materials.

### Keyboard shortcuts

| Shortcut            | Action            |
| ------------------- | ----------------- |
| `Space`             | Play / Pause      |
| `⌘ →`               | Next track        |
| `⌘ ←`               | Previous track    |
| `⌘ ↑` / `⌘ ↓`       | Volume up / down  |
| `⇧⌘ S`              | Toggle shuffle    |
| `⇧⌘ R`              | Cycle repeat mode |
| `⌘ F`               | Search            |
| `⌘ R`               | Refresh library   |
| `⌘ ,`               | Settings          |

---

## Project layout

```
navidrome-mac/
├── Package.swift                    # SwiftPM manifest (executable target)
├── build.sh                         # Compile + bundle into NavidromeMac.app
├── Resources/
│   ├── Info.plist                   # Bundle metadata injected by build.sh
│   └── NavidromeMac.entitlements    # Optional (App Sandbox) entitlements
└── Sources/NavidromeMac/
    ├── App/
    │   ├── NavidromeMacApp.swift     # @main, scenes, menu commands, MenuBarExtra
    │   └── AppState.swift            # Central ObservableObject / coordinator
    ├── Models/
    │   ├── ServerConfig.swift
    │   ├── Track.swift
    │   ├── Album.swift
    │   ├── Artist.swift
    │   ├── Playlist.swift
    │   └── SubsonicResponse.swift    # JSON envelope + endpoint containers
    ├── Services/
    │   ├── NavidromeAPIClient.swift  # async URLSession Subsonic client (actor)
    │   ├── AudioPlayerEngine.swift   # AVPlayer queue + transport (@MainActor)
    │   ├── NowPlayingManager.swift   # MediaPlayer / media keys bridge
    │   └── KeychainHelper.swift      # Secure password storage
    ├── Utilities/
    │   ├── CoverImage.swift          # Async authenticated cover-art loader
    │   └── GlassStyle.swift          # Liquid Glass view modifiers
    └── Views/
        ├── MainSplitView.swift       # NavigationSplitView + floating player
        ├── SidebarView.swift
        ├── AlbumGridView.swift
        ├── AlbumDetailView.swift
        ├── ArtistGridView.swift      # grid + ArtistDetailView
        ├── PlaylistViews.swift       # list, cell + PlaylistDetailView
        ├── SearchView.swift
        ├── TrackRow.swift
        ├── PlayerControlBar.swift
        ├── MenuBarView.swift
        ├── ConnectView.swift         # Onboarding / connect flow
        └── SettingsView.swift
```

---

## Building & running (on a Mac)

> ⚠️ These source files were authored in a Linux environment and **cannot be
> compiled there**. Build on macOS with Xcode 16+ (Xcode 26 for the full Tahoe
> Liquid Glass rendering).

### Option A — Swift Package Manager + `build.sh` (recommended)

```bash
cd navidrome-mac
./build.sh --run
```

This compiles a release build, assembles `dist/NavidromeMac.app`, ad-hoc signs
it, and launches it. Other flags:

```bash
./build.sh           # build + bundle only
./build.sh --debug   # debug configuration
./build.sh --open    # build, bundle, reveal in Finder
```

To just run the executable without bundling (note: the Menu Bar Extra and Now
Playing features behave best from a real `.app` bundle):

```bash
swift run
```

### Option B — Open in Xcode

```bash
cd navidrome-mac
open Package.swift     # Xcode opens the package directly
```

Select the **NavidromeMac** scheme and press **⌘R**. To produce a signed,
notarisable app, switch the target's signing to your Developer ID and (if you
enable the App Sandbox) add `Resources/NavidromeMac.entitlements`.

---

## First launch

1. Launch the app — you'll see the **Connect** screen.
2. Enter:
   - **Server URL** — e.g. `https://music.example.com` (the base URL; the app
     appends `/rest/...` itself).
   - **Username** and **Password** for your Navidrome account.
3. Click **Connect**. On success the credentials are saved to the Keychain and
   the library loads. Subsequent launches reconnect automatically.

Want to try it without your own server? Navidrome runs a public demo at
`https://demo.navidrome.org` (user `demo`, password `demo`).

---

## Notes & customisation

- **HTTP servers:** `Info.plist` enables `NSAllowsArbitraryLoads` so LAN servers
  on plain HTTP work. Remove that key if you exclusively use HTTPS.
- **App Sandbox / App Store:** the default build is **not** sandboxed so the
  generic-password Keychain API works with zero configuration. To sandbox, sign
  with `--entitlements Resources/NavidromeMac.entitlements` and keep the
  `network.client` entitlement.
- **App icon:** drop an `AppIcon.icns` into `Resources/` and `build.sh` will
  bundle it automatically.
- **Minimum OS:** the manifest targets macOS 14, so it also runs on Sonoma /
  Sequoia; the translucent-material styling lights up fully on Tahoe.

---

## Architecture at a glance

- `NavidromeAPIClient` is an **`actor`** — all network state (config, password,
  salted-token generation) is isolated and accessed with `await`.
- `AudioPlayerEngine` and `AppState` are **`@MainActor` `ObservableObject`s** so
  SwiftUI observes them directly; the engine drives `NowPlayingManager`, which
  owns the system transport hooks.
- Views are thin and composable; cover art is fetched through `CoverImage`,
  which resolves an authenticated URL from the actor before handing it to
  `AsyncImage` for fetching and caching.
