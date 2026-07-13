//
//  PromptCard.swift
//  RetaP1
//
//  The floating retrieval-prompt card. Two-stage when an answer exists:
//  question + "Reveal answer" first (recall before checking!), then the
//  answer + Got it / Missed it self-rating. Template fallback cards have
//  no answer and keep the simple one-button form.
//
//  Sizing strategy: measure the content once and create the panel at that
//  exact size; revealing rebuilds the card at its new size. No live
//  auto-resizing — a window that resizes itself while a delegate repositions
//  it is a feedback loop (that crashed with a stack overflow).
//

import AppKit
import SwiftUI

// What the card looks like (SwiftUI).
struct PromptCardView: View {
    let question: String
    let answer: String?              // nil for fallback template cards
    let isRevealed: Bool
    let onReveal: () -> Void
    let onRated: ((Bool) -> Void)?   // called with true = "Got it"
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick recall")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(question)
                .font(.body)
                // Never truncate: take as many lines as the text needs.
                .fixedSize(horizontal: false, vertical: true)

            if let answer {
                if isRevealed {
                    Divider()
                    Text(answer)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Spacer()
                        Button("Missed it") {
                            onRated?(false)
                            onDismiss()
                        }
                        Button("Got it") {
                            onRated?(true)
                            onDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Recall first: the answer stays hidden until asked for.
                    HStack {
                        Spacer()
                        Button("Reveal answer", action: onReveal)
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                // No answer available (template fallback) — old behavior.
                HStack {
                    Spacer()
                    Button("Got it", action: onDismiss)
                }
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

    func show(question: String, answer: String?, onRated: ((Bool) -> Void)? = nil) {
        present(question: question, answer: answer, revealed: false, onRated: onRated)
    }

    private func present(question: String, answer: String?, revealed: Bool, onRated: ((Bool) -> Void)?) {
        hide() // one card at a time; replaces the old panel

        let view = PromptCardView(
            question: question,
            answer: answer,
            isRevealed: revealed,
            onReveal: { [weak self] in
                // Rebuild the card in its revealed form — the closure captured
                // question/answer/onRated, so it has everything it needs.
                self?.present(question: question, answer: answer, revealed: true, onRated: onRated)
            },
            onRated: onRated,
            onDismiss: { [weak self] in
                self?.hide()
            }
        )

        // NSHostingView is the SwiftUI->AppKit bridge. Measure the content
        // ONCE; the panel is created at exactly that size.
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)

        // .nonactivatingPanel: visible and clickable, but does NOT steal
        // keyboard focus from the app the user is working in.
        // .borderless: no title bar — the SwiftUI card supplies all the looks.
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear      // let the rounded corners show
        panel.level = .floating             // stay above normal windows
        // Follow the user everywhere: appear on whichever Space/desktop is
        // active, including alongside full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting

        // Pin the TOP-left corner just under the menu bar (AppKit's origin is
        // the bottom-left, so taller cards would otherwise climb upward).
        if let screen = NSScreen.main {
            let area = screen.visibleFrame // excludes menu bar and Dock
            panel.setFrameTopLeftPoint(NSPoint(x: area.maxX - 336, y: area.maxY - 16))
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
