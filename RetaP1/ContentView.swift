//
//  ContentView.swift
//  RetaP1
//
//  Created by RongzhiChen on 7/2/26.
//

import SwiftUI
import AppKit // AppKit is the older macOS UI framework SwiftUI is built on;
             // we reach into it for NSApplication to quit the app.
import AVFoundation // Apple's audio/video framework; AVCaptureDevice lives here.
import Speech // Apple's on-device/server speech recognition; SFSpeechRecognizer lives here.

struct ContentView: View {
    // @State keeps this single AudioListener alive for as long as the view
    // exists, so the audio engine inside it isn't destroyed between taps.
    @State private var listener = AudioListener()

    var body: some View {
        // VStack stacks its children vertically; spacing is the gap between them.
        VStack(spacing: 12) {
            Text("Reta")
                .font(.headline)

            // Show the live transcript once there is one; a hint until then.
            // SwiftUI re-runs this body whenever listener.transcript changes
            // (that's @Observable at work), so the text updates as you speak.
            if listener.transcript.isEmpty {
                Text(listener.isListening ? "Listening…" : "Ready to listen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary) // muted gray for secondary text
            } else {
                ScrollView {
                    Text(listener.transcript)
                        .font(.subheadline)
                        // fill the card's width, text ragged-right
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120) // keep the card compact; long text scrolls

                Text("Seams noticed: \(listener.seamCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if listener.gotCount + listener.missedCount > 0 {
                    Text("Recall: \(listener.gotCount) ✓  \(listener.missedCount) ✗")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(listener.isListening ? "Stop" : "Start listening") {
                if listener.isListening {
                    listener.stop()
                } else {
                    // Permission chain: ask for speech recognition, then (inside
                    // its callback) for the microphone, then (inside THAT one)
                    // hop to the main thread and start. Both prompts only ever
                    // appear once; afterwards macOS answers instantly.
                    SFSpeechRecognizer.requestAuthorization { status in
                        guard status == .authorized else {
                            print("Speech recognition not authorized.")
                            return
                        }
                        AVCaptureDevice.requestAccess(for: .audio) { granted in
                            guard granted else {
                                print("Microphone permission denied.")
                                return
                            }
                            DispatchQueue.main.async {
                                listener.start()
                            }
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(listener.isListening ? .red : .accentColor) // red while recording

            Divider() // a thin horizontal line separating the main action from utilities

            Button("Quit Reta") {
                // NSApplication.shared is the single running app instance;
                // .terminate(nil) asks macOS to quit it (nil = "no specific sender").
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless) // visually secondary, since quitting isn't the main action
        }
        .padding()
        .frame(width: 240) // give the popover a fixed, sensible width
    }
}

#Preview {
    ContentView()
}
