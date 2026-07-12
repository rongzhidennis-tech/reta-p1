//
//  PromptMaker.swift
//  RetaP1
//
//  Turns a sealed transcript paragraph into a retrieval prompt, entirely
//  on-device: find the paragraph's key term (most frequent meaty noun via
//  NaturalLanguage part-of-speech tagging) and drop it into a question
//  template. No AI yet — the FoundationModels upgrade replaces this.
//

import NaturalLanguage

// A struct, not a class: no long-lived machinery, no callbacks, no identity —
// just a pure "paragraph in, question out" recipe. Value types suffice.
struct PromptMaker {
    // %@ marks where the key term is inserted (String(format:) placeholder).
    private let templates = [
        "How would you explain \u{201C}%@\u{201D} in one sentence?",
        "What was just said about \u{201C}%@\u{201D}?",
        "Why does \u{201C}%@\u{201D} matter here?",
    ]

    func makePrompt(from paragraph: String) -> String {
        guard let term = keyTerm(in: paragraph),
              let template = templates.randomElement() else {
            // No usable noun found (filler talk) — fall back to the generic ask.
            return "What was the key idea of the last stretch?"
        }
        return String(format: template, term)
    }

    // The paragraph's most frequent non-trivial noun, or nil if there is none.
    private func keyTerm(in text: String) -> String? {
        // NLTagger labels each word with its lexical class (noun/verb/...)
        // using an on-device model.
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        // Count noun occurrences: a dictionary word -> how many times seen.
        var counts: [String: Int] = [:]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                // Skip short filler nouns ("way", "lot", "bit").
                if word.count > 3 {
                    counts[word, default: 0] += 1
                }
            }
            return true // keep enumerating to the end of the text
        }

        // The noun with the highest count wins; nil if counts is empty.
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
