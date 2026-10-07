# Live conversation assist scaffold

`request_hint(session_id, intent)` reads at most the last 12 finalized turns
and returns one typed suggestion plus a native-language explanation. Language
and CEFR level come from the session snapshot. Hints are only revealed after
an explicit request; they do not insert text into the learner's transcript.

`request_partner_turn(session_id)` is restricted to active AI-partner sessions.
It creates one partner reply and appends it to the shared transcript. The
panel updates the workspace using the foundation's onSessionChange callback.
Successful calls increment the shared model request counter.

## Next steps

- ASR pause/struggle signal and explicit opt-in automatic hints.
- Measure and tune the 1-2 second latency target; add cancellation and timeouts.
- Headphone interaction, text-to-speech and spoken AI-partner output.
- Account-level model request budgets, retries and concurrency controls.

Based only on `codex/jac-foundation`; no translation/coaching dependencies.
When merging other feature PRs, retain every panel import/render pair in
components/FeaturePanels.jac. No tests, compiler checks, app runs or Gemini
requests have been performed, per request.
