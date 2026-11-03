# Language Assistant

A Jac workspace for practicing real conversations, with a web app, a native
iOS/Android client, and a shared transcript pipeline. The planned coaching
loop combines live reply hints, tap-to-translate, and feedback after a
conversation.

## Current state

The current checkout includes:

- Account creation and sign-in.
- A learner profile with native language, target language, and CEFR level.
  Web setup uses searchable language choices such as Spanish (Spain) and
  Spanish (Mexico). Listening defaults to the learning language; Change opens
  a language picker with Cancel and Apply, affecting transcription only.
- Participant consent before starting a conversation.
- Authenticated sessions, saved text transcripts, and typed turns.
- A web **Download transcript (.txt)** button for active or ended conversations
  with at least one turn. The UTF-8 file includes speaker labels, languages,
  CEFR level, and session status, and is generated locally in the browser.
- Browser speech recognition with interim text, finalized turns, manual
  speaker selection, and recorded utterance durations.
- Use the translation icon on a transcript turn to show English beneath
  the original. Toggle it to hide or reveal the cached translation.
- A responsive Pip-styled web interface for sign-in, conversation setup,
  transcripts, speech controls, and typed turns. The design does not add
  the planned language-assistance features.
- A native mobile conversation UI and device speech-recognition adapter
  using the same authenticated server endpoints. Its web preview uses typed
  turns only; the HTML feature panels are not ported to mobile.

