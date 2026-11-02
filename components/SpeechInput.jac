"""Browser speech-to-text adapter (Web Speech API). Interim hypotheses stay
client-local; each finalized utterance is submitted once with a non-overlapping
duration. Raw audio is never stored.

With voice recognition set up (voiceEnabled), the microphone is also captured in
memory; each utterance's audio (from its first interim result, padded, to its
final result) goes with it to append_spoken_turn, which decides the speaker from
the learner's voiceprint. Otherwise the turn goes to append_turn with the
manually selected speaker."""
import from "./audioCapture.js" { createAudioCapture }
import from ..core.models { SessionView }
import from ..endpoints { append_turn, append_spoken_turn }
import from ..core.speech { speech_locale, speech_error_message, ROUTINE_SPEECH_ERRORS }

# Audio kept before an utterance's first interim result (recognition lags speech),
# and assumed for a final that arrives without any interim result.
glob UTTERANCE_PAD_MS: int = 700, UNTIMED_UTTERANCE_MS: int = 3000;

def:pub SpeechInput(sessionId: str, speaker: str, language: str, voiceEnabled: bool,
                    onSessionChange: Callable[[SessionView], None],
                    onDraft: Callable[[str, str], None] | None = None,
                    onBusyChange: Callable[[bool], None] | None = None) -> JsxElement {
    has listening: bool = False, interim: str = "", locale: str = speech_locale(language),
        error: str = "";
    has saving: bool = False, settling: bool = False;
    has recognitionRef: Ref[any] = Ref(None);
    has listeningRef: Ref[bool] = Ref(False);
    has speakerRef: Ref[str] = Ref(speaker);
    # Open utterance: {"speaker", "started"} captured at its first interim result.
    has utteranceRef: Ref[any] = Ref(None);
    # Result indices below this were already submitted in the current recognition run.
    has nextFinalRef: Ref[int] = Ref(0);
    has queueRef: Ref[list[dict[str, any]]] = Ref([]);
    has drainingRef: Ref[bool] = Ref(False);
    has captureRef: Ref[any] = Ref(None);
    # Typed loosely: the checker has no stubs for the (partly prefixed) speech API.
    browser: any = window;
    recognitionClass: any = browser.SpeechRecognition or browser.webkitSpeechRecognition;
    speakerRef.current = speaker;

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
                        updated = await append_spoken_turn(sessionId, turn["text"], turn["duration"], turn["audio"]);
                    } else {
                        updated = await append_turn(sessionId, turn["speaker"], turn["text"], turn["duration"]);
                    }
                    onSessionChange(updated);
                    if turn["voice"] and updated is not None and updated.turns {
                        detected = updated.turns[-1];
                        reportDraft(detected.speaker, detected.text);
                    }
                } except Exception {
                    error = "Could not save a spoken turn: " + turn["text"];
                }
            }
        } finally { drainingRef.current = False; saving = False; }
    }
    def reportDraft(who: str, text: str) -> None {
        if onDraft { onDraft(who, text); }
    }
    def finalize(text: str) -> None {
        utterance = utteranceRef.current;
        utteranceRef.current = None;
        interim = "";
        if not text.strip() { return; }
        who = utterance["speaker"] if utterance else speakerRef.current;
        started = utterance["started"] if utterance else Date.now();
        now = Date.now();
        elapsed = (now - started) / 1000.0;
        audio = "";
        if voiceEnabled and captureRef.current {
            begin = (started - UTTERANCE_PAD_MS) if utterance else (now - UNTIMED_UTTERANCE_MS);
            audio = captureRef.current.clip(begin, now);
        }
        if not voiceEnabled { reportDraft(who, text.strip()); }
        queueRef.current = (queueRef.current or []) + [{"speaker": who, "text": text.strip(),
            "voice": voiceEnabled, "audio": audio,
            "duration": round(elapsed, 2) if elapsed > 0.0 else 0.0}];
        drain();
    }
    def handleResult(event: any) -> None {
        pending = "";
        i = event.resultIndex;
        while i < event.results.length {
            result = event.results[i];
            if result.isFinal {
                if i >= (nextFinalRef.current or 0) {
                    nextFinalRef.current = i + 1;
                    finalize(result[0].transcript);
                }
            } else {
                pending = pending + result[0].transcript;
            }
            i += 1;
        }
        if pending.strip() and not utteranceRef.current {
            utteranceRef.current = {"speaker": speakerRef.current, "started": Date.now()};
        }
        interim = pending;
        if pending.strip() and not voiceEnabled {
            reportDraft(utteranceRef.current["speaker"] if utteranceRef.current else speakerRef.current, pending);
        }
    }
    def handleError(code: str) -> None {
        # Silence and our own aborts are routine; onend restarts if still listening.
        if code in ROUTINE_SPEECH_ERRORS { return; }
        listeningRef.current = False;
        listening = False;
        stopCapture();
        error = speech_error_message(code);
    }
    def handleEnd() -> None {
        settling = False;
        interim = "";
        utteranceRef.current = None;
        # Browsers end continuous recognition after silence; resume until stopped.
        if listeningRef.current and recognitionRef.current {
            settling = True;
            try { recognitionRef.current.start(); }
            except Exception {
                listeningRef.current = False;
                listening = False;
                settling = False;
                error = "Speech recognition stopped. Press Start listening to resume.";
                stopCapture();
            }
        } else { listening = False; stopCapture(); }
    }
    def stopCapture() -> None {
        if captureRef.current { captureRef.current.stop(); }
        captureRef.current = None;
    }
    async def start() -> None {
        recognition: any = None;
        capture: any = None;
        if not recognitionClass or listeningRef.current { return; }
        error = "";
        # Mark listening before the mic prompt so Start can't run twice meanwhile.
        listeningRef.current = True;
        listening = True;
        if voiceEnabled {
            capture = createAudioCapture();
            try { await capture.start(); captureRef.current = capture; }
            except Exception {
                error = "Could not use the microphone for speaker recognition; turns will be guessed.";
            }
            # Stopped (or unmounted) while the prompt was open.
            if not listeningRef.current { stopCapture(); return; }
        }
        recognition = new(recognitionClass);
        recognition.lang = locale.strip();
        recognition.continuous = True;
        recognition.interimResults = True;
        recognition.onstart = lambda { nextFinalRef.current = 0; };
        recognition.onresult = lambda (e: any) { handleResult(e); };
        recognition.onerror = lambda (e: any) { handleError(e.error); };
        recognition.onend = lambda { handleEnd(); };
        recognitionRef.current = recognition;
        settling = True;
        try { recognition.start(); }
        except Exception {
            listeningRef.current = False;
            listening = False;
            stopCapture();
            settling = False;
            error = "Could not start speech recognition.";
        }
    }
    def stop() -> None {
        listeningRef.current = False;
        listening = False;
        # Keep capturing until onend, so the final result can still cut its audio.
        # stop() (unlike abort()) still delivers the final result for the open utterance.
        if recognitionRef.current { recognitionRef.current.stop(); }
    }
    # Switching speaker mid-utterance flushes it to the previous speaker; onend restarts.
    can with [speaker] entry {
        if not voiceEnabled and listeningRef.current and utteranceRef.current and recognitionRef.current {
            recognitionRef.current.stop();
        }
    }
    can with exit {
        listeningRef.current = False;
        if recognitionRef.current { recognitionRef.current.abort(); }
        stopCapture();
    }
    <section className="speech-panel" aria-label="Speech to text">
        {(listening or saving or settling) and <div className="speech-status" role="status">
            <span className="speech-indicator" aria-hidden="true">
                <svg className="speech-mic-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                    <rect x="9" y="3" width="6" height="11" rx="3"/>
                    <path d="M6 10v2a6 6 0 0 0 12 0v-2M12 18v3m-3 0h6"/>
                </svg>
            </span>
            <span>{("Listening..." if voiceEnabled
                else "Listening for " + ("me" if speaker == "learner" else "partner")) if listening else "Saving spoken turns..."}</span>
        </div>}
        {not recognitionClass and <p className="muted">
            Live transcription needs a browser with the Web Speech API (Chrome, Edge or Safari). You can still type turns.
        </p>}
        {recognitionClass and <div className="speech-controls">
            <label className="field">Recognition language <input value={locale} disabled={listening}
                onChange={lambda (e: ChangeEvent) { locale = e.target.value; }}/></label>
            {listening and <button className="button button-secondary" onClick={stop}>Stop listening</button>}
            {not listening and <button className="button button-primary" disabled={not locale.strip()} onClick={lambda { start(); }}>
                <svg className="speech-mic-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true" focusable="false">
                    <rect x="9" y="3" width="6" height="11" rx="3"/>
                    <path d="M6 10v2a6 6 0 0 0 12 0v-2M12 18v3m-3 0h6"/>
                </svg>
                Start listening
            </button>}
            <p className="interim-text" aria-live="polite">{interim}</p>
        </div>}
        {error and <p className="speech-error" role="alert">{error}</p>}
    </section>
}
