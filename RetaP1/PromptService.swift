//
//  PromptService.swift
//  RetaP1
//
//  Talks to the reta-prompts Worker: POSTs a sealed paragraph, gets back a
//  retrieval question. Swapping `endpoint` is how we'll benchmark other
//  backends (e.g. a local Ollama server) against the same code.
//

import Foundation

struct PromptService {
    private let endpoint = URL(string: "https://reta-prompts.rongzhichen.workers.dev")!

    // Codable: a struct that Swift can convert to/from JSON automatically,
    // as long as its property names match the JSON keys.
    private struct RequestBody: Codable {
        let paragraph: String            // -> {"paragraph": "..."}
    }
    private struct ResponseBody: Codable {
        let question: String             // <- {"question": "...", "answer": "..."}
        let answer: String
    }

    // `async` = calling this may involve waiting (the network round trip);
    // `throws` = it can fail (no network, bad response). The caller must
    // acknowledge both with `try await`. Returns a named tuple: two values
    // travelling together, addressed as .question and .answer.
    func fetchPrompt(about paragraph: String) async throws -> (question: String, answer: String) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        // A prompt that arrives late is worthless — the lecture has moved on.
        // If no answer within 3s, URLSession throws, and the caller's catch
        // shows the template fallback instead. (Default would be 60s.)
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The shared token the Worker requires (see Secrets.swift, gitignored).
        request.setValue("Bearer \(Secrets.workerToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RequestBody(paragraph: paragraph))

        // The wait happens HERE: the function pauses (without blocking any
        // thread) until the response arrives, then resumes on the next line.
        let (data, _) = try await URLSession.shared.data(for: request)

        let body = try JSONDecoder().decode(ResponseBody.self, from: data)
        return (question: body.question, answer: body.answer)
    }
}
