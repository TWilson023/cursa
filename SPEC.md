# Cursa — macOS Mouse Automation Tool

## Overview

A lightweight macOS menu bar app for **making UI demos with cursor motion that looks designed, not captured**. Cursa drives the system cursor along configurable motion presets (circle, figure-8, back-and-forth line) so you can record clean, looped cursor motion over product visuals while you screen-record — the cursor glides on a mathematically perfect path and the menu bar stays out of the shot.

**Target user:** designers, developers, and marketers shooting product demos, landing-page hero videos, App Store previews, docs GIFs, and Dribbble shots — anything where a cursor is part of the shot. Not a gaming macro tool or a QA automation framework; it's a screen-recording companion.

> **Status:** v0.1 ships **presets only**. Mouse recording / replay is planned but not yet implemented — see [Future](#future-v2--planned).

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI + AppKit (menu bar integration)
- **Target:** macOS 14+ (Sonoma)
- **Distribution:** Direct / outside App Store (no sandbox)

## Architecture

### Menu Bar App

- Lives primarily in the macOS menu bar (no Dock icon by default).
- Clicking the menu bar icon opens a dropdown with:
  - **Presets** (Circle, Figure-8, Line) — each opens a full-screen click-and-drag configuration overlay
  - **Stop Playback** (shown only while a preset is playing)
  - **Settings…** (opens a config window)
  - **Quit**
- A small settings window (opened from menu) for configuring the stop hotkey.

### Core Layers

1. **Path Generator** — Protocol-based. Each preset (circle, figure-8, line) conforms to the `MousePath` protocol, producing a sequence of `(timestamp, x, y)` points.
2. **Playback Engine** — Timer-driven loop that posts `CGEvent` mouse-move events along a given path.

## Features

### MVP (v1)

#### Motion Presets
- **Circle** — Configurable: center (x, y), radius (px), duration per revolution.
- **Figure-8** — Configurable: center (x, y), size, duration.
- **Back-and-forth line** — Configurable: start point, end point, duration.
- All presets loop continuously until stopped.
- **Interactive configuration overlay** — Selecting a preset opens a full-screen semi-transparent overlay. The user clicks and drags to set the geometry (center+radius for circle/figure-8, or start+end for line); a floating panel shows numeric fields + steppers for fine adjustment and a Start button to begin playback.
- **Optional starting click** — Posts a left-click at the path's starting point before playback begins, so the demo can show a click landing before the cursor begins its loop.
- **Auto-cancel on user input** — Playback stops immediately if the physical mouse moves more than a few pixels from the expected (programmatic) position, so the user can always regain control.

#### Controls
- **Menu bar dropdown** for all primary actions.
- **Global hotkey** for hands-free stop:
  - Stop playback — `⌃⌥X` (configurable in Settings, persisted via `UserDefaults`).

#### Permissions
- On first launch, check for Accessibility permission.
- If not granted, show a clear prompt explaining why it's needed and a button to open System Settings.
- Gracefully disable preset features until permission is granted.

### Future (v2 — planned)

- **Mouse recording & replay** — record cursor movement + clicks via `CGEventTap`, replay at original speed with optional smoothing (moving-average, click positions pinned), and loop modes (Once, Ping-Pong, Repeat with seam blending). The plumbing for this was prototyped but pulled from v0.1 because it was too unreliable to ship; presets cover the primary use case while recording is rebuilt.
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
├── AppState.swift                    # @Observable app-wide state (activity, starting-click)
├── StatusBarController.swift         # AppKit NSStatusItem menu bar UI + menu building
├── SettingsView.swift                # SwiftUI settings window (stop hotkey)
├── Models/
│   ├── MousePath.swift               # Protocol for mouse paths
│   ├── MouseEvent.swift              # MousePoint + ClickEvent + ClickType
│   ├── CirclePath.swift              # Circle preset
│   ├── Figure8Path.swift             # Figure-8 (lemniscate) preset
│   └── LinePath.swift                # Back-and-forth line preset
├── Services/
│   ├── MousePlayer.swift             # CGEvent playback engine (caches path per run)
│   ├── HotkeyManager.swift           # Global + local key monitor for the stop hotkey
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
