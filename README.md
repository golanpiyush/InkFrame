InkFrame

InkFrame is a minimal yet powerful offline movie video player for Android. Built for cinephiles who value both design and functionality, InkFrame intelligently organizes and plays your local video files — especially full-length movies — with rich metadata, subtitle automation, and a focus on smooth, immersive playback.

> Future-ready: InkFrame will eventually evolve into a hybrid movie platform — supporting online movie streaming and discovery alongside local playback.




---

Key Features

1. Smart Subtitle Engine

Automatically detects movie file names and fetches subtitles using intelligent heuristics.

Supports auto-download and caching of .srt files.

Supports multiple subtitle tracks with easy switching.

Fully customizable subtitles:

Font size, color, and style

Background opacity and color

Sync adjustment



2. Movie Mode (Metadata & Enrichment)

When a movie is detected, InkFrame auto-fetches:

IMDb rating

Poster & banner

Plot synopsis

Cast & crew info


Offers a rich, contextual experience before you hit play.


3. Seamless Playback

Remembers the last playback position for every movie.

Double-tap to pause/play gesture (more gestures planned).

Clean, distraction-free player UI using ExoPlayer under the hood.

Resumes playback with lightning speed, even with large files.


4. Folder Intelligence

Auto-detects movie folders (based on structure, file naming, and size).

Allows folder exclusion to hide unwanted content (e.g., WhatsApp videos, reels).

Supports both grid and list views for browsing.


5. Minimalist Design

Material You inspired clean, dark UI.

Light footprint, no background services unless needed.

Built to be beautiful, battery-efficient, and blazing fast.



---

What's Missing (for now)

> Transparency matters. Here's what InkFrame does not support yet, but may in future updates.

No network/streaming playback (future support planned).

No subtitle search by hash (uses name-based lookup currently).

No PiP (Picture-in-Picture) mode yet.

No Chromecast or DLNA.

No multi-audio track switch (currently defaults to first track).

Only English language is prioritized in metadata and subtitles.



---

Planned Features & Roadmap

Feature	Status

Movie Streaming Support	Coming soon
Subtitle sync editor	Planned
Multi-audio track switching	Planned
PiP Mode	Planned
Chromecast / DLNA streaming	Planned
Theme customization	Planned
TV & tablet UIs (Android TV)	Planned
Video enhancement filters	Planned



---

Preview

> (Add your screenshots here and update paths accordingly)



Movie Details	Player UI	Subtitle Settings	Folder Picker

			



---

How to Install

Clone and build using Android Studio:

git clone https://github.com/yourusername/InkFrame.git

Make sure to add your TMDb API key if metadata fetching is enabled.


---

Tech Stack

Language: Kotlin

Video Engine: ExoPlayer

Metadata API: TMDb / IMDb (via unofficial endpoints)

Subtitles: Custom fetch engine from OpenSubtitles

Architecture: MVVM + Jetpack Libraries



---

Forking Notice

> InkFrame will be forked into a parallel streaming version — supporting content streaming, cloud libraries, and synced watchlists — in the near future.
Stay tuned if you're interested in contributing to the streaming branch or a hybrid version of the player.




---

Contributing

We're happy to welcome contributors! You can:

Submit PRs

File issues or feature requests

Help with localization, UI design, or performance tuning



---

License

MIT License — free to use, modify, and distribute.
