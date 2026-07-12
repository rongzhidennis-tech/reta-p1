//
//  AudioListener.swift
//  RetaP1
//
//  Captures live microphone audio, transcribes it on-device, and detects
//  seams. A seam is "no NEW WORDS for a while" — not "no sound" — so it
//  keeps working in rooms that are never actually silent: the recognizer
//  already ignores background noise for us.
//

import AVFoundation
import Speech
import Observation

@Observable
class AudioListener {
    // The live text. The popover reads this; updating it updates the screen.
    var transcript = ""
    // Whether we're currently capturing; drives the Start/Stop button label.
    var isListening = false
    // How many seams (pauses that ended a spoken stretch) this session.
    var seamCount = 0

    // Long-lived machinery (properties, so they outlive start()):
    private let engine = AVAudioEngine()
    private let promptCard = PromptCard()
    private let promptMaker = PromptMaker()
    private let promptService = PromptService()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Transcript structure: paragraphs sealed at seams + the live segment.
    private var finishedText = ""
    private var currentSegment = ""
    // Results from a retired segment carry an old number and get ignored.
    private var segmentGeneration = 0

    // Seam detection: when did the transcript last actually change?
    private let seamPauseSeconds = 2.0
    private var lastNewText = Date()
    private var seamTimer: Timer?

    func start() {
        // Installing a second tap while running would crash; bail if already on.
        guard !engine.isRunning else { return }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            print("Speech recognition not available for en-US on this Mac.")
            return
        }
        self.recognizer = recognizer

        let inputNode = engine.inputNode
        guard inputNode.inputFormat(forBus: 0).sampleRate > 0 else {
            print("No usable microphone input (sampleRate is 0).")
            return
        }

        // The tap is pure plumbing now: every chunk goes to the CURRENT
        // segment's request (a property — it's replaced at each seam).
        // [weak self] breaks the engine -> closure -> self -> engine loop.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        // Fresh session state.
        finishedText = ""
        currentSegment = ""
        transcript = ""
        seamCount = 0
        lastNewText = Date()
        beginRecognitionSegment()

        // A repeating check on the main thread: has speech gone quiet long
        // enough? (A seam is the ABSENCE of callbacks — nothing arrives to
        // notify us of nothing, so we poll twice a second.)
        seamTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForSeam()
        }

        engine.prepare()
        do {
            try engine.start()
            isListening = true
            print("Audio engine started.")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        guard engine.isRunning else { return }

        seamTimer?.invalidate() // a Timer keeps firing until told to stop
        seamTimer = nil

        // Teardown mirrors setup, in order:
        engine.inputNode.removeTap(onBus: 0) // 1. stop new buffers entering
        engine.stop()                        // 2. release the microphone
        request?.endAudio()                  // 3. let recognition finish politely

        request = nil
        task = nil
        isListening = false
        promptCard.hide() // no stale card lingering after a session
    }

    // One recognition task runs seam-to-seam, never longer — sidestepping
    // the recognizer's decay over long continuous sessions.
    private func beginRecognitionSegment() {
        segmentGeneration += 1
        let generation = segmentGeneration // stamped into this task's callbacks

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true // audio never leaves this Mac
        request.shouldReportPartialResults = true  // refine as we go
        self.request = request

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                // Stale-result guard: drop late results from retired tasks.
                guard let self, generation == self.segmentGeneration else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    // Only a CHANGE counts as speech — this timestamp is the
                    // seam detector's whole input signal.
                    if text != self.currentSegment {
                        self.currentSegment = text
                        self.lastNewText = Date()
                        self.transcript = self.finishedText + text
                    }
                }
                if let error {
                    print("Recognition error: \(error.localizedDescription)")
                }
            }
        }
    }

    // Runs twice a second (main thread). All three conditions must hold:
    // we're listening, something was said, and no new words for the pause.
    // No edge-trigger logic needed: sealing empties currentSegment, which
    // blocks re-firing until speech resumes.
    private func checkForSeam() {
        guard isListening,
              !currentSegment.isEmpty,
              Date().timeIntervalSince(lastNewText) >= seamPauseSeconds
        else { return }
        handleSeam()
    }

    private func handleSeam() {
        seamCount += 1

        // Seal the segment into a finished paragraph (keep a copy — the
        // prompt is generated FROM this text).
        let sealed = currentSegment
        finishedText += sealed + "\n\n"
        currentSegment = ""
        transcript = finishedText

        // Retire this segment's task; start the next one fresh.
        request?.endAudio()
        beginRecognitionSegment()

        // Ask the Worker for a question about what was just said; if anything
        // goes wrong, fall back to the on-device template. The card must
        // never fail to appear.
        // Task { } opens an async context from synchronous code — the seam
        // handling finishes immediately; this block runs alongside it.
        Task {
            do {
                let question = try await promptService.fetchQuestion(about: sealed)
                print("question from Worker: \(question)")
                promptCard.show(prompt: question)
            } catch {
                print("Prompt service failed (\(error.localizedDescription)) — using fallback.")
                promptCard.show(prompt: promptMaker.makePrompt(from: sealed))
            }
        }
    }
}
