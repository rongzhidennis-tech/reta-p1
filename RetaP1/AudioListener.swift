//
//  AudioListener.swift
//  RetaP1
//
//  Captures live microphone audio and transcribes it as the user speaks:
//  mic -> AVAudioEngine tap -> buffers appended to a speech request ->
//  partial transcripts published to the UI via the observable `transcript`.
//

import AVFoundation
import Speech
import Observation

// @Observable lets SwiftUI watch this class: any view that reads `transcript`
// is automatically redrawn whenever `transcript` changes.
@Observable
class AudioListener {
    // The live text. The popover reads this; updating it updates the screen.
    var transcript = ""
    // Whether we're currently capturing; drives the Start/Stop button label.
    var isListening = false

    // Long-lived machinery (properties, so they outlive start()):
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() {
        // Installing a second tap while running would crash; bail if already on.
        guard !engine.isRunning else { return }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            print("Speech recognition not available for en-US on this Mac.")
            return
        }
        self.recognizer = recognizer
        print("Supports on-device recognition: \(recognizer.supportsOnDeviceRecognition)")

        let inputNode = engine.inputNode
        guard inputNode.inputFormat(forBus: 0).sampleRate > 0 else {
            print("No usable microphone input (sampleRate is 0).")
            return
        }

        // The live twin of FileTranscriber's URL request: instead of pointing at
        // a finished file, it's an open-ended request we keep feeding buffers.
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true // audio never leaves this Mac
        request.shouldReportPartialResults = true  // refine the transcript as we go
        self.request = request // kept as a property so stop() can call endAudio()

        // The pipe: every ~0.1s chunk from the mic is appended to the request.
        // (`_` discards the timestamp parameter we don't need.)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            request.append(buffer)
        }

        // Same result closure as FileTranscriber — called once per refined guess.
        // It arrives on a background thread; transcript drives the UI, so we hop
        // to the main thread before writing it.
        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            if let error {
                print("Recognition error: \(error.localizedDescription)")
            }
        }

        engine.prepare()
        do {
            try engine.start()
            isListening = true
            transcript = "" // fresh session, fresh transcript
            print("Audio engine started.")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        guard engine.isRunning else { return }

        // Teardown mirrors setup, in order:
        engine.inputNode.removeTap(onBus: 0) // 1. stop new buffers entering the pipe
        engine.stop()                        // 2. release the microphone hardware
        request?.endAudio()                  // 3. "no more audio" — recognizer finishes
                                             //    politely and delivers its final result

        // Drop our references; a new start() builds fresh ones.
        request = nil
        task = nil
        isListening = false
    }
}
