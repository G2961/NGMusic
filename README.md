# NGMusic
<img width="2160" height="1080" alt="Picsart_26-09-22_14-13-50-119" src="https://github.com/user-attachments/assets/70199b32-7fd9-4732-a8ec-e77aa689683b" />

**English** | [Русский](README.ru.md)

A mobile player for the [Newgrounds Audio Portal](https://www.newgrounds.com/audio) — an unofficial client with a lot of features. The same NG Audio Portal, but as a convenient app.

## Features

- **Catalog and search:** hubs (Featured / Popular / New / Top Rated), track search with endless scrolling
- **Player:** mp3 streaming, queue, auto-advance to the next track, mini-player, background playback
- **Ratings:** 0–5 star voting in 0.5 steps for the Modern skin, whole stars for the Classic skin
- **Favorites and playlists:** add tracks to your Newgrounds account favorites, local playlists
- **Account:** log in to Newgrounds, view and create your playlists library
- **Artists:** artist pages with their tracks
- **Downloads:** save mp3 files to the device

Data is pulled directly from newgrounds.com: HTML is parsed locally, audio is streamed from the Newgrounds CDN.

## Tech stack

- Flutter / Dart, min SDK — Android 5.0 (API 21)
- `http` + `html` for fetching and parsing pages
- Media3 (ExoPlayer + MediaSessionService) for playback and background mode
- `provider` for state management (`ChangeNotifier`)
- `sqflite` as the base of the local library (favorites, playlists)
- `webview_flutter` for logging in to a Newgrounds account

## Build and run

```bash
flutter pub get
flutter run                    # dev mode
flutter build apk --release   # release APK
```

Tests:

```bash
flutter test
```

## Structure

```
lib/
├── data/
│   ├── model/track.dart               # Track model
│   └── repository/ng_repository.dart  # newgrounds.com requests and parsing
├── player/
│   └── ng_audio_handler.dart          # Audio handler (bridge to the native Media3 player)
├── services/
│   └── track_downloader.dart          # mp3 downloads
├── ui/
│   ├── screens/                       # Hub, player, library, account, artists, search
│   ├── widgets/                       # Retro widgets: 2015 chrome, votebar, mini-player
│   └── theme/ng_theme.dart            # NG palette and fonts
├── viewmodel/
│   ├── ng_viewmodel.dart              # Catalog and player state
│   └── library_viewmodel.dart         # Local library
└── main.dart                          # Entry point
```

## ❗IMPORTANT❗

This app is unofficial and not affiliated with Newgrounds. All content rights belong to its authors and Newgrounds.
