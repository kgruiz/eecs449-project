# Language Assistant architecture

## Current data flow

Authentication -> learner profile + consent -> active session -> finalized
transcript turns -> ended session.

`main.jac` exposes the client app and imports the shared server endpoints.
`frontend.jac` handles authentication, profile setup, participant consent,
speaker selection, typed turns, speech input, and session completion.
`components/FeaturePanels.jac` is an empty extension slot and is not rendered
in the web conversation view.

The web transcript section also renders `TranscriptDownload`, which uses
`core/transcript.jac` to format the displayed `SessionView` as UTF-8 text.
It sits alongside the session status as a compact download action, works
during or after a session, and is disabled until a turn exists.
Exports include language/CEFR context and speaker-labeled turns in transcript
order. The browser generates the download locally; no additional endpoint,
stored copy, or model request is involved. Native export is not implemented.

The web UI uses the Pip visual design through `web.css` and decorative
`components/WebArtwork.jac` components. The active session layout places
the transcript beside the existing speech and typed-turn controls, stacking
them at narrow browser widths. `TranscriptScroll.jac` keeps the turn list in a
bounded, keyboard-focusable scroll region beneath the header. It follows new
content while within 48 pixels of the bottom, preserves the reader's position
when scrolled up, and offers a Latest button to resume following. A resize
observer also handles translation expansion and viewport changes, and is
disconnected on unmount. The transcript supports on-demand full-turn
translation to English and next-word suggestions. Full-reply hints and AI replies
remain planned. Saved conversation and practice navigation are implemented on web. Speech listening status remains local
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
seconds and a model-request counter. The server accepts an AI-partner mode
but does not produce AI responses. The web selector disables that option
and labels it “coming soon”.

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

There is no acoustic pause detection. Unsupported browsers fall back to typed turns. The app does not store raw audio; the browser's
speech service handles transcription.

## Speaker detection

The learner can optionally enroll a voiceprint by reading a passage
(`components/VoiceSetup.jac` -> `enroll_voice`). The server keeps only a
WeSpeaker embedding (`core/voiceprint.py`, sherpa-onnx), never the audio;
`delete_voice` removes it.

With a voiceprint, `components/audioCapture.js` keeps the last minute of
microphone PCM in memory. Each finalized utterance's audio (from 700 ms
before its first interim result to its final result) is sent once as a
16 kHz WAV to `append_spoken_turn`, which scores it against the voiceprint
(cosine >= `SPEAKER_MATCH_THRESHOLD`, default 0.5, means learner) and
discards it. Speech under ~1 s, or a scoring failure, falls back to
alternating with the previous turn (`speaker_source = "turn-taking"`, shown
as "guessed"). The learner can click a turn's speaker to correct it
(`set_turn_speaker`). Typed turns and sessions without a voiceprint use the
manually selected speaker. An utterance in which both people speak without a
pause is attributed as a whole.

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

## Next-word suggestions

`components/WordHelper.jac` (web only) treats the learner as struggling
when their in-progress sentence stays unchanged for four seconds while
"Me" is the selected speaker. The in-progress sentence is the typed
composer text, or else the learner's interim speech that `SpeechInput.jac`
reports through `onDraft` (then the finalized utterance). With voice enrollment,
the speaker is unknown during interim speech, so spoken suggestions wait for
the server-attributed finalized turn instead of using the typed-turn picker. Sentences ending
in `.`, `!`, or `?` do not trigger, and the learner can turn automatic
suggestions off or tap "Suggest a word" at any time.

`suggest_word(session_id, partial_sentence)` checks ownership, an active
session, and consent, then calls `suggest_next_word` in `core/hints.jac`
with the partial sentence, the last 12 turns, the session languages, and
CEFR level. It returns a `WordHint` (target-language word plus a short
native-language meaning) and increments `model_requests`. Drafts and hints
are never saved as transcript turns. A hint that arrives after the learner
keeps going is discarded.

Limitations: browsers often finalize speech after a short silence, so a
pause may be detected on the finalized utterance rather than mid-utterance;
an unchanged learner utterance can trigger a hint even if it was complete
but unpunctuated. Suggestion quality, latency, and the mobile client are
unverified or not implemented.

## Planned integration points

Future feature modules should share authenticated sessions and transcript
contracts and connect their panels through `FeaturePanels.jac`. Preserve
all existing feature imports and panels when integrating another feature.
The intended extended flow is:

Transcript -> requested hint / translation / AI-partner reply -> end
session -> coaching report -> mistake history and optional practice lessons.

`core/ai.jac` provides a server-only Jac byLLM translation, using
Gemini 3.5 Flash-Lite. The protected translation endpoint checks ownership,
consent, and that the selected text belongs to the requested turn before
sending it to Gemini. Translations are cached in the browser view only;
the saved transcript remains unchanged. Each turn has an icon-only action
with hover/focus tooltips. The original remains visible while English appears
below it with a labeled accent rule. Toggling visibility reuses the cached
translation; loading and retry states belong to each turn.

Persistent translation caching, full-reply hint generation, AI-partner responses,
mistake history, and lessons are not implemented in this checkout.

## Limitations

Text persists in the user's graph; deletion and retention controls are
future work. Provider usage/cost accounting, budgets, latency measurement,
and audio-based pronunciation scoring are also future work. The model
request field is incremented by next-word suggestions and attempted coaching calls.

The initial four-PR scaffold merge instructions are historical; use the
current checkout's files and interfaces as the integration baseline. See
[the project plan](project-plan.md) for the indicative schedule and product
decisions, and [the README](../README.md) for setup and validation status.

## Post-conversation coaching

`core/coaching.jac` uses the shared server-only Gemini model to return a typed
`CoachingReport`. `conversation_feedback` resolves an owned session and requires
completion, consent, and learner text before generating a report. It validates
nonempty fields, list limits, and exact learner-quote/turn-ID matches before saving
the report on `Conversation`. `SessionView` includes the optional saved report.
Failed generation leaves the transcript ended and retryable. Successful sequential
requests return the cached report; there is no distributed in-flight request lock.

Web and mobile `CoachingPanel` components request feedback after completion,
render summary/strengths/practice priorities, and expose retry on failure. A report
is not a transcript turn and is not included in the existing text download.
Speech adapters report listening/finalization/save activity so End conversation
stays disabled until the learner stops listening and outstanding saves finish.
The server rejects speaker corrections after completion to preserve report evidence.
Real microphone timing and native-device presentation still require verification.

## Web conversation library

`list_conversations(offset, limit)` traverses only the authenticated caller's
root and returns bounded `ConversationSummary` records for completed sessions.
`core/history.jac` sorts by the saved UTC `created_at`, with undated legacy
sessions last. List records contain opening-turn titles and short previews;
full transcripts and coaching are fetched with the existing owned-session API.
New sessions record creation time, while old sessions default to an empty date.
The UI formats dates in the browser's local timezone.

`frontend.jac` owns Talk state separately from `components/Conversations.jac`.
Navigating away unmounts live controls only after speech activity has settled,
while preserving the session and draft in the parent. Completion clears the
live workspace and opens the ended session in Conversations. Overview and
Practice share one mounted coaching component, so switching detail sections
does not regenerate feedback. Transcript has its own view and retains export
and translation. The completed library is paginated; its page selection is
local state. Active-session recovery after reload and deep links remain future
work. Native mobile still uses its existing conversation/recap screen.
