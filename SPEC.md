# Cursa — macOS Mouse Automation Tool

## Overview

A lightweight macOS menu bar app that lets you record and replay mouse movements, and run customizable motion presets (circle, figure-8, back-and-forth line). Designed to live in the menu bar and stay out of the way.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI + AppKit (menu bar integration)
- **Target:** macOS 14+ (Sonoma)
- **Distribution:** Direct / outside App Store (no sandbox)

## Architecture

### Menu Bar App

- Lives primarily in the macOS menu bar (no Dock icon by default).
- Clicking the menu bar icon opens a dropdown with:
  - **Record / Stop Recording** toggle (shows the configured hotkey while recording is active)
  - **Play / Stop Playback** toggle
  - **Recording Loop Mode** submenu (Once, Ping-Pong, Repeat)
  - **Presets** (Circle, Figure-8, Line) — each opens a full-screen click-and-drag configuration overlay
  - **Settings…** (opens a config window)
  - **Quit**
- A small settings window (opened from menu) for configuring smoothing, loop mode, and hotkeys.

### Core Layers

1. **Input Capture** — `CGEventTap` to record global mouse positions + timestamps.
2. **Path Generator** — Protocol-based. Each preset (circle, figure-8, line) and recorded macros conform to the same `MousePath` protocol, producing a sequence of `(timestamp, x, y)` points.
3. **Playback Engine** — Timer-driven loop that posts `CGEvent` mouse-move events along a given path.

## Features

### MVP (v1)

#### Recording & Playback
- Record mouse movement (position + timing) while recording is active.
- Replay the most recent recording at original speed.
- Stop playback at any time.
- One recording slot in memory (new recording overwrites the old one).
- **Pre-roll countdown** — A 3-second countdown is shown in the menu bar before recording actually starts, giving the user time to move the mouse to the starting position.
- **Auto-cancel on user input** — Playback stops immediately if the physical mouse moves more than a few pixels from the expected (programmatic) position, so the user can always regain control.
- **Click recording** — Records left, right, and middle clicks (down + up events) alongside movement. Each click event stores the exact position and timestamp. During playback, clicks are replayed via `CGEvent` posting at the correct moments.
- **Smoothing slider** — Adjustable smoothing level (0% = raw input, 100% = heavily smoothed). Applies a moving-average smoothing pass (window scaled by the slider) to reduce jitter in recorded paths. Smoothing is applied fresh for each playback and is never destructive to the raw recording. **Click positions are pinned by index** — smoothing skips the exact sample points where a click event was recorded, so the mouse always arrives at the recorded (x, y) for each click.
- **Loop mode** — Three modes:
  - **Once** — Plays the recording once and stops.
  - **Ping-Pong** — Plays the recording forward, then in reverse, repeating until stopped.
  - **Repeat** — Plays the recording forward, loops back to the start, and repeats; the seam is blended over a short window (≤0.3s) to avoid a hard jump.

#### Motion Presets
- **Circle** — Configurable: center (x, y), radius (px), duration per revolution.
- **Figure-8** — Configurable: center (x, y), size, duration.
- **Back-and-forth line** — Configurable: start point, end point, duration.
- All presets loop continuously until stopped.
- **Interactive configuration overlay** — Selecting a preset opens a full-screen semi-transparent overlay. The user clicks and drags to set the geometry (center+radius for circle/figure-8, or start+end for line); a floating panel shows numeric fields + steppers for fine adjustment and a Start button to begin playback.

#### Controls
- **Menu bar dropdown** for all primary actions.
- **Global hotkeys** for hands-free use (defaults):
  - Record start/stop — `⌃⌥R`
  - Playback start/stop — `⌃⌥P`
  - Stop all — `⌃⌥X`
- Hotkeys are user-configurable in Settings and persisted via `UserDefaults`.

#### Permissions
- On first launch, check for Accessibility permission.
- If not granted, show a clear prompt explaining why it's needed and a button to open System Settings.
- Gracefully disable recording/playback features until permission is granted.

### Future (v2 — nice to have)

- Save/load recorded macros to files (JSON).
- Multiple recording slots / macro library.
- Adjustable playback speed (0.5x, 1x, 2x).
- Additional presets (square, spiral, random jitter).
- Dock icon toggle in settings.

## Non-Goals

- No App Store distribution or sandboxing.
- No iOS/iPadOS support.
- No scripting language or complex macro editor.

## File Structure

```
cursa/
├── cursaApp.swift                    # @main App entry point; installs StatusBarController
├── AppState.swift                    # @Observable app-wide state (activity, loop mode, smoothing)
├── StatusBarController.swift         # AppKit NSStatusItem menu bar UI + menu building
├── SettingsView.swift                # SwiftUI settings window (hotkeys, playback)
├── Models/
│   ├── MousePath.swift               # Protocol for mouse paths
│   ├── MouseEvent.swift              # MousePoint + ClickEvent + ClickType
│   ├── RecordedPath.swift            # Recorded mouse data + moving-average smoothing
│   ├── CirclePath.swift              # Circle preset
│   ├── Figure8Path.swift             # Figure-8 (lemniscate) preset
│   └── LinePath.swift                # Back-and-forth line preset
├── Services/
│   ├── MouseRecorder.swift           # CGEventTap recording (movement + clicks)
│   ├── MousePlayer.swift             # CGEvent playback engine (caches path per run)
│   ├── HotkeyManager.swift           # Global + local key monitors for hotkeys
│   └── AccessibilityChecker.swift    # AX permission checks
├── Overlay/
│   ├── OverlayCoordinator.swift      # Coordinates preset-configuration lifecycle
│   ├── OverlayWindowController.swift # Full-screen borderless window host
│   ├── OverlayView.swift             # Click-and-drag preset picker + path preview
│   ├── ToolbarPanelController.swift  # Floating NSPanel with preset controls
│   ├── ToolbarView.swift             # SwiftUI content of the floating panel
│   └── PresetConfiguration.swift     # @Observable preset configuration model
├── Assets.xcassets/
└── cursa.entitlements                # App Sandbox OFF (requires AX permission at runtime)
```

## Build & Run

```bash
# Build from command line
xcodebuild -project cursa.xcodeproj -scheme cursa -configuration Debug build

# Or open in Xcode
open cursa.xcodeproj
```

Requires Accessibility permission in System Settings → Privacy & Security → Accessibility.
