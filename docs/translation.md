# Tap-to-translate scaffold

`request_translation(session_id, turn_id="", destination_language="")`
translates the latest finalized partner turn by default. A supplied turn ID
selects any finalized turn in the caller's conversation. The destination
language defaults to the session's native language snapshot. It works during
or after a conversation and does not change the transcript.

The private graph cache keys on session, turn ID, source text and destination
language. Repeated requests reuse the cached text without another Gemini
call. A cache miss increments the successful model request counter. No
continuous or automatic translation is performed.

The panel supports a latest-partner button and a turn selector, displaying
the source alongside its translation. Native-language rendering and the
read-only result let the learner return to the conversation immediately.

## Next steps

- Make transcript sentences directly tappable in the mic/ASR UI.
- Cache retention, bounded lookup/indexing and concurrent miss deduplication.
- Provider timeout/retry behavior and learner correction feedback.
- Accessibility and real conversation evaluation after testing is authorized.

Based only on `codex/jac-foundation`; no live-assist/coaching dependencies.
Retain other panel imports/render pairs in FeaturePanels.jac when merging.
No tests, compiler checks, app runs or Gemini requests have been performed,
per request.
