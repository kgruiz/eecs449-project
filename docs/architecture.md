# Week 6 architecture

## Four independent PRs

1. `codex/jac-foundation` -> `main`: generated Jac web app, private learner
   graph, consent, sessions, transcript and shared Gemini configuration.
2. `codex/live-assist` -> `codex/jac-foundation`: on-demand level-aware hints
   and AI-partner endpoint/panel.
3. `codex/tap-to-translate` -> `codex/jac-foundation`: latest partner sentence
   or selected turn translation with a session-scoped cache.
4. `codex/conversation-coaching` -> `codex/jac-foundation`: text-evidence
   feedback, mistake history and tailored practice contracts.

Merge initialization first, then retarget the three independent feature PRs
to main. Each feature touches its own module and one import/render pair in
`FeaturePanels.jac`. When merging multiple features, keep all feature imports
and panels and remove the foundation placeholder. Resolve that small shared
slot without discarding previously merged panels. Features share no feature
code dependencies.

## Pipeline

Consent + learner profile -> session -> finalized transcript -> requested
hint / translation -> end session -> coaching.

`append_turn(session_id, speaker, text, duration_seconds)` is the ASR
handoff. `components/SpeechInput.jac` uses the browser Web Speech API
(continuous, interim results): interim hypotheses stay client-local and each
finalized utterance is submitted once, in order, with the speaker selected
when the utterance began and a duration measured from its first interim
result to finalization, so durations never overlap. Switching speaker
mid-utterance flushes it to the previous speaker. Recognition restarts after
browser silence timeouts until the learner stops it. Manual turns have zero
duration. There is no automatic diarization or pause detection, and Chrome/
Edge send audio to their speech provider; raw audio is never stored here.
Browsers without the API (e.g. Firefox) fall back to typed turns.

Conversation nodes snapshot languages/level at start. Endpoints use
`def:protect` and resolve IDs within the caller's root. Text persists; raw
audio does not. Deletion/retention controls are future work. AI features
send transcript text to Gemini only on explicit request.

Usage fields count audio seconds and successful model requests. Provider
usage/cost accounting, budgets and latency measurement remain future work.

## Milestones

- Week 8: mic/ASR adapter and interim transcript display.
- Week 11: hint latency, pause triggers, translation and spoken output.
- Week 14: audio-based pronunciation/fluency evidence, retention controls,
  coaching quality review and beta with 10-20 learners.

No runtime or compiler validation has been performed for these scaffolds.
