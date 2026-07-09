# CLAUDE.md — Reta

## What this project is
Reta is a macOS menu-bar app for motivated college students. It listens to a live
lecture, transcribes it in real time, and at natural seams (topic transitions,
pauses) shows ONE short retrieval prompt as a small floating card — active recall
in the moment. The hard core of the product is the *timing* of prompts.
Current status: Phase 2 (seam detection — pause-based prompt timing; Phase 1,
live capture + on-device transcription, is complete and tagged v0.1-phase1).

## Who you're working with
A first-time developer whose explicit goal is to learn to build software properly,
not just ship. Not in a rush. Understanding beats speed.

## Working agreement (always follow)
1. Small steps: one concept or change at a time. Never large multi-file scaffolds.
2. Explain before and after: what we're about to do and why; then what each
   non-obvious part of the code does.
3. Never let me accept code I don't understand. Answer "why" patiently.
4. Simple version first; then say what the industry-standard version adds and
   when it would matter.
5. Ask me to run/verify each step before stacking the next.
6. Commit to Git at every working checkpoint, with clear commit messages.
7. If I ask for something premature or unwise, say so directly instead of doing it.

## Technical ground rules
- Native Swift/SwiftUI; Apple frameworks first (AVFoundation, Speech).
- No API keys in the app — any LLM calls go through a server-side endpoint (later phase).
- Prefer on-device processing where possible (privacy matters for a listening app).
