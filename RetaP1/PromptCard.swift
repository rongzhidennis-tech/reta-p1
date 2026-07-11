//
//  PromptCard.swift
//  RetaP1
//
//  The floating retrieval-prompt card. Shown at a seam, near the menu bar,
//  WITHOUT stealing keyboard focus from whatever the user is doing.
//

import AppKit
import SwiftUI

// What the card looks like (SwiftUI).
struct PromptCardView: View {
    let prompt: String
    // A closure stored as a property: the card doesn't know HOW to dismiss
    // itself — its owner hands it the instructions, same way we hand Apple's
    // APIs closures. Now we're the ones designing that pattern.
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick recall")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(prompt)
                .font(.body)
            HStack {
                Spacer() // pushes the button to the trailing edge
                Button("Got it", action: onDismiss)
            }
        }
        .padding(16)
        .frame(width: 320)
        // regularMaterial = the frosted-glass background macOS panels use
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// How the card gets on screen (AppKit).
class PromptCard {
    private var panel: NSPanel?

    func show(prompt: String) {
        hide() // one card at a time; a new seam replaces the old card

        let view = PromptCardView(prompt: prompt) { [weak self] in
            self?.hide()
        }

        // .nonactivatingPanel: visible and clickable, but does NOT steal
        // keyboard focus from the app the user is working in.
        // .borderless: no title bar — the SwiftUI card supplies all the looks.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear      // let the rounded corners show
        panel.level = .floating             // stay above normal windows
        // Follow the user everywhere: appear on whichever Space/desktop is
        // active, including alongside full-screen apps (a student watching
        // full-screen slides is the main use case).
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // NSHostingView is the SwiftUI->AppKit bridge: wraps our SwiftUI view
        // so the panel can display it.
        panel.contentView = NSHostingView(rootView: view)

        // Position: top-right of the screen, just under the menu bar.
        // AppKit's origin is the BOTTOM-left; y grows upward, so "top" = maxY.
        if let screen = NSScreen.main {
            let area = screen.visibleFrame // excludes menu bar and Dock
            panel.setFrameOrigin(NSPoint(x: area.maxX - 336, y: area.maxY - 136))
        }

        // Show it without activating our app (keeps the user's focus put).
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil) // remove from screen
        panel = nil
    }
}
