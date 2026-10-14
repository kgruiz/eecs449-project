# Working in this Jac project

This repository is a real-conversation language assistant built with Jac.
Read `README.md`, `docs/architecture.md`, and `docs/project-plan.md` before
changing behavior. Keep documentation clear about what is implemented,
planned, and verified.

## Current implementation

The app has authentication, learner profiles, participant consent, sessions,
saved transcripts, typed turns, and browser and native speech-to-text adapters.
`jac.toml` defines a `web` app serving the API and browser UI, and a `mobile`
app with a native conversation UI. Both use the shared server endpoints;
the mobile browser preview supports typed turns only.
`components/FeaturePanels.jac` is a placeholder. Live reply hints,
AI-partner responses, translation, coaching, mistake history, and lessons
are planned, not implemented. The AI-partner selector only records a mode.
`core/ai.jac` contains configuration; the current flow makes no model calls.

Preserve authenticated ownership checks, participant consent, and the
shared `append_turn` transcript handoff. Keep raw audio out of persistence
and Gemini credentials on the server. Do not describe audio-based
pronunciation scoring as available from text transcripts alone.

## Jac reference guides

The project pins Jac 0.37.23 in `jac.toml`. Jac syntax evolves and is easily
confused with Python or JSX. Before writing or editing `.jac` files, consult
the guides bundled with the matching installed compiler:

- `jac guide` lists available guides.
- `jac guide jac-essentials` provides the starting reference.
- `jac guide --search <keyword>` finds task-specific guides.
- `jac guide <name> --sections` lists headings.
- `jac guide <name> --section <slug>` retrieves a relevant section.
- `jac guide --json` provides machine-readable guidance.

Follow diagnostic hints pointing to relevant guides. Preserve surrounding
code style and existing public interfaces unless the task requires a change.

## Validation

The four initial scaffold PRs were intentionally created without tests,
compiler checks, app servers, or Gemini requests. Do not treat their merge,
or the later speech-to-text merge, as evidence that validation passed.
The mobile PR author reports a passing project-wide `jac check` under
Jac 0.37.23 and an iOS simulator launch up to sign-in. Those results do not
establish that authentication, sessions, or live transcription work end to end.
Do not run those initial scaffold validation steps or paid model requests
unless authorized for the task. Preserve this constraint when updating docs.

When validation is authorized:

- `jac check <file>` type-checks and lints; follow its guide references.
- `jac run <file>` executes a script.
- `jac run --dev web` serves the web app with development reload behavior.
- Follow the README's mobile setup and toolchain workarounds before native
  builds. Avoid concurrent iOS builds, which can overwrite generated files.
- `jac browse open localhost:8000` starts browser QA; use `snapshot`,
  `click`, `fill`, `screenshot`, and `close` as supported by the installed CLI.

Verify authentication, consent, session ownership, typed and spoken turns,
and session completion when changing the conversation flow. Record actual
commands, results, and remaining limitations. No test suite is currently
checked in. Documentation-only changes need documentation checks, not app
runs or model requests.

## Repository hygiene

Use atomic Conventional Commits and stage only files changed for the task.
Leave unrelated local changes untouched. Keep credentials, dependency
folders, compiler caches, and generated build artifacts out of commits.
