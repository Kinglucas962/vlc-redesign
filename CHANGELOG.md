# Changelog

Changes of **VLC Redesign**, an unofficial VLC 4 build with the interface designed by
[Juxtopposed](https://www.youtube.com/@juxtopposed) ([video](https://www.youtube.com/watch?v=ERFeOgqk324)).
For changes to VLC itself, see [NEWS](NEWS).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each section groups changes by
what you see first, with the technical details after. Based on VLC `4.0.0-dev` (`392bc1d0ab`, 2026-10-12).

**Contents:** [0.1.0](#010--2026-10-20) · [M3](#m3--dialogs-settings-and-playback-tools--2026-10-13) ·
[M2](#m2--library-playlists-and-subtitles--2026-10-13) · [M1](#m1--first-native-shell-and-player--2026-10-12) ·
[M0](#m0--baseline-and-build--2026-10-12) · [Differences from upstream VLC](#differences-from-upstream-vlc)

---

## [0.1.0] · 2026-10-20

**The first Windows release.** The redesign now builds and runs on real Windows, matches the Figma
frames down to the pixel on the measured screens, and no longer freezes.

### Highlights

- 🪟 **Runs on Windows**: a reproducible Docker build and a portable zip.
- 🎯 **Pixel-matched to the design**: text renders like Figma (Inter, same spacing), the light theme follows the *Player - Light* frame.
- 🧊 **No more freezes**: three deadlocks between the interface and the core are fixed.
- 📚 **New library spots**: *Listen Again*, *Frequently Visited Folders*, a folder browser, and a compact library over the video.
- 🎛️ **Settings rebuilt** with the design's controls and many more VLC options.
- 🖼️ **Frame previews** when hovering the seek bar.

### Added

**Player**
- A compact library sidebar over the video: sections, folder breadcrumb, search, sorting, progress and play counts.
- A queue card with *Queue*, *Bookmarks* and *Chapters* tabs.
- Frame previews when hovering the seek bar, for local seekable videos (option `qt-seek-thumbnail`).
- 12 new control bar buttons: ±10 s, picture-in-picture, right sidebar, home, thumbnail, folder name, playlist name, replay, chapters, bookmarks, playlists, main menu, library.
- Control bar editing by drag and drop on the player itself. The timeline can sit on its own row.
- **Q** toggles the queue and **L** the library (only when no VLC hotkey uses the key).
- An *External Tracks* group in the subtitle panel; a refresh for the audio device list; a *None* video track.

**Library**
- *Listen Again* on Home (recently played audio) and *Frequently Visited Folders* (ranked from recent history).
- A folder page with breadcrumbs.
- Playlists: favourite, shuffle play, export to a file.
- Add and remove bookmarks from the interface.
- The subtitle dialog can also attach external audio tracks, and target a whole folder or playlist.

**Settings**
- A settings window without an Apply button: changes are saved when it closes. Search, sidebar, and an *Advanced Options* block on every page.
- The design's controls: toggle, dropdown, segmented control, slider, text field, startup volume, inline equalizer.
- Many more VLC options, regrouped like the design, including repeat / loop, play and exit, fast seek, skins, mouse wheel direction, web remote, night mode, caching presets and post-processing.
- Language list (ISO 639-2), optical drives and x264 presets in dropdowns.
- Actions: rescan plugins, open the configuration folder, reset everything.
- Window geometry memory, notification duration, cast device discovery, process priority (Windows), double-click action, a filter for the recent items list, subtitle size mode and background opacity.
- Interface language for the portable copy, kept in `<vlc folder>\portable\language` instead of the registry an installed VLC uses.

**Dialogs and menus**
- A redesigned **Network Stream** dialog: several URLs at once, optionally saved as a playlist.
- A redesigned right-click menu: playback, *Hide UI* (Ctrl+\\), playback / video / audio / subtitle submenus, playlist, open media, quit. Shortcut labels come from your actual hotkeys.
- A **⋯ main menu**: open actions, *Open Recent*, profiles, keyboard shortcuts, customise player, settings, about.
- Classic VLC menus are redrawn to the design, with two-tone icons.

**Credits and packaging**
- The design credit (CC BY 4.0) in **About**, in its Credits page, and in [CREDITS.md](CREDITS.md).
- The Windows package ships `CREDITS.txt`, `CHANGELOG.txt`, `COPYING.LIB.txt` and the font licenses (`licenses/`).

### Changed

- The video is framed between the bars, with a 10 px inset and rounded corners; a redesigned top bar.
- The skip buttons jump ±15 s.
- Times are always shown with hours; the resume prompt is a compact card; record shows the accent colour instead of blinking.
- The volume slider goes up to 200 %, with fill states to match.
- The bars auto-hide in fullscreen.
- Onboarding: keycaps show your real shortcuts, the theme previews live, and it can be cancelled with *Cancel* or Escape.
- The toolbar editor became a *Customize Player* panel that edits the bar in place.
- The subtitle association and new playlist dialogs use the shared redesign dialog.
- Video cards use file names as titles, dim watched items and show progress as an accent line.
- The library header has an address bar, named sort options and a *View Options* menu.
- Without the main interface (skins), the classic Preferences and Effects windows open.

**Visual fidelity**
- Inter is the application font, rendered with distance fields, no hinting and greyscale antialiasing, the combination that matches Figma's text.
- The bundled Inter has every advance width one unit wider: Qt truncates advances to 1/64 px, and the extra unit gives back the design's spacing.
- DM Mono for keyboard shortcuts.
- Light theme: icons are recoloured to the *Player - Light* frame's greys.
- Most icons re-exported; new player corners and theme preview images; restyled checkboxes, scroll bars, headers and sidebar rows.
- Rounded video and artwork textures crop correctly at any aspect ratio.

### Changed defaults

| Option | Before | Now | Why |
|---|---|---|---|
| `qt-pin-controls` | off | **on** | The design keeps the bars beside the video |
| `qt-video-autoresize` | on | **off** | The window keeps its size when a video starts |
| `qt-max-volume` | 125 | **200** | The design's volume control goes to 200 % |
| Loop hotkey (`key-loop`) | `L` | **Shift+L** | `L` opens the library |
| Next / previous | | also **`<` `>`** | |
| Next / previous frame | | also **`.` `,`** | |
| OSD message duration | fixed | **`osd-duration`** (1000 ms) | Set from the notification duration setting |

### Fixed

**Freezes and crashes**
- The interface froze when a hotkey waited on the video output: hotkeys now go to the core from their own thread.
- A deadlock between the player, the input resource and the interface thread: `input_resource_SetInput` now runs in the input thread's `Init`.
- A deadlock when the video window was enabled or disabled: `vlc_window_Enable` / `Disable` are called outside `window_lock`, and `Enable` gets a copy of the configuration.
- A crash on exit with MinGW (Qt's thread-local timer outlived the libstdc++ destructor key).
- An assertion on iPhone HEIC photos (`ES_OUT_DRAIN`); HEIF images show the primary grid instead of each tile.
- Wrong colours and Direct3D 11 device removal when switching video filters; a plane overrun in the interactive filter picture pool.
- Video filters (extract, gradfun, gradient, grain, invert, sepia, sharpen) refuse to open when input and output formats differ, instead of producing garbage.

**Interface**
- The window shrank by 16×8 px on every restart (Windows' resize borders weren't counted). It now opens at 1280×720, centred, the first time, and restores maximised and fullscreen windows to their normal size.
- The waveform seek bar and cover corners were rebuilt without Canvas, which VLC's Qt Quick lacks; the waveform helper gets native paths on Windows.
- Rate and delay changes are announced after the player lock is released.
- Developer mode was on whenever the setting read back as the text `"false"`.
- Importing a profile with a setting that no longer exists failed: the setting is now skipped.
- The effects dialog no longer cancels itself while closing; popups are centred on whole pixels; the title bar stays draggable while a dialog is open.
- The audio effects hint showed an internal name (`audioBridge`).
- The registry language read is type-checked and the key is closed.

### Build

- **Windows Docker build**: `extras/juxtopposed/win64-docker.ps1` (host) runs `win64-docker.sh` in VideoLAN's official `vlc-debian-win64-posix` image with prebuilt contribs. Objects persist in a Docker volume; `-Quick` skips configure; `-Lint` runs qmllint on changed QML; `-Volume` and `-Strip` make a separate stripped release build.
- The SRT, x265 and GME plugins link the static unwinder, so they don't import `libgcc_s_seh-1.dll`, which the plugin loader can't find.
- `vlc-waveform` links its runtime statically on Windows.
- OpenSubtitles uses a WinHTTP client on Windows, so the QtNetwork dependency is gone.
- License headers on every new source file; Meson and Autotools list the same QML files and resources; line endings normalised to LF.

---

## M3 · Dialogs, settings and playback tools · 2026-10-13

*By MrDouglax, in [JuxtopposedVLC](https://github.com/SrDouglax/JuxtopposedVLC).*

### Added
- Redesigned settings on a staged QML model: startup, file logging and diagnostics, Last.fm, developer mode, add-ons, audio device preview with rollback, DPI-scaled navigation, clearing history under Privacy.
- A three-step onboarding: welcome, theme, shortcuts.
- A keyboard shortcut editor with staged changes and a confirmed reset.
- Transactional audio and video effects, equalizer preset curves, effects inline in settings.
- Sleep timer (stop or pause), control bar profiles and a personalisation menu.
- Control bar customisation on the live player; profiles keep a safe subset of settings.
- New controls: favourite, file and artist name, frame rate, resolution, zoom, HDR, divider.
- Mini player with a live queue, picture-in-picture, a dedicated music view, a blurred backdrop.
- A **waveform seek bar** computed by the isolated `vlc-waveform` helper, and a *waveform* audio visualisation.
- HDR output selection, depending on the video backend.
- Advanced subtitle sources (OpenSubtitles, links), series timing presets and a sync timeline in the tracks menu.

### Fixed
- QML delegates, series lifetime, light theme contrast, popup checkmarks, video resizing during effect rollback.

## M2 · Library, playlists and subtitles · 2026-10-13

*By MrDouglax.*

- A compact tracks and playback panel with chapters and bookmarks.
- Create and edit playlists from the library; native *Open media* actions.
- Subtitle choices remembered per media, restored for direct playback too.
- Header layout for narrow windows; video cards, header, sidebar and floating player aligned to the design.

## M1 · First native shell and player · 2026-10-12

*By MrDouglax.*

- The redesigned window shell and player controls (window buttons, adjacent playback controls, design defaults).
- The redesign icon set and the four volume states exported from Figma.
- Fixed opening videos through nested navigation.

## M0 · Baseline and build · 2026-10-12

*By MrDouglax.*

- Linux Docker build, smoke tests and launcher (`extras/juxtopposed/`).
- A Windows CI workflow with MinGW runtime packaging.
- Plans, Figma coverage maps and validation evidence under `.specs/`.

---

## Differences from upstream VLC

Most of the work is in the Qt interface (`modules/gui/qt`). These changes touch the rest of VLC; they're
the ones to watch when merging upstream, and the candidates to propose to VideoLAN.

| File | Change |
|---|---|
| `src/input/input.c` | `input_resource_SetInput` moved to the input thread's `Init` (deadlock) |
| `src/video_output/video_output.c` | Window enable/disable outside `window_lock` (deadlock); pool fallback for other chromas |
| `src/video_output/window.c` | `vlc_window_Enable` passes a copy of the configuration |
| `src/video_output/video_text.c` | OSD duration from `osd-duration` |
| `src/libvlc-module.c` | `osd-duration` and `media-library-enabled` options; hotkey changes (see *Changed defaults*) |
| `src/libvlc.c` | The media library is created only when `media-library-enabled` is on |
| `src/player/medialib.c` | External subtitle and soundtrack files from the media library attached before playback |
| `src/audio_output/filters.c`, `output.c` | The *waveform* visualisation choice |
| `modules/visualization/visual/` | Oscilloscope code moved to its own file; waveform effect |
| `modules/demux/mp4/heif.c` | Primary grid shown; PCR reset after drain (assert) |
| `modules/video_output/win32/direct3d11.cpp` | Unsupported CPU chromas and mismatched pictures refused |
| `modules/video_filter/{extract,gradfun,gradient,grain,invert,sepia,sharpen}.c` | Refuse differing input/output chromas |
| `modules/text_renderer/freetype/freetype.c` | `freetype-fontsize` brought back; default text direction |
| `bin/winvlc.c` | Portable language file read before the registry |
| `bin/Makefile.am`, `bin/meson.build` | Build the `vlc-waveform` helper |
| `extras/package/win32/package.mak` | Credits, changelog and font licenses in the package |

[0.1.0]: https://github.com/KuchiSofts/vlc-redesign/releases/tag/v0.1.0
