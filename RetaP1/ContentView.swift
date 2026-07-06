//
//  ContentView.swift
//  RetaP1
//
//  Created by RongzhiChen on 7/2/26.
//

import SwiftUI
import AppKit // AppKit is the older macOS UI framework SwiftUI is built on;
             // we reach into it for NSApplication to quit the app.

struct ContentView: View {
    var body: some View {
        // VStack stacks its children vertically; spacing is the gap between them.
        VStack(spacing: 12) {
            Text("Reta")
                .font(.headline)

            Text("Ready to listen.")
                .font(.subheadline)
                .foregroundStyle(.secondary) // muted gray for secondary text

            Button("Start listening") {
                // Placeholder: Phase 1 will start audio capture + transcription here.
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
