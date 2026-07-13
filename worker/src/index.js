// reta-prompts Worker, step (b): authenticated, and the question now comes
// from Claude reading the sealed paragraph. The Anthropic API key lives ONLY
// in a Worker secret (env.ANTHROPIC_API_KEY) — never in this file.

// The instructions Claude follows for every request. Iterating on this text
// is step (c) — the quality bar: specific to the transcript, answerable in
// one line, varied in type.
const INSTRUCTIONS = `You write retrieval-practice questions for a student
listening to a live lecture. The user message is a rough live transcript of
the last stretch of the lecture; it may contain transcription errors and
poor punctuation.

Produce exactly ONE short question and its model answer:
- the question is specifically about the content of this transcript (name
  its concepts) and varies in style across calls: key idea, why/how,
  explain-it-back, or predict-what-comes-next;
- the answer is ONE line, and must be verifiable from the transcript alone -
  if the transcript doesn't contain the answer, ask about what it does
  contain instead.`;

// Structured output: the API constrains generation to this exact shape, so
// the reply is guaranteed parseable - no prose, no preamble, ever.
const OUTPUT_FORMAT = {
  type: "json_schema",
  schema: {
    type: "object",
    properties: {
      question: { type: "string" },
      answer: { type: "string" },
    },
    required: ["question", "answer"],
    additionalProperties: false,
  },
};

export default {
  async fetch(request, env) {
    // The lock: reject anyone who doesn't present the shared token.
    const auth = request.headers.get("Authorization");
    if (auth !== `Bearer ${env.AUTH_TOKEN}`) {
      return Response.json({ error: "unauthorized" }, { status: 401 });
    }

    if (request.method !== "POST") {
      return Response.json({ error: "POST only" }, { status: 405 });
    }

    let paragraph = "";
    try {
      const body = await request.json();
      paragraph = (body.paragraph ?? "").trim();
    } catch {
      return Response.json({ error: "body must be JSON" }, { status: 400 });
    }
    if (paragraph === "") {
      return Response.json({ error: "paragraph is empty" }, { status: 400 });
    }

    // Call the Claude API. The Worker is a CLIENT here — same fetch/JSON
    // dance the Mac app does to us, one hop further down the chain.
    const apiResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY, // injected from the Worker secret
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5", // fastest tier; fits the ~2s card budget
        max_tokens: 300,           // one question + one-line answer
        system: INSTRUCTIONS,      // standing instructions, separate from data
        output_config: { format: OUTPUT_FORMAT },
        messages: [{ role: "user", content: paragraph }],
      }),
    });

    if (!apiResponse.ok) {
      // Don't leak upstream details to callers; log them for us instead.
      console.error("Claude API error", apiResponse.status, await apiResponse.text());
      return Response.json({ error: "generation failed" }, { status: 502 });
    }

    const data = await apiResponse.json();
    // The reply's content is a list of blocks; with structured output, the
    // text block is guaranteed to be JSON matching OUTPUT_FORMAT's schema.
    const text = data.content?.find((block) => block.type === "text")?.text;
    let generated;
    try {
      generated = JSON.parse(text);
    } catch {
      // Belt and suspenders (e.g. a safety refusal has no schema guarantee):
      // any unparseable reply becomes a 502, which the app turns into the
      // template fallback card.
      console.error("unparseable model reply", text);
      return Response.json({ error: "no question generated" }, { status: 502 });
    }

    return Response.json({
      question: generated.question.trim(),
      answer: generated.answer.trim(),
    });
  },
};