Full-reply hints, AI-partner responses, mistake history, and personalized
lessons are planned. Web next-word hints and web/mobile post-conversation
recaps are implemented. `FeaturePanels.jac` is still
an extension placeholder. The web AI-partner option is disabled and labeled
“coming soon”; the server still accepts the mode but does not generate replies.
Translation is sent to Gemini only when requested, after participant consent.

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
jac run --dev web
```

Open the local URL printed by Jac. Create an account, choose your languages
and CEFR level, confirm participant consent, and start a session. Select who
is speaking, then use **Start listening**, or type a sentence and add it as
a turn. Speech input requires a browser exposing `SpeechRecognition` or
`webkitSpeechRecognition`; the UI names Chrome, Edge, and Safari. Browsers
without that API can use typed turns. Actual browser and language support
still needs runtime verification.

Set `GEMINI_API_KEY` in `.env` to enable translation, word hints, and coaching. The server defaults to
`gemini-3.5-flash-lite` through Jac's byLLM integration. Run `jac install`
after pulling the change, and restart the server after changing environment variables.
Never commit real credentials.

## Native mobile app

The `mobile` app (React Native through `@jac/mobui`) transcribes speech
with the phone's own recognizer via `expo-speech-recognition`. That is Apple
Speech on iOS and Google's SpeechRecognizer on Android, so no browser microphone
is involved. It needs a development build: Expo Go does not include the native
module.

```sh
jac setup mobile   # one-time Expo scaffold in .jac/mobile-rn/
```

Then add the config plugin to `.jac/mobile-rn/app.json` under `expo.plugins`,
so iOS gets its usage strings and Android its microphone permission:

```json
["expo-speech-recognition", {
  "microphonePermission": "Allow $(PRODUCT_NAME) to hear your conversation for live transcription.",
  "speechRecognitionPermission": "Allow $(PRODUCT_NAME) to transcribe your conversation.",
  "androidSpeechServicePackages": ["com.google.android.googlequicksearchbox"]
}]
```

The `expo-speech-recognition` version in `jac.toml` must match the Expo SDK
of the scaffold (`expo` in `.jac/mobile-rn/package.json`). From SDK 56 on, the
package's major version equals the SDK; the scaffold currently uses SDK 57.

```sh
jac run --dev mobile                 # Metro + a dev API server; press a / i
jac run --platform ios mobile        # or android: build, install and launch
jac run --dev --platform web mobile  # browser preview, typed turns only
```

Release builds call the deployed web server: set `base_url` under
`[apps.mobile.client.api]` in `jac.toml`.

### iOS simulator (Xcode 27, iOS 27)

The mobile PR author reports verification on macOS 27 with Xcode 27 and
Jac 0.37.23, up to the sign-in screen. The following toolchain workarounds
are retained from that report; they were not rerun during conflict resolution.
Jac 0.37.23 is required: 0.37.14 compiles `has` state to `useJacState`, which
its mobile runtime does not export, so the app fails with "undefined is not a
function". Check with `jac --version`; to upgrade:

```sh
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --version 0.37.23
```

One-time Xcode setup:

```sh
sudo xcodebuild -license accept && sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS   # the iOS simulator runtime, about 8 GB
```

Jac 0.37.23 needs four workarounds on this toolchain:

1. **Simulator name.** Jac builds for a simulator named exactly "iPhone 16",
   which iOS 27 does not ship. Create and boot one:

   ```sh
   ID=$(xcrun simctl create "iPhone 16" com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-27-0)
   xcrun simctl boot "$ID"
   ```

2. **Corrupt Xcode project.** Jac runs `expo prebuild` under its bundled Bun,
   which pads `ios/main.xcodeproj/project.pbxproj` with NUL bytes, and prebuild
   then fails with `Expected end of input but "\0" found`. Save this wrapper
   outside the repo (it needs Node on `PATH`), `chmod +x` it, and set
   `JAC_BUN` to its path for every `jac run` of the mobile app:

   ```sh
   #!/bin/zsh
   # Run `expo prebuild` under Node; everything else under Jac's bundled Bun.
   setopt null_glob
   REAL=$(ls -t ~/Library/Caches/jac/rt/*/site/jaclang/client/_bun/bun ~/.cache/jac/rt/*/site/jaclang/client/_bun/bun 2>/dev/null | head -1)
   if [[ "$1" == */expo/bin/cli && "$2" == prebuild ]]; then exec node "$@"; fi
   exec "$REAL" "$@"
   ```

3. **Crash on launch.** iOS 27 terminates apps that do not adopt the UIScene
   life cycle (`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`).
   Expo SDK 57 ships `ExpoAppSceneDelegate`, but its template does not use it.
   Save the config plugin below as `.jac/mobile-rn/plugins/withSceneLifecycle.js`
   and append `"./plugins/withSceneLifecycle"` to `expo.plugins` in
   `.jac/mobile-rn/app.json`, after the speech plugin.

   <details>
   <summary><code>withSceneLifecycle.js</code></summary>

   ```js
   // iOS 27 traps at launch unless the app adopts the UIScene life cycle. Expo SDK 57
   // ships ExpoAppSceneDelegate, but its bare template still starts React Native from
   // the app delegate. Hand startup to the scene delegate instead.
   const { withInfoPlist, withAppDelegate } = require('expo/config-plugins');

   function withSceneManifest(config) {
     return withInfoPlist(config, (cfg) => {
       cfg.modResults.UIApplicationSceneManifest = {
         UIApplicationSupportsMultipleScenes: false,
         UISceneConfigurations: {
           UIWindowSceneSessionRoleApplication: [
             {
               UISceneConfigurationName: 'Default Configuration',
               UISceneDelegateClassName: 'EXExpoAppSceneDelegate',
             },
           ],
         },
       };
       return cfg;
     });
   }

   function withFactoryProvider(config) {
     return withAppDelegate(config, (cfg) => {
       if (cfg.modResults.language !== 'swift') {
         throw new Error('withSceneLifecycle: expected a Swift AppDelegate');
       }
       let src = cfg.modResults.contents;
       if (!src.includes('ExpoReactNativeFactoryProvider')) {
         src = src.replace(
           /class AppDelegate: ExpoAppDelegate \{/,
           'class AppDelegate: ExpoAppDelegate, ExpoReactNativeFactoryProvider {'
         );
       }
       // The scene delegate creates the window and starts React Native.
       src = src.replace(
         /#if os\(iOS\) \|\| os\(tvOS\)\s*window = UIWindow\(frame: UIScreen\.main\.bounds\)\s*factory\.startReactNative\([\s\S]*?\)\s*#endif\n+/,
         ''
       );
       if (!src.includes('ExpoReactNativeFactoryProvider') || src.includes('UIWindow(frame:')) {
         throw new Error('withSceneLifecycle: AppDelegate template changed; update the plugin');
       }
       cfg.modResults.contents = src;
       return cfg;
     });
   }

   module.exports = (config) => withFactoryProvider(withSceneManifest(config));
   ```

   </details>

4. **Scaffold from an older Jac.** If `.jac/mobile-rn` was created by Jac
   0.37.14, Metro fails with `Unable to resolve "@jac/prelude"`. Add this line
   after the `@jac/runtime` entry in `.jac/mobile-rn/metro.config.js`:

   ```js
   '@jac/prelude': path.resolve(projectRoot, 'jac-src', 'jac_prelude.js'),
   ```

Build and install once (about 10 minutes the first time):

```sh
JAC_BUN=/path/to/bun-wrap jac run --platform ios mobile
```

Never start a second iOS build while one is running: each run's prebuild
deletes `.jac/mobile-rn/ios/`, including the `Pods/` the running build compiles
against, which shows up as missing `folly` or `jsi` headers. Also avoid
`jac run --dev mobile` here, because its API backend starts another native
build. Instead, after the build, run the API and Metro in separate terminals:

```sh
jac run web                                     # prints the API URL, e.g. http://localhost:8001
echo 'globalThis.__JAC_API_BASE_URL__ = "http://localhost:8001";' > .jac/mobile-rn/__jacApiBase.js
(cd .jac/mobile-rn && /path/to/bun-wrap node_modules/expo/bin/cli start --port 8081 --clear)
xcrun simctl launch booted com.jac.app          # reloads the app from Metro
```

Use the URL `jac run web` prints. After changing `.jac` files, rerun the build
step, which recompiles the app sources. Xcode 27 has no separate Simulator app;
open the simulator from Xcode > Open Developer Tool > Device Hub. The simulator
cannot test live transcription reliably; use a physical iPhone, which also needs
code signing.

## Structure

- `main.jac`: entry point for the `web` app and its server endpoints.
- `frontend.jac`: authentication, profile setup, consent, and conversation UI.
- `web.css`: web-only colors, typography, controls, and responsive layouts.
- `components/WebArtwork.jac`: decorative web logo and companion artwork.
- `endpoints.jac`: authenticated profile, session, and transcript endpoints.
- `core/models.jac`: learner profile, transcript, session, and usage contracts.
- `core/ai.jac`: server-only byLLM model and translation prompt.
- `components/Translation.jac`: per-turn translation controls and bilingual transcript display.
- `components/SpeechInput.jac`: browser speech-to-text adapter; with a voiceprint
  enrolled it sends each turn's audio to `append_spoken_turn` for speaker detection.
- `components/VoiceSetup.jac`, `components/audioCapture.js`: web voice enrollment
  and in-memory microphone capture for speaker detection.
- `core/voiceprint.py`: server-side speaker verification (sherpa-onnx WeSpeaker);
  stores only an embedding, never audio.
- `components/TranscriptDownload.jac`: local plain-text download in the web UI.
- `core/transcript.jac`: readable transcript formatting.
- `core/speech.jac`: shared locale mapping and speech error messages.
- `mobile/main.jac`: entry point for the `mobile` app.
- `mobile/ConversationApp.jac`: native authentication and conversation UI.
- `mobile/SpeechInput.native.jac`: device speech-to-text adapter.
- `mobile/SpeechInput.jac`: typed-only mobile web-preview fallback.
- `mobile/theme.jac` and `mobile/ui.jac`: native styling and UI helpers.
- `components/FeaturePanels.jac`: extension slot for planned coaching features.
- `docs/architecture.md`: data flow, integration points, and limitations.
- `docs/project-plan.md`: product goals and indicative delivery plan.

## Web navigation

**Talk** contains conversation setup and the live transcript/controls.
**Conversations** lists your completed sessions, newest dated sessions first,
with a title taken from the opening turn, language/level, local date/time,
turn count, and summary preview. Earlier sessions without timestamps remain
available and are labeled Earlier conversation. Lists use pages of 20 records.

Opening a conversation shows three sections:

- **Overview:** its summary and what went well.
- **Transcript:** saved turns, on-demand translations, and text download.
- **Practice:** evidence-based phrasing improvements and short practice tasks.

Ending a session takes you directly to its Overview. New conversation returns
to Talk setup. Switching tabs retains an active session, speaker selection, and
typed draft; stop listening and wait for saves before leaving Talk. Active
sessions are not shown in the completed library, and active-session recovery
after a full page reload is not implemented. Tab selection is local UI state,
not a shareable URL. Native mobile retains its existing recap layout.

## Conversation recap

Stop listening and wait for pending turns to save, then end the conversation.
Web and mobile request a recap automatically for sessions with a learner turn.
The recap includes a summary, up to three strengths, and up to three priorities
with learner quotes, suggested phrasing, and specific practice tasks. Explanations
use the session's native language; phrasing follows its target language and CEFR level.
Feedback uses text only and does not score pronunciation or acoustic fluency.

Successful reports are saved with the conversation and returned by
`get_conversation`; repeat requests reuse them. The web Conversations tab
lets you revisit completed sessions and their saved feedback.
Empty or partner-only sessions do not request feedback. Provider failures keep
the ended transcript intact and show Retry feedback. Transcripts exceeding
100,000 serialized characters are rejected rather than silently truncated.
Speaker corrections must be made before ending the conversation.

## Data handling

Conversation text is stored in the authenticated user's graph. The app does
not store raw audio. Speech recognition uses the browser's speech service;
the consent copy explains that Chrome and Edge send audio to their provider.
The native app uses the phone's speech service; its consent copy explains
that Apple or Google may process the audio. The consent flow also covers
sending conversation text to Gemini for language help and an automatic recap
after completion. Deletion
and retention controls are not implemented.

## Validation status

The initial scaffolds were created without dependency installation, tests,
compiler checks, app runs, or Gemini requests, at the user's request.
The mobile PR author reports that `jac check` passes for the whole project
under Jac 0.37.23 and that the mobile app reached its sign-in screen in an
iOS 27 simulator. Those results were not rerun during conflict resolution.
The author reports no tests, sign-in or session-flow checks, web app runs,
or Gemini requests. Offline AI regression tests are now checked in beside the core AI modules.

Live native transcription and physical-device conversation flows still need
verification. Follow `AGENTS.md` when planning validation and record the
exact commands and outcomes when it occurs.

### Transcript-download validation (2026-10-23)

`jac check` passed for both app entry points with existing warnings. The web
app was run with Jac 0.37.23 in WSL using a temporary Linux-local copy of the
changed source: installation on the Windows mount timed out, while
`jac install` and `jac run --dev web` succeeded in the Linux-local copy.
Synthetic-account checks covered sign-in, required authentication/consent,
typed turns, cross-account isolation, ending a session, and rejecting late
turns. Browser checks confirmed the disabled empty-state button and downloaded
active/ended UTF-8 files with the correct status, speaker order, accents,
non-Latin text, and literal markup. The compiled formatter also passed direct
Node assertions for the same text format. No microphone, native-device, or
Gemini checks were performed; live speech still needs verification.

### Web UI verification on 10/23/2026

The web restyle was checked with Jac 0.37.23:

- `jac check` passed for both configured app entry points. The checker
  reports warnings, including loose speech-API types and JSX host names.
- `biome check web.css` passed without warnings.
- `jac build --as client web` built the browser bundle successfully.
- `jac run --dev --host 127.0.0.1 --port 8000 --api-port 8001 web`
  served the UI for browser checks with a disposable local test account.
- Browser checks verified sign-in, the consent-gated Start control,
  conversation creation, Partner and Me typed turns, session completion,
  and sign-out. The 390px-wide setup and active conversation layouts had
  no horizontal overflow. No browser console warnings or errors were
  reported during that flow.

These checks do not verify microphone capture, spoken-turn delivery,
cross-account isolation, native mobile behavior, or model requests. No
simulator was started for this web change. Follow `AGENTS.md` for further
validation and record the exact commands and outcomes when it occurs.

### Sentence translation verification (2026-10-30)

`jac check` passed for both app entry points with existing warnings. An
isolated WSL copy was served with `jac run --dev --host 127.0.0.1 --port
8010 --api-port 8011 web`. Disposable-account checks covered authentication,
required consent, transcript ownership, rejected unrelated text, typed turns,
session completion, and rejection of late turns. A live Gemini 3.5 Flash-Lite
request translated a synthetic sentence. Browser checks covered individual
sentence selection, loading, English output, and toggling without a second
request. Microphone capture and spoken-turn delivery were not tested.

### Transcript download UI integration on 11/02/2026

Merged the Pip web UI into the transcript-download branch. The download
control now sits beneath the conversation heading, using the shared secondary
button and error-banner styles. Its state resets for each new session.

- `jac check` passed for both apps under Jac 0.37.23, with warnings.
- `biome check web.css` and `jac build --as client web` passed.
- `jac run --dev --host 127.0.0.1 --port 8000 --api-port 8001 web`
  served the app for browser checks with a disposable local account.
- Browser checks covered account creation, consent-gated session creation,
  disabled empty export, Partner/Me typed turns, active and ended downloads,
  session completion, and sign-out. Downloaded UTF-8 files contained the
  expected status, speaker order, accents, Chinese text, and line breaks.
- Inspected desktop and 390px layouts; the narrow layout had no horizontal
  overflow. After giving the download component a distinct session key,
  the final browser run reported no console warnings or errors.

Microphone input, native mobile, cross-account isolation, download failure
handling, and Gemini requests were not retested for this UI integration.

### Translation response validation on 11/02/2026

Translation now requests a structured `TranslationResult` and returns its
`text` field to the browser. Malformed structured output uses byLLM's typed
output retry/error path, and empty translations raise an error rather than
being displayed. This addresses the observed tuple-like translation display
without stripping punctuation from valid translations.

`jac test core/ai.jac` passes four offline regression tests covering text
extraction, malformed output, punctuation preservation, and empty text. The
tests replace the provider transport while exercising the real byLLM parsing;
they make no model requests. `jac check` passes both apps with warnings, and
`jac build --as client web` succeeds. Live Gemini output and browser behavior
were not retested for this change; the source of the original malformed live
response has not been confirmed.

### Conversation layout verification on 11/02/2026

The web conversation view uses open transcript rows, icon-only translation
controls with hover/focus tooltips, and English beneath the original with an
accent rule. Each action translates the entire turn through the existing
protected endpoint. Its 4,000-character limit matches the turn-input limit.
Translations remain local to the current view; downloads retain original text.
The header, speech controls, and multiline composer use the simplified layout.
The planned-feature footnote is removed. Recognition language was a text
field at this validation point; the web now uses the picker described above.
Native mobile code is unchanged.

- `jac test core/ai.jac`: four offline translation regression tests passed.
- `jac check`: both apps passed with warnings.
- `biome check web.css` and `jac build --as client web` passed.
- Browser QA used an isolated temporary copy served with
  `jac run --dev --host 127.0.0.1 --port 8020 --api-port 8021 web` and a
  simulated translation provider. No mock is included in the app source.
- Verified account creation, consent-gated session creation, empty download
  state, typed and multiline turns, translation loading, original/English
  coexistence, keyboard toggle, cached toggling, simulated failure/retry,
  original-text export, completion, and sign-out. Desktop and 390px layouts
  were inspected; the narrow viewport had no horizontal overflow. Browser
  diagnostics reported no warnings or errors.

Live Gemini, microphone capture, and cross-account isolation were not retested.
No mobile simulator was started. The isolated QA server was stopped afterward.

### Transcript scrolling verification on 11/02/2026

The web transcript now scrolls inside a bounded card, leaving the header and
desktop controls outside the scrolling list. New content follows the bottom
only while the reader is near it; Latest returns to the newest turn. Narrow
browser layouts retain stacked controls and an independently scrollable list.

- `jac check` passed for both apps with warnings; `jac test core/ai.jac`
  passed all four offline tests.
- `biome check web.css` and `jac build --as client web` passed.
- The isolated test copy was served with `jac run --dev --host 127.0.0.1
  --port 8020 --api-port 8021 web`, using its simulated translation provider.
  Browser checks covered sign-in, consent, nine typed turns, following new
  turns, preserving scroll position while adding a turn, keyboard scrolling,
  Latest, translation expansion, and session completion. A six-turn session
  at 390px also scrolled correctly without horizontal overflow. The browser
  reported no console errors or warnings.
- No live Gemini request, microphone capture, cross-account isolation check,
  or mobile simulator was run for this change. The test server was stopped.

### Voice-detection merge integration on 11/02/2026

Merged `origin/main` into `voice-detection`, retaining the scrollable transcript,
translation, and download UI alongside voice enrollment and speaker correction.
Speaker correction now uses the speaker button in each translated transcript row;
guessed labels remain visible and corrections remain disabled after completion.

`jac check` passed for both apps with warnings, `jac test core/ai.jac` passed
all four offline tests, `biome check web.css` passed, and
`jac build --as client web` succeeded. An isolated browser-QA server could not
start because the local environment lacks the newly declared `numpy` dependency.
Run `jac install` to install this branch's dependencies before starting the app.
The integrated browser flow, voice enrollment, and real-microphone speaker
detection remain unverified. No simulator or live Gemini request was run.

### Next-word hint merge integration on 11/02/2026

Merged `origin/main` into `feat/struggle-word-hint`, keeping translation,
transcript export/scrolling, voice enrollment, and speaker corrections together
with word suggestions. Hints use the shared Gemini configuration. With voice
enrollment, spoken hints wait for the server-attributed finalized turn because
the interim speaker is unknown; manual-speaker speech still supplies interim
drafts. Typed hints continue to use the selected speaker.

`jac check` passed for both apps with warnings, `biome check web.css` passed,
and `jac build --as client web` succeeded. `jac test core/ai.jac` passed four
offline tests; `jac test core/hints.jac` passed five collected tests including
a new mocked structured-word-hint regression. The web/API server started with
`jac run --dev --host 127.0.0.1 --port 8020 --api-port 8021 web` and was stopped
after the startup check. The integrated browser/microphone flow and live hint
quality were not verified. No simulator or live Gemini request was run.

### Speaker selector verification on 11/02/2026

The web speaker dropdown is now a Me/Partner segmented radio group with
avatars, a selected-state checkmark, and visible keyboard focus. Native radio
keys work, and switching still clears the spoken hint draft. Voice-enrolled
sessions retain the Typed turns are from label and automatic spoken attribution.

`jac check` passed for both apps with warnings, `biome check web.css` and
`jac build --as client web` passed, and `jac test core/hints.jac` passed five
collected offline tests. An isolated test copy on ports 8020/8021 with simulated
AI providers verified consent, click selection, arrow-key switching, Me and
Partner typed-turn attribution, session completion, and the 390px layout with
no horizontal overflow or browser console errors/warnings. The test server
was stopped. Live microphone/voice enrollment and Gemini were not exercised;
no simulator was started.

### Post-conversation coaching verification on 11/02/2026

- `jac check` passed both apps with warnings under Jac 0.37.23.
- `jac test core/coaching.jac` passed 10 collected tests (six coaching tests
  plus four imported translation regressions). `jac test core/hints.jac`
  passed five collected tests. All provider calls were mocked.
- `biome check web.css` and `jac build --as client web` passed.
- An isolated temporary source copy on ports 8020/8021 used simulated coaching
  and hint providers. API checks passed authentication, consent, ownership,
  completion requirements, saved-report retrieval/cache reuse, rejection of late
  turns/speaker changes, empty sessions, and preservation after provider errors.
- Browser checks covered sign-in, consent, learner typed turns, recap display,
  simulated failure/retry, and a 390px recap without horizontal overflow.
  A synthetic speech recognizer verified End remains disabled while listening
  and awaiting its delayed final result, then enables after the turn is saved.
- The temporary copy reused the existing project virtual environment because
  `jac install` failed creating a venv with a bundled-Python symbol error.
  Hot reload emitted transient Vite reload errors while QA files were copied;
  a full reload restored the tested flow. QA fixtures are outside the repository.

No live Gemini requests, real microphone tests, or native simulator/device runs
were performed. Native recap rendering and live output quality remain unverified.

### Conversations navigation verification on 11/02/2026

- `jac check` passed both apps with warnings; `biome check web.css` and
  `jac build --as client web` passed. The list-return bridge needs a type-import
  alias to avoid duplicate generated class declarations under Jac 0.37.23.
- `jac test core/history.jac` passed three tests for sorting/filtering, bounded
  previews, legacy dates, and pagination. Coaching and hints suites passed
  10 and five collected offline tests respectively (including imported tests).
- Isolated API QA with simulated AI passed authentication, ownership isolation,
  completed-only listing, timestamps, pagination, report persistence/reuse,
  rejection of late turns/corrections, and provider-failure preservation.
- Browser QA verified an empty library, consent, typed turns, retained drafts
  and active sessions across tab switches, completion into Overview, separate
  Transcript/Practice sections, reopening saved feedback, and history after
  reopening the app. Downloaded text contained the correct ended transcript.
- A synthetic recognizer verified navigation/completion remain disabled through
  a delayed final result. Practice at 390px had no horizontal overflow.

The temporary QA copy used simulated AI and speech, not live Gemini or a real
microphone. No native simulator was started. Native navigation was not changed.

### Interactive practice verification on 11/03/2026

The web Practice section now provides phrase comparisons with changed-word
highlighting, Listen, expandable explanations, typed or spoken answers, and
Check answer with retry and next/finish controls. Checking sends the answer to
Gemini; answers and exercise progress are temporary and never appended to the
saved transcript. Speech recognition produces editable text, not pronunciation
scores. Playback depends on an available device voice for the selected language.

- `jac check` passed the new practice module, web coaching panel, and endpoints
  (existing JSX/interface warnings remain).
- `jac build web -a client` passed.
- `jac test core/practice.jac` passed seven collected offline tests;
  `jac test core/coaching.jac` passed ten collected offline tests.
- `bun test components/practice-diff.test.js` passed three tests; scoped Biome
  checks passed for the new JavaScript/JSX and CSS.
- An isolated preview with simulated AI verified correction, successful answers,
  retry, provider-error text preservation, completion/restart, and editable
  output from a synthetic speech recognizer. Browser phrase playback started.
- No live Gemini request, real microphone capture, or native-device run was
  performed. Model feedback quality still needs live evaluation.

### Practice explanations on 11/03/2026

Practice now shows its explanation above the phrase comparison. Newly generated
feedback labels each priority Correction or Optional improvement and provides a
specific heading. Optional wording changes must not be presented as mistakes.
Existing saved reports remain readable with a neutral Practice note label and
visible explanation; they are not automatically regenerated or classified.

Validation: `jac check core/coaching.jac`, `jac build web -a client`, and scoped
Biome checks passed. Coaching and practice suites passed 12 and seven collected
offline tests respectively. An isolated component preview verified corrections,
optional improvements, legacy feedback, answer/next controls, and a 390px layout
without horizontal overflow. The preview used fixtures and simulated checking;
no live model or microphone requests were made.
