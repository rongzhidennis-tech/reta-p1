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
    // How many seams (sustained pauses) we've noticed this session.
    var seamCount = 0

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

        // Seam tuning. Threshold is a starting guess — tune it against the
        // printed level: values (silence must sit below it, speech above).
        let silenceThreshold: Float = 0.005
        let seamPauseSeconds = 2.0

        // Captured by the tap closure below: a closure keeps the variables it
        // captures ALIVE between calls, so this local persists across buffers,
        // accumulating how long the current quiet stretch has lasted.
        var quietSeconds = 0.0

        // The pipe: every ~0.1s chunk from the mic is appended to the request.
        // (`_` discards the timestamp parameter we don't need.)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            request.append(buffer)

            // Measure this chunk's loudness (RMS): square each sample so
            // negative swings count too, average, square-root. Samples are
            // Float32 in -1...1; silence hovers near 0.
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            var sumOfSquares: Float = 0
            for i in 0..<count {
                sumOfSquares += channel[i] * channel[i]
            }
            let rms = sqrt(sumOfSquares / Float(count))

            if rms < silenceThreshold {
                // Quiet chunk: extend the streak by this buffer's duration.
                let before = quietSeconds
                quietSeconds += Double(buffer.frameLength) / buffer.format.sampleRate
                // Edge trigger: fire exactly once, on the buffer that crosses
                // the line — a longer silence is still just one seam.
                if before < seamPauseSeconds && quietSeconds >= seamPauseSeconds {
                    print("SEAM — \(seamPauseSeconds)s of quiet")
                    DispatchQueue.main.async {
                        self.seamCount += 1
                    }
                }
            } else {
                // Loud chunk: streak broken, re-arm for the next pause.
                quietSeconds = 0
            }
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
            seamCount = 0
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
