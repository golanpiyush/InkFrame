inkFrame

Minimal yet powerful offline movie player for Android

InkFrame is designed for cinephiles who value both form and function. It intelligently organizes your local movie files, fetches rich metadata, handles subtitles effortlessly, and delivers a smooth, immersive playback experience — all wrapped in a beautiful, minimalist UI.

> Future-ready: InkFrame is set to evolve into a hybrid movie platform supporting online streaming and movie discovery alongside local playback.




---

Key Features

1. Smart Subtitle Engine

Auto-detects movie filenames and fetches subtitles using intelligent heuristics

Supports .srt subtitle auto-download & caching

Multiple subtitle tracks with easy switching

Fully customizable:

Font size, color, and style

Background opacity and color

Sync offset adjustment




---

2. Movie Mode (Metadata & Enrichment)

Automatically fetches:

IMDb rating

Poster & banners

Plot summary

Cast & crew info


Rich, contextual movie detail screen before playback



---

3. Seamless Playback

Remembers playback position for each movie

Double-tap gesture for play/pause (more gestures coming)

Clean, distraction-free UI

ExoPlayer-based fast and stable playback, even for large files



---

4. Folder Intelligence

Smart folder detection based on structure, file size, and naming

Folder exclusion (hide WhatsApp videos, Instagram reels, etc.)

Grid and list views for browsing



---

5. Minimalist Design

Material You-inspired dark UI

Lightweight with no unnecessary background services

Fast, battery-friendly, and beautiful



---

What’s Missing (For Now)

> Transparency first — here’s what we don’t support yet:



No network or streaming playback (coming soon)

No hash-based subtitle search (currently name-based only)

No PiP (Picture-in-Picture) mode

No Chromecast or DLNA support

No multi-audio track selection (defaults to first)

English prioritized for metadata/subtitles (multi-language support planned)



---

Planned Features & Roadmap

Feature	Status

Movie Streaming Support	Coming Soon
Subtitle Sync Editor	Planned
Multi-Audio Track Switching	Planned
Picture-in-Picture Mode	Planned
Chromecast / DLNA	Planned
Theme Customization	Planned
TV & Tablet UI (Android TV)	Planned
Video Enhancement Filters	Planned



---

Installation

Clone the repo and build using Android Studio:

git clone https://github.com/yourusername/InkFrame.git

> Note: You’ll need to add your TMDb API key to enable metadata fetching.




---

Tech Stack

Language: Flutter

Video Engine: ExoPlayer

Metadata API: OMDb / IMDb (via unofficial endpoints)

Subtitles: Custom fetch engine (OpenSubtitles)

Architecture: MVVM + Jetpack Components



---

Forking Notice

InkFrame will soon be forked into a streaming-first version, supporting:

Online content streaming

Cloud libraries

Synced watchlists


> Stay tuned if you're interested in contributing to the hybrid or streaming branch.




---

Contributing

We welcome contributions! You can:

Submit pull requests

File bugs or feature requests

Help with localization, UI design, or performance optimization



---

License

MIT License — free to use, modify, and distribute.