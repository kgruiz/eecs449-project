# Language Assistant architecture

## Current data flow

Authentication -> learner profile + consent -> active session -> finalized
transcript turns -> ended session.

`main.jac` exposes the client app and imports the shared server endpoints.
`frontend.jac` handles authentication, profile setup, participant consent,
speaker selection, typed turns, speech input, and session completion.
`components/FeaturePanels.jac` currently renders a placeholder.

The web UI uses the Pip visual design through `web.css` and decorative
`components/WebArtwork.jac` components. The active session layout places
the transcript beside the existing speech and typed-turn controls, stacking
them at narrow browser widths. The transcript supports on-demand sentence
translation to English. Hints, AI replies, and practice navigation remain
planned. Speech listening status remains local
to `SpeechInput.jac`; an active session does not imply microphone capture.

`jac.toml` defines `web` (the default app, entry point `main`) and `mobile`
(entry point `mobile.main`). The web app serves the shared API.
`mobile/ConversationApp.jac` implements the native authentication, consent,
profile, and conversation UI using the same server endpoints. The HTML
feature panels are not ported to mobile.

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

## Native mobile speech input

The native `mobile` app does not use a browser microphone.
`mobile/SpeechInput.native.jac` uses `expo-speech-recognition` (Apple Speech on
iOS, SpeechRecognizer on Android) and queues turns for sequential submission
to `append_turn`. Interim text stays on the device; turns carry estimated
durations and the speaker captured at the first interim result. The adapter
requests non-continuous recognition on iOS and continuous recognition on
Android, and restarts while listening remains enabled. If recognition ends
before a final result arrives, it submits the last hypothesis. It ignores
repeated final results when there is no new utterance. The mobile app calls
the same `endpoints.jac` functions; release builds set `base_url` under
`[apps.mobile.client.api]` to the web server.
`mobile/SpeechInput.jac` is the typed-only browser-preview fallback.
`core/speech.jac` shares locale and error helpers between both speech adapters.
These native adapter behaviors still need end-to-end verification.

## Planned integration points

Future feature modules should share authenticated sessions and transcript
contracts and connect their panels through `FeaturePanels.jac`. Preserve
all existing feature imports and panels when integrating another feature.
The intended extended flow is:

Transcript -> requested hint / translation / AI-partner reply -> end
session -> coaching report -> mistake history and optional practice lessons.

`core/ai.jac` provides a server-only Gemini text helper, defaulting to
Gemini 3.5 Flash-Lite. The protected translation endpoint checks ownership,
consent, and that the selected text belongs to the requested turn before
sending it to Gemini. Translations are cached in the browser view only;
the saved transcript remains unchanged.

Persistent translation caching, hint generation, AI-partner responses, coaching,
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
