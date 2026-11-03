"""Native speech-to-text adapter (expo-speech-recognition: Apple Speech on iOS,
SpeechRecognizer on Android). Interim hypotheses stay on the device; each
finalized utterance is submitted once, in order, with a non-overlapping duration.

With voice recognition set up (voiceEnabled), each session is also recorded to a
temporary WAV; the turn is sent with that audio to append_spoken_turn,
which decides the speaker from the learner's voiceprint, and the file is deleted.
Otherwise the turn goes to append_turn with the manually selected speaker. The
server never stores the audio.

iOS runs one non-continuous session per utterance (it finalizes after ~3s of
silence) and restarts it. Android runs continuous sessions, which finalize per
segment and avoid the system beep on every restart.

Each restart waits for the previous session's "end" plus a short delay: iOS tears
the audio session down asynchronously, and starting again too soon reads a 0 Hz
input format, which the module reports as "audio-capture" (audioInputBusy)."""
import from "expo-speech-recognition" { ExpoSpeechRecognitionModule, useSpeechRecognitionEvent }
import from "expo-file-system" { File }
import from "@jac/mobui" { View, Text, TextInput, Platform }
import from ..core.models { SessionView }
import from ..endpoints { append_turn, append_spoken_turn }
import from ..core.speech {
    speech_locale, speech_error_message, ROUTINE_SPEECH_ERRORS, RETRYABLE_SPEECH_ERRORS,
    MAX_SPEECH_RETRIES, RESTART_DELAY_MS
}
import from .theme { styles, C }
import from .ui { ActionButton }

