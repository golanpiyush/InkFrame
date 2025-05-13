****🎬 InkFrame****

Minimal yet powerful offline movie player for Android


InkFrame is built for cinephiles who appreciate both form and function. It intelligently organizes your local movie files, fetches rich metadata, handles subtitles effortlessly, and delivers a smooth, immersive playback experience — all wrapped in a beautiful, minimalist UI.

Future-ready: InkFrame will evolve into a hybrid platform supporting online streaming and movie discovery, alongside local playback.


****✨ Key Features****

**🎞️ 1. Smart Subtitle Engine**
  • Auto-detects movie filenames and fetches subtitles using intelligent heuristics
  
  • Supports .srt subtitle auto-download & caching
  
  • Multiple subtitle tracks with quick switching
  
  • Fully customizable:
  
  • Font size, color, and style
  
  • Background opacity and color
  
  • Sync offset adjustment

**📽️ 2. Movie Mode (Metadata & Enrichment)**
_Automatically fetches:_
  
  • IMDb rating
  
  • Posters & banners
  
  • Plot summaries
  
  • Cast & crew info
  
  • Rich, contextual movie detail screen before playback

****▶️ 3. Seamless Playback****
  
  • Remembers playback position for each movie
  
  • Double-tap gesture for play/pause (more gestures coming)
  
  • Clean, distraction-free UI
  
  • ExoPlayer-based for fast and stable playback, even with large files

****📂 4. Folder Intelligence****

  • Smart folder detection using structure, size, and naming patterns
  
  • Folder exclusion (e.g., hide WhatsApp, Instagram, Telegram videos)
  
  • Grid and list views for movie browsing
  

****🖤 5. Minimalist Design
****
  • Material You-inspired dark UI
  
  • Lightweight — no unnecessary background services
  
  • Fast, battery-friendly, and beautiful

  

****⚠️ What’s Missing (For Now)****
_InkFrame is under active development. Here's what we don’t support yet:_

• **❌ No network or streaming playback (coming soon)**

• **❌ No hash-based subtitle search (currently filename-based)**

• **❌ No Picture-in-Picture (PiP) mode**

• **❌ No Chromecast or DLNA support**

• **❌ No multi-audio track selection (defaults to first audio track)**

• **❌ English prioritized for metadata/subtitles (multi-language support planned)
**

**📅 Planned Features & Roadmap
**

_Feature	Status
_
**• ✅ Movie Streaming Support	Coming Soon\n
• ❌ Subtitle Sync Editor - Planned\n
• ❌ Multi-Audio Track Switching - Planned\n
• ❌ Picture-in-Picture Mode - Planned\n
• ❌ Chromecast / DLNA - Planned\n
• ❌ Theme Customization - Planned\n
• ❌ TV & Tablet UI (Android TV) - Planned\n
• ❌ Video Enhancement Filters	Planned**

**📦 Installation**
_Clone the repo and build using Android Studio:

git clone https://github.com/golanpiyush/InkFrame.git
Note: You'll need to add your TMDb API key to enable metadata fetching._

**🧠 Tech Stack**

• Language: Flutter

• Video Engine: ExoPlayer

• Metadata API: OMDb / IMDb (via unofficial endpoints)

• Subtitles: Custom fetch engine (OpenSubtitles)

• Architecture: MVVM + Jetpack Components

****🪓 Forking Notice
****
_InkFrame will soon be forked into a streaming-first version with support for:
_
**• 🌐 Online content streaming**

**• ☁️ Cloud libraries
**
**• 📚 Synced watchlists
**

_Stay tuned if you're interested in contributing to the hybrid or streaming fork.
_
****💡 Contributing
****
We welcome all contributions!

• 🛠 Submit pull requests

• 🐞 File bugs or feature requests

• 🌍 Help with localization

• 🎨 Contribute UI/UX designs

• ⚡ Improve performance

🖼 Screenshots

**Folder Exclusion Screen -
**
• ![WhatsApp Image 2025-05-14 at 02 26 48_2af578b7](https://github.com/user-attachments/assets/7976e9bb-68df-4716-b011-238d80607d6e)

**Library Screen (Main) -
**
• ![WhatsApp Image 2025-05-14 at 02 26 48_7f7848ce](https://github.com/user-attachments/assets/0b009484-22f9-49f8-a566-8ebac1dc1053)

**FolderContent Screen - 
** 
![WhatsApp Image 2025-05-14 at 02 26 49_c46979aa](https://github.com/user-attachments/assets/9fef6e39-4794-4c66-85de-009afa3d1307)



**📄 License
**
_MIT License — Free to use, modify, and distribute.
_
