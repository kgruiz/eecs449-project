"""Native speech-to-text adapter (expo-speech-recognition: Apple Speech on iOS,
SpeechRecognizer on Android). Interim hypotheses stay on the device; each
finalized utterance is submitted once, in order, through append_turn with its
speaker and a non-overlapping duration. Raw audio is never stored.

iOS runs one non-continuous session per utterance (it finalizes after ~3s of
silence) and restarts it. Android runs continuous sessions, which finalize per
segment and avoid the system beep on every restart."""
import from "expo-speech-recognition" { ExpoSpeechRecognitionModule, useSpeechRecognitionEvent }
import from "@jac/mobui" { View, Text, TextInput, Platform }
import from ..core.models { SessionView }
import from ..endpoints { append_turn }
import from ..core.speech { speech_locale, speech_error_message, ROUTINE_SPEECH_ERRORS }
import from .theme { styles, C }
import from .ui { ActionButton }

def:pub SpeechInput(sessionId: str, speaker: str, language: str,
                    onSessionChange: Callable[[SessionView], None]) -> JsxElement {
    has listening: bool = False, interim: str = "", locale: str = speech_locale(language),
        error: str = "", available: bool = True;
    has listeningRef: Ref[bool] = Ref(False);
    has speakerRef: Ref[str] = Ref(speaker);
    # Open utterance: {"speaker", "started", "text"} captured at its first interim result.
    has utteranceRef: Ref[any] = Ref(None);
    # Set once a session submits; a later final without new speech is a duplicate
    # (iOS 18 can repeat the final after its early-final workaround).
    has sessionFinalRef: Ref[bool] = Ref(False);
    has queueRef: Ref[list[dict[str, any]]] = Ref([]);
    has drainingRef: Ref[bool] = Ref(False);
    speakerRef.current = speaker;

    # Submit queued turns one at a time so transcript order matches speech order.
    async def drain() -> None {
        updated: SessionView | None = None;
        turn: dict[str, any] = {};
        if drainingRef.current { return; }
        drainingRef.current = True;
        try {
            while queueRef.current and len(queueRef.current) > 0 {
                turn = queueRef.current[0];
                queueRef.current = queueRef.current[1:];
                try {
                    updated = await append_turn(sessionId, turn["speaker"], turn["text"], turn["duration"]);
                    onSessionChange(updated);
                } except Exception {
                    error = "Could not save a spoken turn: " + turn["text"];
                }
            }
        } finally { drainingRef.current = False; }
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
        queueRef.current = (queueRef.current or []) + [{"speaker": who, "text": text.strip(),
            "duration": round(elapsed, 2) if elapsed > 0.0 else 0.0}];
        drain();
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
        listeningRef.current = False;
        listening = False;
        error = speech_error_message(code);
    }
    def begin() -> None {
        sessionFinalRef.current = False;
        ExpoSpeechRecognitionModule.start({"lang": locale.strip(), "interimResults": True,
            "continuous": Platform.OS == "android", "addsPunctuation": True});
    }
    def handleEnd() -> None {
        # A session cut off before its final result keeps its last hypothesis.
        if utteranceRef.current { finalize(utteranceRef.current["text"]); }
        interim = "";
        utteranceRef.current = None;
        if listeningRef.current {
            try { begin(); }
            except Exception {
                listeningRef.current = False;
                listening = False;
                error = "Speech recognition stopped. Tap Start listening to resume.";
            }
        } else { listening = False; }
    }
    useSpeechRecognitionEvent("result", lambda (e: any) { handleResult(e); });
    useSpeechRecognitionEvent("error", lambda (e: any) { handleError(e.error); });
    useSpeechRecognitionEvent("end", lambda { handleEnd(); });

    async def start() -> None {
        permission: any = None;
        error = "";
        try {
            permission = await ExpoSpeechRecognitionModule.requestPermissionsAsync();
        } except Exception {
            error = "Could not request microphone access.";
            return;
        }
        if not permission.granted {
            error = speech_error_message("not-allowed");
            return;
        }
        listeningRef.current = True;
        listening = True;
        try { begin(); }
        except Exception {
            listeningRef.current = False;
            listening = False;
            error = "Could not start speech recognition.";
        }
    }
    def stop() -> None {
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
        if listeningRef.current and utteranceRef.current { ExpoSpeechRecognitionModule.stop(); }
    }
    can with exit {
        if listeningRef.current {
            listeningRef.current = False;
            ExpoSpeechRecognitionModule.abort();
        }
    }
    <View style={styles.card} accessibilityLabel="Speech to text">
        {(<Text style={styles.muted}>
            Speech recognition is unavailable on this device. You can still type turns.
        </Text>) if not available else (<View style={{"gap": 12}}>
            <Text style={styles.label}>Recognition language</Text>
            <TextInput style={styles.input} value={locale} editable={not listening}
                autoCapitalize="none" autoCorrect={False} placeholderTextColor={C.muted}
                placeholder="es-ES" onChangeText={lambda (t: str) { locale = t; }}/>
            {(<ActionButton label="Stop listening" variant="danger" onPress={stop}/>) if listening
                else (<ActionButton label="Start listening" disabled={not locale.strip()}
                    onPress={lambda { start(); }}/>)}
            {(<Text style={styles.muted}>
                {"Listening for " + ("me" if speaker == "learner" else "partner") + "..."}
            </Text>) if listening else <View/>}
            <Text style={styles.interim} accessibilityLiveRegion="polite">{interim}</Text>
        </View>)}
        {(<Text style={styles.error} accessibilityRole="alert">{error}</Text>) if error else <View/>}
    </View>
}
