//
//  AudioListener.swift
//  RetaP1
//
//  Captures live microphone audio, transcribes it on-device, and detects
//  seams (sustained pauses). Each seam seals the current transcript segment
//  into a paragraph, restarts recognition (so no task runs long enough to
//  decay), and shows the floating prompt card.
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
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Transcript structure: paragraphs sealed at seams + the live segment.
    private var finishedText = ""
    private var currentSegment = ""
    // Stamped into every recognition callback; results carrying an old
    // number are from a retired segment and get ignored (stale-result guard).
    private var segmentGeneration = 0

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

        // Seam tuning. Threshold is a starting guess — tune it against
        // measured levels (silence must sit below it, speech above).
        let silenceThreshold: Float = 0.005
        let seamPauseSeconds = 2.0
        // Captured by the tap closure; persists across buffers (closures keep
        // their captured variables alive).
        var quietSeconds = 0.0

        // [weak self]: the engine holds this closure and the closure uses self,
        // while self holds the engine — a reference loop. weak breaks it.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard let self else { return }

            // Append to the CURRENT segment's request. This must read the
            // property each time — the request is replaced at every seam, and
            // a captured local would keep feeding the retired one forever.
            self.request?.append(buffer)

            // Loudness (RMS): square each sample so negative swings count,
            // average, square-root. Samples are Float32 in -1...1.
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            var sumOfSquares: Float = 0
            for i in 0..<count {
                sumOfSquares += channel[i] * channel[i]
            }
            let rms = sqrt(sumOfSquares / Float(count))

            if rms < silenceThreshold {
                let before = quietSeconds
                quietSeconds += Double(buffer.frameLength) / buffer.format.sampleRate
                // Edge trigger: fire once, on the buffer that crosses the line.
                if before < seamPauseSeconds && quietSeconds >= seamPauseSeconds {
                    DispatchQueue.main.async {
                        self.handleSeam()
                    }
                }
            } else {
                quietSeconds = 0 // streak broken; re-arm for the next pause
            }
        }

        // Fresh session state.
        finishedText = ""
        currentSegment = ""
        transcript = ""
        seamCount = 0
        beginRecognitionSegment()

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
                // Stale-result guard: a retired task's last result can arrive
                // after the next segment began; its old stamp gets it dropped.
                guard let self, generation == self.segmentGeneration else { return }
                if let result {
                    self.currentSegment = result.bestTranscription.formattedString
                    self.transcript = self.finishedText + self.currentSegment
                }
                if let error {
                    print("Recognition error: \(error.localizedDescription)")
                }
            }
        }
    }

    // Runs on the main thread, once per detected pause.
    private func handleSeam() {
        // A pause with nothing said isn't a seam — nothing to seal, nothing
        // to recall. (Also means silence-only stretches show no card.)
        guard !currentSegment.isEmpty else { return }

        seamCount += 1

        // Seal the segment into a finished paragraph.
        finishedText += currentSegment + "\n\n"
        currentSegment = ""
        transcript = finishedText

        // Retire this segment's task; start the next one fresh.
        request?.endAudio()
        beginRecognitionSegment()

        // Placeholder prompt — a later phase generates a real question from
        // the paragraph just sealed.
        promptCard.show(prompt: "What was the key idea of the last stretch?")
    }
}
