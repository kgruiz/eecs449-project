# Language Assistant architecture

## Current data flow

Authentication -> learner profile + consent -> active session -> finalized
transcript turns -> ended session.

`main.jac` exposes the client app and imports the shared server endpoints.
`frontend.jac` handles authentication, profile setup, participant consent,
speaker selection, typed turns, speech input, and session completion.
`components/FeaturePanels.jac` currently renders a placeholder.

## Shared contracts and ownership

`core/models.jac` defines `LearnerProfile`, `TranscriptTurn`, `Conversation`,
and `SessionView`. A conversation snapshots the learner's languages and
CEFR level at creation, stores its turns, and tracks submitted utterance
seconds and a model-request counter. Selecting an AI partner stores the
mode but does not yet produce an AI response.

Protected endpoints in `endpoints.jac` resolve sessions within the caller's
root. `append_turn(session_id, speaker, text, duration_seconds)` is the
shared handoff for speech adapters and typed input. It accepts learner or
partner turns only while a session is active. Typed turns use zero duration.

## Browser speech input

`components/SpeechInput.jac` uses `SpeechRecognition` or
`webkitSpeechRecognition` with continuous recognition and interim results.
Interim hypotheses stay client-local; finalized utterances are queued for
sequential submission to `append_turn`.

The adapter captures the selected speaker when an utterance first produces
an interim result and measures its duration until finalization. A result
with no prior interim hypothesis can have zero duration. These durations
are estimates, not total microphone-on time or provider billable minutes.
Switching speaker during an open utterance requests finalization for the
previous speaker. Recognition attempts to restart after browser silence
timeouts until stopped. These behaviors are implementation intent and
still need browser verification.

There is no automatic diarization or pause detection. Unsupported browsers
fall back to typed turns. The app does not store raw audio; the browser's
speech service handles transcription.

## Planned integration points

Future feature modules should share authenticated sessions and transcript
contracts and connect their panels through `FeaturePanels.jac`. Preserve
all existing feature imports and panels when integrating another feature.
The intended extended flow is:

Transcript -> requested hint / translation / AI-partner reply -> end
session -> coaching report -> mistake history and optional practice lessons.

`core/ai.jac` loads server-side environment configuration and creates a
byLLM model configuration. It is not imported by the current conversation
flow. Future model calls should use that shared configuration and send
conversation text only as covered by participant consent and the requested
feature. The configured provider/model still needs availability checks.

Translation caching, hint generation, AI-partner responses, coaching,
mistake history, and lessons are not implemented in this checkout.

## Limitations

Text persists in the user's graph; deletion and retention controls are
future work. Provider usage/cost accounting, budgets, latency measurement,
and audio-based pronunciation scoring are also future work. The model
request field currently has no feature call sites that increment it.

The initial four-PR scaffold merge instructions are historical; use the
current checkout's files and interfaces as the integration baseline. See
[the project plan](project-plan.md) for the indicative schedule and product
decisions, and [the README](../README.md) for setup and validation status.
