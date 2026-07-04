# RetaP1

A learning project on the way to **Reta** — a macOS menu-bar app that helps
college students stay present in lectures through active recall.

This repository is **Phase 1** of that journey: a deliberately minimal macOS app
built to learn Swift, SwiftUI, and the Xcode/Git workflow from the ground up.
Each phase is a separate, self-contained app. The real product is built later,
once the fundamentals are solid.

## What this app does (so far)

Right now it is the default macOS SwiftUI template: a single window that shows a
globe icon and "Hello, world!". The next milestone is turning it into a menu-bar
app that shows a small "Reta" placeholder.

## Requirements

- macOS
- Xcode (version 26 or newer)

## How to run it

1. Open `RetaP1.xcodeproj` in Xcode.
2. Press **⌘R** (or the ▶ button) to build and run.
3. The app window appears; stop it with **⌘.** (command-period).

## Project layout

```
RetaP1/
├── RetaP1.xcodeproj      Xcode's project database (build settings, file list)
└── RetaP1/               Source code
    ├── RetaP1App.swift   App entry point — defines the app and its window
    ├── ContentView.swift The UI shown inside the window
    └── Assets.xcassets   Images, colors, and the app icon
```

## The bigger vision (future phases, not built yet)

Reta will listen to a live lecture, transcribe it in real time, and at natural
seams — topic transitions, pauses — surface one short retrieval prompt
("What was the key idea just now?") as a small floating card. Active recall in
the moment, to aid retention. That hard problem (the *timing* of prompts) comes
in later phases.