def:pub SpeechInput(sessionId: str, speaker: str, language: str, voiceEnabled: bool,
                    onSessionChange: Callable[[SessionView], None],
                    onBusyChange: Callable[[bool], None] | None = None) -> JsxElement {
    has listening: bool = False, interim: str = "", locale: str = speech_locale(language),
        error: str = "", available: bool = True;
    has saving: bool = False, settling: bool = False;
    has listeningRef: Ref[bool] = Ref(False);
    # True from start() until the module's "end"; a new session must not start before then.
    has activeRef: Ref[bool] = Ref(False);
    has retriesRef: Ref[int] = Ref(0);
    has timerRef: Ref[any] = Ref(None);
    has speakerRef: Ref[str] = Ref(speaker);
    # Open utterance: {"speaker", "started", "text"} captured at its first interim result.
    has utteranceRef: Ref[any] = Ref(None);
    # Set once a session submits; a later final without new speech is a duplicate
    # (iOS 18 can repeat the final after its early-final workaround).
    has sessionFinalRef: Ref[bool] = Ref(False);
    has queueRef: Ref[list[dict[str, any]]] = Ref([]);
    has drainingRef: Ref[bool] = Ref(False);
    # Voice mode holds a session's turns until "end", when its recording is known.
    has pendingRef: Ref[list[dict[str, any]]] = Ref([]);
    has audioUriRef: Ref[any] = Ref(None);
    has voiceRef: Ref[bool] = Ref(voiceEnabled);
    speakerRef.current = speaker;
    voiceRef.current = voiceEnabled;

    # Read a temporary recording as base64 and delete it; "" if it is unreadable.
    async def take_recording(uri: str) -> str {
        data: str = "";
        try {
            file = new(File, uri);
            data = await file.base64();
            file.delete();
        } except Exception { data = ""; }
        return data;
    }
    can with [listening, saving, settling] entry {
        if onBusyChange { onBusyChange(listening or saving or settling); }
    }
    # Submit queued turns one at a time so transcript order matches speech order.
    async def drain() -> None {
        updated: SessionView | None = None;
        turn: dict[str, any] = {};
        if drainingRef.current { return; }
        drainingRef.current = True; saving = True;
        try {
            while queueRef.current and len(queueRef.current) > 0 {
                turn = queueRef.current[0];
                queueRef.current = queueRef.current[1:];
                try {
                    if turn["voice"] {
                        audio = await take_recording(turn["audio"]) if turn["audio"] else "";
                        updated = await append_spoken_turn(sessionId, turn["text"], turn["duration"], audio);
                    } else {
                        updated = await append_turn(sessionId, turn["speaker"], turn["text"], turn["duration"]);
                    }
                    onSessionChange(updated);
                } except Exception {
                    error = "Could not save a spoken turn: " + turn["text"];
                }
            }
        } finally { drainingRef.current = False; saving = False; }
    }
    def finalize(text: str) -> None {
        utterance = utteranceRef.current;
        utteranceRef.current = None;
        interim = "";
        if not text.strip() { return; }
        sessionFinalRef.current = True;
        who = utterance["speaker"] if utterance else speakerRef.current;
        started = utterance["started"] if utterance else Date.now();
        elapsed = (Date.now() - started) / 1000.0;
        turn = {"speaker": who, "text": text.strip(), "voice": voiceRef.current, "audio": None,
            "duration": round(elapsed, 2) if elapsed > 0.0 else 0.0};
        if voiceRef.current {
            pendingRef.current = (pendingRef.current or []) + [turn];
            return;
        }
        queueRef.current = (queueRef.current or []) + [turn];
        drain();
    }
    # A session's recording identifies its speaker only if it holds a single turn
    # (iOS); several turns in one recording (Android) fall back to turn-taking.
    def flushSession() -> None {
        turns = pendingRef.current or [];
        uri = audioUriRef.current;
        pendingRef.current = [];
        audioUriRef.current = None;
        if uri and len(turns) == 1 { turns[0]["audio"] = uri; }
        elif uri { take_recording(uri); }
        if len(turns) > 0 {
            queueRef.current = (queueRef.current or []) + turns;
            drain();
        }
    }
    # Each result carries the whole current utterance, not a growing result list.
    def handleResult(event: any) -> None {
        transcript: str = "";
        if event.results and event.results.length > 0 {
            transcript = event.results[0].transcript or "";
        }
        if event.isFinal {
            if utteranceRef.current or not sessionFinalRef.current { finalize(transcript); }
            return;
        }
        if transcript.strip() {
            retriesRef.current = 0;
            if not utteranceRef.current {
                utteranceRef.current = {"speaker": speakerRef.current, "started": Date.now(), "text": ""};
            }
            utteranceRef.current["text"] = transcript;
        }
        interim = transcript;
    }
    def handleError(code: str) -> None {
        # Silence and our own aborts are routine; "end" restarts if still listening.
        if code in ROUTINE_SPEECH_ERRORS { return; }
        # The audio session may still be settling; "end" follows and schedules a retry.
        if (code in RETRYABLE_SPEECH_ERRORS and listeningRef.current
                and retriesRef.current < MAX_SPEECH_RETRIES) {
            retriesRef.current = retriesRef.current + 1;
            return;
        }
        listeningRef.current = False;
        listening = False;
        error = speech_error_message(code);
    }
    def begin() -> None {
        sessionFinalRef.current = False;
        activeRef.current = True; settling = True;
        options: dict[str, any] = {"lang": locale.strip(), "interimResults": True,
            "continuous": Platform.OS == "android", "addsPunctuation": True};
        if voiceRef.current {
            # Native input format; the module's downsampling produced near-empty files.
            options["recordingOptions"] = {"persist": True};
        }
        ExpoSpeechRecognitionModule.start(options);
    }
    def clearTimer() -> None {
        if timerRef.current { clearTimeout(timerRef.current); }
        timerRef.current = None;
    }
    def restart() -> None {
        timerRef.current = None;
        if not listeningRef.current or activeRef.current { return; }
        try { begin(); }
        except Exception {
            activeRef.current = False; settling = False;
            listeningRef.current = False;
            listening = False;
            error = "Speech recognition stopped. Tap Start listening to resume.";
        }
    }
    def handleEnd() -> None {
        settling = False;
        activeRef.current = False;
        # A session cut off before its final result keeps its last hypothesis.
        if utteranceRef.current { finalize(utteranceRef.current["text"]); }
        interim = "";
        utteranceRef.current = None;
        flushSession();
        if listeningRef.current {
            clearTimer();
            timerRef.current = setTimeout(lambda { restart(); },
                RESTART_DELAY_MS * (retriesRef.current + 1));
        } else { listening = False; }
    }
    useSpeechRecognitionEvent("result", lambda (e: any) { handleResult(e); });
    useSpeechRecognitionEvent("error", lambda (e: any) { handleError(e.error); });
    useSpeechRecognitionEvent("audioend", lambda (e: any) { audioUriRef.current = e.uri; });
    useSpeechRecognitionEvent("end", lambda { handleEnd(); });

    async def start() -> None {
        permission: any = None;
        error = ""; settling = True;
        try {
            permission = await ExpoSpeechRecognitionModule.requestPermissionsAsync();
        } except Exception {
            settling = False;
            error = "Could not request microphone access.";
            return;
        }
        if not permission.granted {
            settling = False;
            error = speech_error_message("not-allowed");
            return;
        }
        retriesRef.current = 0;
        listeningRef.current = True;
        listening = True;
        # A just-stopped session restarts from its "end" instead.
        if activeRef.current { return; }
        try { begin(); }
        except Exception {
            activeRef.current = False; settling = False;
            listeningRef.current = False;
            listening = False;
            error = "Could not start speech recognition.";
        }
    }
    def stop() -> None {
        clearTimer();
        listeningRef.current = False;
        listening = False;
        # stop() (unlike abort()) still delivers the final result for the open utterance.
        ExpoSpeechRecognitionModule.stop();
    }
    can with entry {
        try { available = ExpoSpeechRecognitionModule.isRecognitionAvailable(); }
        except Exception { available = False; }
    }
    # Switching speaker mid-utterance flushes it to the previous speaker; "end" restarts.
    can with [speaker] entry {
        if not voiceRef.current and listeningRef.current and utteranceRef.current {
            ExpoSpeechRecognitionModule.stop();
        }
    }
    can with exit {
        clearTimer();
        if listeningRef.current or activeRef.current {
            listeningRef.current = False;
            ExpoSpeechRecognitionModule.abort();
        }
    }
    <View style={styles.card} accessibilityLabel="Speech to text">
        {(<Text style={styles.muted}>
            Speech recognition is unavailable on this device.
        </Text>) if not available else (<View style={{"gap": 12}}>
            <Text style={styles.label}>Recognition language</Text>
            <TextInput style={styles.input} value={locale} editable={not listening}
                autoCapitalize="none" autoCorrect={False} placeholderTextColor={C.muted}
                placeholder="es-ES" onChangeText={lambda (t: str) { locale = t; }}/>
            {(<ActionButton label="Stop listening" variant="danger" onPress={stop}/>) if listening
                else (<ActionButton label="Start listening" disabled={not locale.strip()}
                    onPress={lambda { start(); }}/>)}
            {(<Text style={styles.muted}>
                {"Listening..." if voiceEnabled
                    else "Listening for " + ("me" if speaker == "learner" else "partner") + "..."}
            </Text>) if listening else <View/>}
            <Text style={styles.interim} accessibilityLiveRegion="polite">{interim}</Text>
        </View>)}
        {(<Text style={styles.error} accessibilityRole="alert">{error}</Text>) if error else <View/>}
    </View>
}
