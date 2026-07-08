//
//  FileTranscriber.swift
//  RetaP1
//
//  Transcribes a bundled audio file with Apple's Speech framework.
//  A stepping stone: it exercises the exact recognizer machinery live
//  transcription will use, without needing a microphone.
//

import Speech

class FileTranscriber {
    // The recognizer and task must outlive the function that starts them
    // (results arrive later, asynchronously), so they live here as properties.
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?

    func transcribeBundledSample() {
        // A recognizer is tied to one language. Our test file is English.
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            print("Speech recognition not available for en-US on this Mac.")
            return
        }
        self.recognizer = recognizer

        // Can this Mac transcribe WITHOUT sending audio to Apple's servers?
        print("Supports on-device recognition: \(recognizer.supportsOnDeviceRecognition)")

        // Find the audio file Xcode bundled into the app.
        guard let url = Bundle.main.url(forResource: "test-lecture", withExtension: "aiff") else {
            print("test-lecture.aiff not found in app bundle.")
            return
        }

        // "Transcribe this file." (Live audio will use a different request type,
        // SFSpeechAudioBufferRecognitionRequest, fed by our microphone tap.)
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true // privacy: never leave this Mac
        request.shouldReportPartialResults = true  // stream refining guesses, not one final answer

        // The task runs asynchronously; this closure is called MANY times —
        // each partial result is its current best guess at the WHOLE transcript.
        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                let label = result.isFinal ? "FINAL" : "partial"
                print("\(label): \(result.bestTranscription.formattedString)")
            }
            if let error {
                print("Recognition error: \(error.localizedDescription)")
            }
        }
    }
}
