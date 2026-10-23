# Language Assistant

A Jac workspace for practicing real conversations, with a web app, a native
iOS/Android client, and a shared transcript pipeline. The planned coaching
loop combines live reply hints, tap-to-translate, and feedback after a
conversation.

## Current state

The current checkout includes:

- Account creation and sign-in.
- A learner profile with native language, target language, and CEFR level.
- Participant consent before starting a conversation.
- Authenticated sessions, saved text transcripts, and typed turns.
- A web **Download transcript (.txt)** button for active or ended conversations
  with at least one turn. The UTF-8 file includes speaker labels, languages,
  CEFR level, and session status, and is generated locally in the browser.
- Browser speech recognition with interim text, finalized turns, manual
  speaker selection, and recorded utterance durations.
- A native mobile conversation UI and device speech-recognition adapter
  using the same authenticated server endpoints. Its web preview uses typed
  turns only; the HTML feature panels are not ported to mobile.

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
jac run --dev web
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
- `endpoints.jac`: authenticated profile, session, and transcript endpoints.
- `core/models.jac`: learner profile, transcript, session, and usage contracts.
- `core/ai.jac`: server-only Gemini/byLLM configuration for future features.
- `components/SpeechInput.jac`: browser speech-to-text adapter.
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

## Data handling

Conversation text is stored in the authenticated user's graph. The app does
not store raw audio. Speech recognition uses the browser's speech service;
the consent copy explains that Chrome and Edge send audio to their provider.
The native app uses the phone's speech service; its consent copy explains
that Apple or Google may process the audio. The consent flow also covers
sending conversation text to Gemini for future requested help. Deletion
and retention controls are not implemented.

## Validation status

The initial scaffolds were created without dependency installation, tests,
compiler checks, app runs, or Gemini requests, at the user's request.
The mobile PR author reports that `jac check` passes for the whole project
under Jac 0.37.23 and that the mobile app reached its sign-in screen in an
iOS 27 simulator. Those results were not rerun during conflict resolution.
The author reports no tests, sign-in or session-flow checks, web app runs,
or Gemini requests. No test suite is currently checked in.

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
