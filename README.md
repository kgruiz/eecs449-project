# Language Assistant

A Jac web app for practicing real conversations, with browser speech-to-text
and a shared transcript pipeline. The planned coaching loop combines live
reply hints, tap-to-translate, and feedback after a conversation.

## Current state

The current checkout includes:

- Account creation and sign-in.
- A learner profile with native language, target language, and CEFR level.
- Participant consent before starting a conversation.
- Authenticated sessions, saved text transcripts, and typed turns.
- Browser speech recognition with interim text, finalized turns, manual
  speaker selection, and recorded utterance durations.

Live hints, AI-partner responses, translation, coaching reports, mistake
history, and personalized lessons are planned. `FeaturePanels.jac` is still
an extension placeholder. The AI-partner selector records a session mode;
selecting it does not yet generate responses. Gemini configuration exists,
but the current conversation flow makes no model requests.

See [the project plan](docs/project-plan.md) for scope, milestones, risks,
and open decisions, and [the architecture](docs/architecture.md) for the
current integration points.

## Development setup

The project pins Jac 0.37.23 in `jac.toml`. Use a matching Jac installation.
The existing setup workflow targets WSL. From the repository directory:

```sh
# Only copy this template if you do not already have a .env file.
cp .env.example .env
jac install
jac run --dev main.jac
```

Open the local URL printed by Jac. Create an account, choose your languages
and CEFR level, confirm participant consent, and start a session. Select who
is speaking, then use **Start listening**, or type a sentence and add it as
a turn. Speech input requires a browser exposing `SpeechRecognition` or
`webkitSpeechRecognition`; the UI names Chrome, Edge, and Safari. Browsers
without that API can use typed turns. Actual browser and language support
still needs runtime verification.

The `.env.example` file contains placeholders for server-side
`GEMINI_API_KEY` and `GEMINI_MODEL`. Replace the key before implementing or
trying Gemini features. The current configured model string is
`gemini/gemini-3.8-flash`; its provider availability has not been verified.
Never commit real credentials.

## Structure

- `main.jac`: full-stack entry point.
- `frontend.jac`: authentication, profile setup, consent, and conversation UI.
- `endpoints.jac`: authenticated profile, session, and transcript endpoints.
- `core/models.jac`: learner profile, transcript, session, and usage contracts.
- `core/ai.jac`: server-only Gemini/byLLM configuration for future features.
- `components/SpeechInput.jac`: browser speech-to-text adapter.
- `components/FeaturePanels.jac`: extension slot for planned coaching features.
- `docs/architecture.md`: data flow, integration points, and limitations.
- `docs/project-plan.md`: product goals and indicative delivery plan.

## Data handling

Conversation text is stored in the authenticated user's graph. The app does
not store raw audio. Speech recognition uses the browser's speech service;
the consent copy explains that Chrome and Edge send audio to their provider.
The consent flow also covers sending conversation text to Gemini for future
requested help. Deletion and retention controls are not implemented.

## Validation status

The initial scaffolds were created without dependency installation, tests,
compiler checks, app runs, or Gemini requests, at the user's request. The
speech-to-text work has since been merged, but this checkout contains no
record of runtime validation or a test suite. Source inspection alone does
not establish that the app works end to end. Follow `AGENTS.md` when
planning validation; document the exact commands and outcomes when it occurs.
