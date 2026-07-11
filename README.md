# RetaP1

A learning project on the way to **Reta** — a macOS menu-bar app that helps
college students stay present in lectures through active recall.

This repository is that journey, built phase by phase to learn Swift, SwiftUI,
and the Xcode/Git workflow from the ground up. Phases build on each other in
this one app, and each completed phase is tagged (e.g. `v0.1-phase1`), so any
earlier state is one `git checkout` away.

## What this app does (so far)

Phases 1 and 2 (core) are complete. Reta lives in the menu bar (a brain icon,
no Dock icon) and, on "Start listening", captures live microphone audio and
transcribes it in real time — entirely on-device; no audio ever leaves the Mac.
It detects seams (sustained pauses that end a spoken stretch): each seam seals
the transcript into a paragraph, restarts recognition (avoiding long-session
decay), and shows a small floating prompt card at the top-right — without
stealing keyboard focus. Stop ends the session cleanly.

How it works, in one line: the microphone feeds an `AVAudioEngine` tap, each
audio buffer is appended to an on-device `SFSpeechRecognizer` request, and its
partial results update an observable `transcript` that SwiftUI redraws live;
per-buffer RMS loudness drives the pause detector.

## Known limitations / roadmap

- **Seam detection is loudness-based, and rooms are not silent.** A fixed RMS
  threshold fails in a real lecture hall: background noise (HVAC, shuffling)
  can sit above the threshold, so the teacher's pauses never read as quiet and
  no seams fire. Planned ladder: (1) calibrate the threshold to the room's
  measured noise floor; (2) use "transcript stopped growing for N seconds" as
  the primary seam signal — the recognizer already ignores non-speech; (3) if
  needed, a real voice-activity-detection model.
- The prompt card does not appear over full-screen apps yet (needs panel
  collection-behavior flags).
- The silence threshold (0.005) and pause length (2.0 s) are constants in
  `AudioListener.start()`; tune there for now.
- Prompts are a hard-coded placeholder; generating real questions from the
  sealed paragraph is a later phase (via a server-side LLM endpoint — no API
  keys in the app).

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
    ├── AudioListener.swift  Mic capture, transcription, seam detection
    ├── PromptCard.swift     The floating retrieval-prompt card (NSPanel)
    └── Assets.xcassets      Images, colors, and the app icon
```

## The bigger vision (future phases, not built yet)

Reta will listen to a live lecture, transcribe it in real time, and at natural
seams — topic transitions, pauses — surface one short retrieval prompt
("What was the key idea just now?") as a small floating card. Active recall in
the moment, to aid retention. That hard problem (the *timing* of prompts) comes
in later phases.
