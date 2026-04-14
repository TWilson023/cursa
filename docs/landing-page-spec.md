# Cursa Landing Page — Spec

A single-page marketing site for **Cursa**, a macOS menu bar app for recording, replaying, and generating mouse motion. Lives at **cursa.so**.

## Stack

- Next.js (App Router) + TypeScript
- Tailwind CSS
- Hosted on Vercel, deployed from `main`
- Vercel Analytics (no cookies, no banner)
- No CMS, no database, no auth. All content hard-coded.

## What Cursa Is

A **lightweight macOS menu bar app** that:

- Records mouse movement + clicks and replays them on demand.
- Ships with built-in motion presets — **Circle**, **Figure-8**, **Back-and-forth Line** — each configured with a click-and-drag full-screen overlay.
- Supports three loop modes: **Once**, **Ping-Pong**, **Repeat**.
- Has a **smoothing slider** that cleans up jittery recordings without losing click targeting.
- Has **global hotkeys** for hands-free use (defaults `⌃⌥R` record, `⌃⌥P` play, `⌃⌥X` stop).
- **Auto-cancels playback** the moment you touch the mouse — you're always in control.
- Lives entirely in the menu bar. No dock icon, no windows in the way.
- Requires macOS 14 (Sonoma) or later.
- Distributed direct (not via the App Store). Requires Accessibility permission.

## Pricing & Purchase

- **$2.99 one-time. No free trial.**
- Checkout goes through **Polar.sh**. The "Buy" button links to a Polar checkout URL (store it in a single config constant — the Polar URL will be provided later).
- After purchase, Polar delivers the DMG download link. The site itself does not host the binary and does not need a download route.
- Say the price plainly in the hero and on the button ("Buy for $2.99"). Don't hide it.

## Positioning & Voice

**Cursa is for people making UI demos.** If you've ever tried to screen-record a hover state, a tooltip, a cursor-tracking animation, or a click interaction and ended up with jittery, human-hand motion that distracts from the product — that's the problem Cursa solves. Record a take once, let Cursa smooth and loop it forever, and your demo plays back with cursor motion that looks *designed*, not captured.

Primary target user: designers, developers, and marketers shooting product demos, landing-page hero videos, App Store previews, Dribbble shots, docs GIFs, and conference-talk screen recordings — anything where a cursor is part of the shot.

Why they'll care:
- **Smooth, designed motion** — the smoothing pass removes hand tremor so the cursor glides.
- **Seamless looping** — Ping-Pong and Repeat modes (with seam blending) mean a single take becomes an infinite loop for a hero video or GIF.
- **Pixel-accurate clicks** — clicks stay pinned to the exact recorded position, so they still land on the button even after smoothing.
- **Presets for abstract shots** — when you need a cursor doing a circle or figure-8 over a product shot, the presets give you a mathematically perfect path in seconds.
- **Stays out of the recording** — menu bar only, no dock icon, no windows popping up mid-take.

Not positioned as: a gaming macro tool, a QA automation framework, or a general-purpose scripting suite. It's a demo-recording companion that happens to also be useful for repetitive pointer tasks.

Voice: plainspoken, slightly dry, technically precise. No hype, no emojis, no exclamation marks. Think Panic, Things, Raycast — not a SaaS splash page.

## Page Structure

One long scrollable page, dark mode only. Sections in order:

