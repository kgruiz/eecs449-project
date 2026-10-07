# Language Assistant

A Jac full-stack scaffold for a live conversation coach, built on a shared
transcript pipeline with three independent feature modules.

## Setup in WSL

Jac 0.37.23 generated this project with `jac create --kind web-app --skip`.
From the repo directory in WSL:

```sh
cp .env.example .env  # skip if your .env already contains GEMINI_API_KEY
jac install
jac run --dev main.jac
```

Open the local URL printed by Jac. Create an account, choose your languages
and CEFR level, confirm participant consent, and start a session. Add partner
and learner transcript turns manually while the audio adapter is built.
Gemini configuration is server-only; override the model with `GEMINI_MODEL`.

## Structure

- `main.jac`: full-stack entry point.
- `frontend.jac`: sign-in, learner setup, consent and conversation workspace.
- `endpoints.jac`: authenticated profile and transcript/session endpoints.
- `core/models.jac`: profile, transcript, session and usage contracts.
- `core/ai.jac`: shared server-only Gemini/byLLM configuration.
- `components/FeaturePanels.jac`: slot for independent feature panels.
- `docs/architecture.md`: integration seams, scope and PR merge instructions.

Conversation text is stored in the authenticated user's graph. Raw audio is
not stored. Requested AI features send text to Gemini, covered by the consent
copy. Retention controls and real audio capture remain to be implemented.

No tests, compiler checks, app runs or Gemini requests have been performed
for these PRs, as requested. Dependency installation was also skipped.

[Original planning slides](https://docs.google.com/presentation/d/1oia2oowVMfUT1DjR8zHERDEfMGvG46OYe3SEBxx5his)
