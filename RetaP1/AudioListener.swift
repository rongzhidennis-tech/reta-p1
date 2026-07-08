//
//  AudioListener.swift
//  RetaP1
//
//  Owns the microphone capture engine. For now its only job is to prove
//  that live audio is flowing, by logging each buffer of samples it receives.
//

import AVFoundation

class AudioListener {
    // AVAudioEngine is Apple's graph of audio "nodes" (mic, effects, output...).
    // We hold ONE instance for the app's lifetime. If this were a local variable
    // it would be destroyed the moment start() returned, and no audio would flow.
    private let engine = AVAudioEngine()

    func start() {
        // Installing a tap while already running would crash, so bail if we're on.
        guard !engine.isRunning else { return }

        let inputNode = engine.inputNode

        // Diagnostics: the mic node has a format on its input (hardware) side and
        // its output (downstream) side. If they disagree, that's usually the root
        // of format errors — so we log both.
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = inputNode.outputFormat(forBus: 0)
        print("mic inputFormat:  \(inputFormat)")
        print("mic outputFormat: \(outputFormat)")

        // If no microphone is available/selected, sampleRate comes back as 0.
        guard inputFormat.sampleRate > 0 else {
            print("No usable microphone input (sampleRate is 0).")
            return
        }

        // A "tap" is a probe on the node: macOS hands us each incoming buffer as
        // audio flows, without disturbing the stream. This closure runs over and
        // over, on a background audio thread — once per buffer.
        //
        // format: nil = adopt the mic node's OWN format. Handing in a format that
        // doesn't exactly match crashes with "Failed to create tap due to format
        // mismatch". (bufferSize is only a hint; the system may hand a different size.)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, when in
            // frameLength = how many samples are in THIS chunk.
            print("audio buffer: \(buffer.frameLength) samples")
        }

        // prepare() allocates the engine's resources and negotiates formats across
        // the graph BEFORE starting. Skipping it is a common cause of the -10868
        // "format not supported" error when the engine spins up the input chain.
        engine.prepare()

        do {
            try engine.start()
            print("Audio engine started.")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
}
