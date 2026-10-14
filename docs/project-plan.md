# Language Assistant project plan

## Goal

Help language learners participate in real conversations and learn from
what went wrong. Provide support during a conversation and targeted
practice afterward, using one shared speech and transcript pipeline.

This plan reflects the Week 7 update on 10/14/2026. Milestones are targets,
not evidence of completed or tested functionality.

## Current progress

The Jac foundation and browser speech-to-text work are merged. The checkout
contains authentication, learner profiles, consent, sessions, saved text,
typed turns, and browser transcription with manual speaker selection.
The Week 7 update lists PR #7 as the merged initial speech-to-text demo.
Runtime behavior still needs verification; the coaching panels remain
placeholders.

## Planned features

1. **Live conversation assistance.** Offer short, CEFR-appropriate reply
   hints when requested. Add an AI conversation partner. Explore pause or
   struggle triggers and spoken or headphone delivery after the basic flow.
2. **Tap-to-translate.** Translate a missed partner sentence or selected
   transcript turn on request, with cached results within a session.
3. **Post-conversation coaching.** Use conversation evidence for grammar
   and vocabulary feedback, mistake history, and personalized practice.
   Pronunciation and audio-based fluency scoring need a separate source of
   audio evidence and scoring capability; the saved text alone is insufficient.

The shared foundation should support learner goals, transcript context,
consent, and usage tracking. Tailored lessons were discussed as a stretch
feature if time permits.

## Indicative schedule

| Workstream | Planned course weeks |
| --- | --- |
| Design, research, and setup | 5-6 |
| Audio capture and live transcription | 6-8 |
| Live assistance and AI partner | 8-11 |
| Tap-to-translate | 9-10 |
| Coaching reports and custom lessons | 10-13 |
| Onboarding, testing, and beta | 13-14 |

- **Week 8:** demonstrate live transcription with a spoken conversation
  shown on screen.
- **Week 11:** demonstrate hints and translation end to end in a real
  conversation.
- **Week 14:** demonstrate the full coaching loop and run a beta with
  10-20 learners, with lesson scope depending on available time.

## Risks and evaluation

- **Transcription:** verify supported languages, accents, background noise,
  browser behavior, and speaker changes. The current adapter does not
  automatically identify speakers.
- **Hint latency:** aim for roughly 1-2 seconds; measure actual response
  time before claiming that target is met.
- **Feedback quality:** ground advice in specific conversation evidence
  and check usefulness with learners rather than offering generic feedback.
- **Privacy:** require participant consent, keep raw audio out of app
  storage by default, and design deletion and retention controls.
- **Cost:** measure provider usage and per-minute costs. Existing fields
  count submitted utterance durations and model requests, but are not
  provider billing or a budget system.

## Open decisions

- Choose a product name.
- Decide whether a mobile app should be the main experience. The current
  implementation is a web app; a mobile version is a proposal.
- Choose and verify the model/provider for language features. The code
  currently configures Gemini; a small model such as `qwen3.5:4b` was floated
  for cost control but has not been integrated or evaluated here.
- Decide how to collect pronunciation evidence without undermining the
  no-raw-audio-storage default.
- Prioritize hint triggers, spoken output, and personalized lessons after
  the core requested-help flow.

## Weekly reporting

Each weekly progress slide should include linked issues and pull requests
and a one-bullet summary of the week's work. A separate demo slide is
optional. Keep the group's repository link current in the course project
spreadsheet and give partner teams specific, actionable feedback.
