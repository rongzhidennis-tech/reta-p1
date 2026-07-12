// reta-prompts Worker, step (a): prove the pipe with a hard-coded question.
// Step (b) replaces the hard-coded string with a Claude API call.

export default {
  // Cloudflare calls this function once per incoming HTTP request —
  // the Worker equivalent of our audio tap closure.
  async fetch(request) {
    // Only accept POST (the app will POST the sealed paragraph).
    if (request.method !== "POST") {
      return Response.json({ error: "POST only" }, { status: 405 });
    }

    // Read the request body; expect JSON like {"paragraph": "..."}.
    // Ignored for now — but parsing it already proves the app can send it.
    let paragraph = "";
    try {
      const body = await request.json();
      paragraph = body.paragraph ?? "";
    } catch {
      return Response.json({ error: "body must be JSON" }, { status: 400 });
    }

    // Step (a): hard-coded. The echo of the paragraph's length lets the app
    // side verify that the text actually arrived intact.
    return Response.json({
      question: "What was the key idea of the last stretch?",
      receivedCharacters: paragraph.length,
    });
  },
};
