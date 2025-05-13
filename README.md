🎬 InkFrame
Minimal yet powerful offline movie player for Android

InkFrame is built for cinephiles who appreciate both form and function. It intelligently organizes your local movie files, fetches rich metadata, handles subtitles effortlessly, and delivers a smooth, immersive playback experience — all wrapped in a beautiful, minimalist UI.

Future-ready: InkFrame will evolve into a hybrid platform supporting online streaming and movie discovery, alongside local playback.

✨ Key Features
🎞️ 1. Smart Subtitle Engine
Auto-detects movie filenames and fetches subtitles using intelligent heuristics

Supports .srt subtitle auto-download & caching

Multiple subtitle tracks with quick switching

Fully customizable:

Font size, color, and style

Background opacity and color

Sync offset adjustment

📽️ 2. Movie Mode (Metadata & Enrichment)
Automatically fetches:

IMDb rating

Posters & banners

Plot summaries

Cast & crew info

Rich, contextual movie detail screen before playback

▶️ 3. Seamless Playback
Remembers playback position for each movie

Double-tap gesture for play/pause (more gestures coming)

Clean, distraction-free UI

ExoPlayer-based for fast and stable playback, even with large files

📂 4. Folder Intelligence
Smart folder detection using structure, size, and naming patterns

Folder exclusion (e.g., hide WhatsApp, Instagram, Telegram videos)

Grid and list views for movie browsing

🖤 5. Minimalist Design
Material You-inspired dark UI

Lightweight — no unnecessary background services

Fast, battery-friendly, and beautiful

⚠️ What’s Missing (For Now)
InkFrame is under active development. Here's what we don’t support yet:

❌ No network or streaming playback (coming soon)

❌ No hash-based subtitle search (currently filename-based)

❌ No Picture-in-Picture (PiP) mode

❌ No Chromecast or DLNA support

❌ No multi-audio track selection (defaults to first audio track)

❌ English prioritized for metadata/subtitles (multi-language support planned)

📅 Planned Features & Roadmap
Feature	Status
✅ Movie Streaming Support	Coming Soon
❌ Subtitle Sync Editor	Planned
❌ Multi-Audio Track Switching	Planned
❌ Picture-in-Picture Mode	Planned
❌ Chromecast / DLNA	Planned
❌ Theme Customization	Planned
❌ TV & Tablet UI (Android TV)	Planned
❌ Video Enhancement Filters	Planned

📦 Installation
Clone the repo and build using Android Studio:

bash
Copy
Edit
git clone https://github.com/golanpiyush/InkFrame.git
Note: You'll need to add your TMDb API key to enable metadata fetching.

🧠 Tech Stack
Language: Flutter

Video Engine: ExoPlayer

Metadata API: OMDb / IMDb (via unofficial endpoints)

Subtitles: Custom fetch engine (OpenSubtitles)

Architecture: MVVM + Jetpack Components

🪓 Forking Notice
InkFrame will soon be forked into a streaming-first version with support for:

🌐 Online content streaming

☁️ Cloud libraries

📚 Synced watchlists

Stay tuned if you're interested in contributing to the hybrid or streaming fork.

💡 Contributing
We welcome all contributions!

🛠 Submit pull requests

🐞 File bugs or feature requests

🌍 Help with localization

🎨 Contribute UI/UX designs

⚡ Improve performance

🖼 Screenshots
📎 Attach screenshots below to showcase UI/UX, features, and movie detail screens.

bash
Copy
Edit
[Add your screenshots here, for example:]
- /screenshots/home_ui.png
- /screenshots/movie_details.png
- /screenshots/player.png
📄 License
MIT License — Free to use, modify, and distribute.