1. **Nav** — sticky, translucent. Wordmark left; section links and a primary "Buy for $2.99" button right.
2. **Hero** — headline pitched at demo creators (e.g. "Cursor motion that looks designed, not captured."), one-sentence subhead explaining the record-smooth-loop workflow for UI demos, primary CTA (Buy for $2.99 → Polar), small line noting "macOS 14+ · One-time purchase". Visual: a hand-built HTML/CSS mock of a macOS menu bar with the Cursa dropdown open showing real menu items (Record, Play, Loop Mode, Presets, Settings, Quit). No stock screenshots.
3. **Features** — 6 short cards framed around demo-making: *Smooth, Designed Motion*, *Seamless Looping*, *Pixel-Accurate Clicks*, *Motion Presets for Abstract Shots*, *Global Hotkeys (Hands Off the Trackpad)*, *Stays Out of the Shot*.
4. **Use cases / "Built for"** — a short strip calling out the shots Cursa is made for: landing-page hero videos, product demo GIFs, App Store previews, docs screencasts, Dribbble shots, conference-talk recordings. One line each, no images.
5. **Presets showcase** — Circle, Figure-8, Line. Render the motion path for each as an **inline animated SVG** (not video). Short blurb framing each around demo use ("a figure-8 over a product shot", "a clean linear sweep across a feature grid", etc.).
6. **How it works** — three steps: record a take (or pick a preset) → pick a loop mode and crank smoothing → hit record on your screen recorder and let it loop.
7. **FAQ** — `<details>` accordion. Seed with: what you get for $2.99, refund policy (TODO — confirm with Polar's default), does it work with ScreenFlow/QuickTime/Loom/Rotato (yes — it just drives the system cursor), can I loop clicks as well as motion (yes), why Accessibility permission, where recordings are stored, Intel Mac support, is it for games (polite no — it's a demo tool), how to uninstall. Leave unknowns as `TODO:` — don't invent.
8. **Footer** — wordmark, copyright, contact email, privacy link.

Also include a minimal `/privacy` page: the app is local and sends no telemetry; the website uses Vercel Analytics (no cookies); payments are processed by Polar. State plainly.

## Design

- Dark mode only. **Mostly black and white** — near-black background, near-white text, grayscale surfaces and borders. No accent color; let typography and spacing carry the design.
- Generous vertical rhythm. Large hero type. No drop shadows. Subtle 1px borders for surfaces (white at low opacity).
- Motion reserved for the hero menu reveal and the preset SVGs. Respect `prefers-reduced-motion`.
- **Geist** for body and headlines, **Geist Mono** for hotkeys rendered as `<kbd>` and any code. Self-hosted via `next/font` (`geist/font/sans`, `geist/font/mono`).

## SEO & Metadata

- `<title>`: "Cursa — Mouse Automation for macOS"
- Meta description: one sentence, under 160 chars.
- OpenGraph + Twitter cards with a generated OG image (dark background, Cursa wordmark, tagline).
- `robots.txt` and `sitemap.xml` via Next.js conventions.

## Accessibility & Performance

- Keyboard-reachable, visible focus rings, AA contrast, decorative icons marked `aria-hidden`.
- Target Lighthouse 100 across the board on mobile. Achievable because the page is static, image-light, and almost entirely server-rendered.
- No tracking beyond Vercel Analytics. No web fonts beyond the two declared.

## Config Constants

Keep all facts about the app in a single config module so they're trivial to update:

- Polar checkout URL (TODO — will be provided)
- GitHub URL (TODO — or omit if closed source)
- Contact email (TODO)
- Minimum macOS version (14)
- Price ($2.99)

## Out of Scope

- No blog, changelog, or docs site.
- No free trial, no signup, no email capture, no newsletter.
- No i18n, no light mode, no A/B testing.
- No self-hosted download — Polar handles delivery.

## Before Declaring Done

- `pnpm build` clean, no type or lint errors.
- Open the built site in a browser and actually use it. Tab through every interactive element. Resize from 320px to 1920px — no horizontal scroll, no overflowing text.
- Hero menu mock and preset SVGs render and animate.
- Buy button actually opens the Polar checkout URL.

## Open Questions

- Final Polar checkout URL.
- Contact email.
- GitHub URL (if open source).
- Intel Mac support — confirm.
- Final headline/subhead copy — spec suggests a direction; the owner signs off on the exact words.

Leave unresolved items as `TODO:` in config. Do not invent answers.
