# Post-conversation coaching scaffold

`request_coaching(session_id)` analyzes a completed conversation with at
least one learner turn. The full transcript includes stable turn IDs and
speaker labels. Typed feedback targets grammar/vocabulary and includes the
original phrase, correction and actionable native-language explanation.
Each finding must point to an existing learner turn containing the exact
quoted phrase, or the report is rejected before saving. This validates source
attribution; correction accuracy still needs human evaluation.

Reports are cached per ended session, avoiding repeated Gemini calls.
`list_mistake_history()` exposes the caller's saved findings across reports.
`request_lesson(session_id)` separately generates and caches a short tailored
lesson from the validated findings. The panel reveals answers only on request.

Pronunciation and timing-based fluency explicitly remain unassessed; text
alone cannot support those measurements. The scaffold does not invent scores.

## Next steps

- Audio-based pronunciation integration and reliable timing evidence.
- Human review of correction quality across accents, dialects and CEFR levels.
- Learner correction/dismissal controls and history UI/filtering.
- Lesson grading, spaced practice and repeated-mistake trend summaries.
- Provider timeouts, budgets, long-transcript chunking and cache retention.

Based only on `codex/jac-foundation`; no assist/translation dependencies.
Keep all feature imports/panels when resolving FeaturePanels.jac merges.
No tests, compiler checks, app runs or Gemini calls performed, per request.
