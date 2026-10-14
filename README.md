# Language Assistant

A Jac workspace for a live conversation coach, built on a shared transcript
pipeline with three independent feature modules. The `web` app serves the API
and a browser UI; the `mobile` app is a native iOS/Android client of that
server.

## Setup in WSL

Jac 0.37.23 generated this project with `jac create --kind web-app --skip`.
From the repo directory in WSL:

```sh
cp .env.example .env  # skip if your .env already contains GEMINI_API_KEY
jac install
jac run --dev web
```

Open the local URL printed by Jac. Create an account, choose your languages
and CEFR level, confirm participant consent, and start a session. Add partner
and learner turns by speaking (choose who is talking, then Start listening;
Chrome, Edge or Safari) or by typing.
Gemini configuration is server-only; override the model with `GEMINI_MODEL`.

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

Release builds call the deployed web server: set `[apps.mobile.client.api]
base_url` in `jac.toml`.

### iOS simulator (Xcode 27, iOS 27)

Verified on macOS 27 with Xcode 27 and Jac 0.37.23, up to the sign-in screen.
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

- `main.jac`: `web` app entry (server endpoints and browser client).
- `frontend.jac`: sign-in, learner setup, consent and conversation workspace.
- `endpoints.jac`: authenticated profile and transcript/session endpoints.
- `core/models.jac`: profile, transcript, session and usage contracts.
- `core/ai.jac`: shared server-only Gemini/byLLM configuration.
- `components/SpeechInput.jac`: browser speech-to-text adapter feeding `append_turn`.
- `core/speech.jac`: locale mapping and error messages shared by both adapters.
- `mobile/main.jac`: `mobile` app entry; `mobile/ConversationApp.jac` is its screen.
- `mobile/SpeechInput.native.jac`: native speech-to-text adapter feeding
  `append_turn`; `mobile/SpeechInput.jac` is its typed-only web-preview variant.
- `components/FeaturePanels.jac`: slot for independent feature panels.
- `docs/architecture.md`: integration seams, scope and PR merge instructions.

Conversation text is stored in the authenticated user's graph. Raw audio is
not stored. Requested AI features send text to Gemini, covered by the consent
copy. Speech is transcribed by the browser's speech service on the web and by
the phone's speech service (Apple or Google) in the mobile app. Retention
controls remain to be implemented.

`jac check` passes for the whole project under Jac 0.37.23, and the mobile
app has been run in the iOS 27 simulator up to its sign-in screen. No tests,
sign-in or session flows, web app runs or Gemini requests have been exercised.

[Original planning slides](https://docs.google.com/presentation/d/1oia2oowVMfUT1DjR8zHERDEfMGvG46OYe3SEBxx5his)
