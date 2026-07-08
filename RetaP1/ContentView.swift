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

struct ContentView: View {
    // @State keeps this single AudioListener alive for as long as the view
    // exists, so the audio engine inside it isn't destroyed between taps.
    @State private var listener = AudioListener()

    var body: some View {
        // VStack stacks its children vertically; spacing is the gap between them.
        VStack(spacing: 12) {
            Text("Reta")
                .font(.headline)

            Text("Ready to listen.")
                .font(.subheadline)
                .foregroundStyle(.secondary) // muted gray for secondary text

            Button("Start listening") {
                // Ask macOS for permission to use the microphone.
                // The answer does NOT come back on this line — the user has to
                // respond to a dialog first. So we hand requestAccess a "closure"
                // (the { granted in ... } block): a chunk of code it stores and
                // runs LATER, once the user taps Allow/Don't Allow. `granted`
                // is the true/false result passed back to us.
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    if granted {
                        listener.start() // begin capturing mic audio
                    } else {
                        print("Microphone permission denied.")
                    }
                }
            }
            .buttonStyle(.borderedProminent)

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
