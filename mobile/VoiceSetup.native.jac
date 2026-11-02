"""Voice enrollment: the learner reads a passage aloud once. The recording goes
to enroll_voice, which keeps only a voiceprint (speaker embedding) and discards
the audio; the temporary files on the phone are deleted after upload. Only one
speech session may run at a time, so this is shown only between conversations.

A speech session can end on its own after a second or two (the iOS Simulator
does this on audio reconfiguration), so recording restarts sessions until the
learner taps Done, and every session's file is uploaded together."""
import from "expo-speech-recognition" { ExpoSpeechRecognitionModule, useSpeechRecognitionEvent }
import from "expo-file-system" { File }
import from "@jac/mobui" { View, Text, Switch }
import from ..endpoints { enroll_voice, delete_voice }
import from ..core.speech {
    speech_error_message, ROUTINE_SPEECH_ERRORS, RETRYABLE_SPEECH_ERRORS, MAX_SPEECH_RETRIES,
    RESTART_DELAY_MS, ENROLL_PASSAGE, ENROLL_MIN_SECONDS, ENROLL_MAX_SECONDS
}
import from .theme { styles }
import from .ui { ActionButton, endpoint_error_message }

def:pub VoiceSetup(enrolled: bool, onChange: Callable[[bool], None]) -> JsxElement {
    has recording: bool = False, seconds: int = 0, consent: bool = False,
        busy: bool = False, error: str = "", notice: str = "", redo: bool = False;
    has uriRef: Ref[any] = Ref(None);
    has tickRef: Ref[any] = Ref(None);
    has restartRef: Ref[any] = Ref(None);
    # wantRef: the learner is still recording; activeRef: a session is running.
    has wantRef: Ref[bool] = Ref(False);
    has activeRef: Ref[bool] = Ref(False);
    has clipsRef: Ref[list[str]] = Ref([]);
    has failuresRef: Ref[int] = Ref(0);

    def stopTimers() -> None {
        if tickRef.current { clearInterval(tickRef.current); }
        if restartRef.current { clearTimeout(restartRef.current); }
        tickRef.current = None;
        restartRef.current = None;
    }
    def begin() -> None {
        restartRef.current = None;
        if not wantRef.current or activeRef.current { return; }
        activeRef.current = True;
        try {
            # The transcript is ignored; recognition only drives the recording.
            # Record in the input's native format: the module's 16 kHz downsampling
            # produced near-empty files, and the server resamples anyway.
            ExpoSpeechRecognitionModule.start({"lang": "en-US", "interimResults": False,
                "continuous": True, "recordingOptions": {"persist": True}});
        } except Exception {
            activeRef.current = False;
            stopRecording("Could not start recording.");
        }
    }
    # Stop for good: upload what was captured, or report why recording stopped.
    def stopRecording(reason: str) -> None {
        wantRef.current = False;
        stopTimers();
        if activeRef.current { ExpoSpeechRecognitionModule.stop(); return; }
        recording = False;
        clips = clipsRef.current or [];
        clipsRef.current = [];
        if reason { error = reason; discard(clips); }
        elif len(clips) > 0 { upload(clips); }
        elif not error { error = "Nothing was recorded. Check microphone access and try again."; }
    }
    def finishRecording() -> None { stopRecording(""); }
    def discard(uris: list[str]) -> None {
        for uri in uris {
            try { new(File, uri).delete(); } except Exception { }
        }
    }
    async def upload(uris: list[str]) -> None {
        clips: list[str] = [];
        busy = True;
        try {
            for uri in uris {
                file = new(File, uri);
                clips.append(await file.base64());
                file.delete();
            }
            await enroll_voice(clips, True);
            notice = "Voice recognition is set up.";
            redo = False;
            onChange(True);
        } except Exception as e {
            error = endpoint_error_message(e, "Could not save your voiceprint. Try again.");
        } finally { busy = False; }
    }
    def handleEnd() -> None {
        uri = uriRef.current;
        uriRef.current = None;
        activeRef.current = False;
        if uri {
            clipsRef.current = (clipsRef.current or []) + [uri];
            failuresRef.current = 0;
        }
        if wantRef.current {
            restartRef.current = setTimeout(lambda { begin(); },
                RESTART_DELAY_MS * (failuresRef.current + 1));
        } else { stopRecording(""); }
    }
    def handleError(code: str) -> None {
        if code in ROUTINE_SPEECH_ERRORS { return; }
        # Transient: "end" follows and restarts the session.
        if code in RETRYABLE_SPEECH_ERRORS and failuresRef.current < MAX_SPEECH_RETRIES {
            failuresRef.current = failuresRef.current + 1;
            return;
        }
        wantRef.current = False;
        stopTimers();
        clips = clipsRef.current or [];
        clipsRef.current = [];
        discard(clips);
        error = speech_error_message(code);
        if not activeRef.current { recording = False; }
    }
    useSpeechRecognitionEvent("audioend", lambda (e: any) { uriRef.current = e.uri; });
    useSpeechRecognitionEvent("error", lambda (e: any) { handleError(e.error); });
    useSpeechRecognitionEvent("end", lambda { handleEnd(); });

    async def start() -> None {
        permission: any = None;
        error = ""; notice = "";
        try { permission = await ExpoSpeechRecognitionModule.requestPermissionsAsync(); }
        except Exception { error = "Could not request microphone access."; return; }
        if not permission.granted { error = speech_error_message("not-allowed"); return; }
        seconds = 0;
        recording = True;
        clipsRef.current = [];
        failuresRef.current = 0;
        wantRef.current = True;
        started = Date.now();
        tickRef.current = setInterval(lambda {
            seconds = int((Date.now() - started) / 1000);
            if seconds >= ENROLL_MAX_SECONDS { finishRecording(); }
        }, 500);
        begin();
    }
    async def remove() -> None {
        busy = True; error = ""; notice = "";
        try { await delete_voice(); onChange(False); notice = "Your voiceprint was deleted."; }
        except Exception { error = "Could not delete your voiceprint."; }
        finally { busy = False; }
    }
    can with exit {
        wantRef.current = False;
        stopTimers();
        if activeRef.current { ExpoSpeechRecognitionModule.abort(); }
        discard(clipsRef.current or []);
    }

    <View style={styles.card} accessibilityLabel="Voice recognition">
        <Text style={styles.heading} accessibilityRole="header">Voice recognition</Text>
        {(<View style={{"gap": 12}}>
            <Text style={styles.text}>
                The app recognizes your voice, so it can tell when you are speaking and when your partner is.
            </Text>
            <ActionButton label="Record again" variant="secondary" disabled={busy}
                onPress={lambda { consent = False; notice = ""; redo = True; }}/>
            <ActionButton label="Delete my voiceprint" variant="secondary" disabled={busy}
                onPress={lambda { remove(); }}/>
        </View>) if enrolled and not redo else (<View style={{"gap": 12}}>
            <Text style={styles.text}>
                Read the passage below aloud, in your normal voice, so the app can tell you apart from your partner.
            </Text>
            <Text style={[styles.text, {"fontStyle": "italic"}]}>{ENROLL_PASSAGE}</Text>
            <View style={styles.switchRow}>
                <Switch value={consent} disabled={recording or busy}
                    onValueChange={lambda (v: bool) { consent = v; }}
                    accessibilityLabel="Consent to storing a voiceprint"/>
                <Text style={[styles.text, {"flex": 1}]}>
                    I agree to store a voiceprint: a numeric summary of my voice, not a recording. I can delete it anytime.
                </Text>
            </View>
            {(<View style={{"gap": 12}}>
                <Text style={styles.muted}>{"Recording... " + str(seconds) + "s"}</Text>
                <ActionButton label="Done" disabled={seconds < ENROLL_MIN_SECONDS}
                    onPress={finishRecording}/>
            </View>) if recording else (
                <ActionButton label={"Saving..." if busy else "Start recording"}
                    disabled={busy or not consent} onPress={lambda { start(); }}/>)}
            {(<ActionButton label="Keep my current voiceprint" variant="secondary"
                disabled={recording or busy} onPress={lambda { redo = False; }}/>)
                if enrolled else <View/>}
        </View>)}
        {(<Text style={styles.muted} accessibilityLiveRegion="polite">{notice}</Text>) if notice else <View/>}
        {(<Text style={styles.error} accessibilityRole="alert">{error}</Text>) if error else <View/>}
    </View>
}
