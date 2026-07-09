# RetaP1

A learning project on the way to **Reta** — a macOS menu-bar app that helps
college students stay present in lectures through active recall.

This repository is **Phase 1** of that journey: a deliberately minimal macOS app
built to learn Swift, SwiftUI, and the Xcode/Git workflow from the ground up.
Each phase is a separate, self-contained app. The real product is built later,
once the fundamentals are solid.

## What this app does (so far)

Phase 1 is complete. Reta lives in the menu bar (a brain icon, no Dock icon)
and, on "Start listening", captures live microphone audio and transcribes it
in real time — entirely on-device; no audio ever leaves the Mac. The transcript
appears in the popover as you speak, and Stop ends the session cleanly.

How it works, in one line: the microphone feeds an `AVAudioEngine` tap, each
audio buffer is appended to an on-device `SFSpeechRecognizer` request, and its
partial results update an observable `transcript` that SwiftUI redraws live.

## Requirements

- macOS
- Xcode (version 26 or newer)

## How to run it

1. Open `RetaP1.xcodeproj` in Xcode.
2. Press **⌘R** (or the ▶ button) to build and run.
3. No window appears — look for the brain icon in the menu bar (top-right).
4. Click it, then "Start listening" and speak. First run: macOS asks for
   microphone and speech-recognition permission.
5. Quit with the popover's "Quit Reta" button.

## Project layout

```
RetaP1/
├── RetaP1.xcodeproj      Xcode's project database (build settings, file list)
└── RetaP1/               Source code
    ├── RetaP1App.swift      App entry point — the MenuBarExtra scene
    ├── ContentView.swift    The popover UI: transcript, Start/Stop, Quit
    ├── AudioListener.swift  Mic capture + live on-device transcription
    └── Assets.xcassets      Images, colors, and the app icon
```

## The bigger vision (future phases, not built yet)

Reta will listen to a live lecture, transcribe it in real time, and at natural
seams — topic transitions, pauses — surface one short retrieval prompt
("What was the key idea just now?") as a small floating card. Active recall in
the moment, to aid retention. That hard problem (the *timing* of prompts) comes
in later phases.
