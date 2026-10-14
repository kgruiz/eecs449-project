"""Browser speech-to-text adapter (Web Speech API). Interim hypotheses stay
client-local; each finalized utterance is submitted once through append_turn
with its speaker and a non-overlapping duration. Raw audio is never stored."""
import from ..core.models { SessionView }
import from ..endpoints { append_turn }

glob SPEECH_LOCALES: dict[str, str] = {
    "arabic": "ar-SA", "chinese": "zh-CN", "mandarin": "zh-CN", "dutch": "nl-NL",
    "english": "en-US", "french": "fr-FR", "german": "de-DE", "hindi": "hi-IN",
    "italian": "it-IT", "japanese": "ja-JP", "korean": "ko-KR", "portuguese": "pt-BR",
    "russian": "ru-RU", "spanish": "es-ES"
};
glob SPEECH_ERRORS: dict[str, str] = {
    "not-allowed": "Microphone access was blocked. Allow it in your browser settings to transcribe.",
    "service-not-allowed": "This browser's speech service is unavailable here.",
    "audio-capture": "No microphone was found.",
    "network": "The browser's speech service could not be reached.",
    "language-not-supported": "This browser cannot transcribe that language. Try a code such as es-ES."
};

"""Map a profile language name to a BCP-47 tag; codes pass through unchanged."""
def speech_locale(language: str) -> str {
    key = language.strip().lower();
    return SPEECH_LOCALES[key] if key in SPEECH_LOCALES else language.strip();
}

def:pub SpeechInput(sessionId: str, speaker: str, language: str,
                    onSessionChange: Callable[[SessionView], None]) -> JsxElement {
    has listening: bool = False, interim: str = "", locale: str = speech_locale(language),
        error: str = "";
    has recognitionRef: Ref[any] = Ref(None);
    has listeningRef: Ref[bool] = Ref(False);
    has speakerRef: Ref[str] = Ref(speaker);
    # Open utterance: {"speaker", "started"} captured at its first interim result.
    has utteranceRef: Ref[any] = Ref(None);
    # Result indices below this were already submitted in the current recognition run.
    has nextFinalRef: Ref[int] = Ref(0);
    has queueRef: Ref[list[dict]] = Ref([]);
    has drainingRef: Ref[bool] = Ref(False);
    # Typed loosely: the checker has no stubs for the (partly prefixed) speech API.
    browser: any = window;
    recognitionClass: any = browser.SpeechRecognition or browser.webkitSpeechRecognition;
    speakerRef.current = speaker;

    # Submit queued turns one at a time so transcript order matches speech order.
    async def drain() -> None {
        updated: SessionView | None = None;
        turn: dict = {};
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
        who = utterance["speaker"] if utterance else speakerRef.current;
        started = utterance["started"] if utterance else Date.now();
        elapsed = (Date.now() - started) / 1000.0;
        queueRef.current = (queueRef.current or []) + [{"speaker": who, "text": text.strip(),
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
    }
    def handleError(code: str) -> None {
        # Silence and our own aborts are routine; onend restarts if still listening.
        if code == "no-speech" or code == "aborted" { return; }
        listeningRef.current = False;
        listening = False;
        error = SPEECH_ERRORS[code] if code in SPEECH_ERRORS else "Speech recognition error: " + code + ".";
    }
    def handleEnd() -> None {
        interim = "";
        utteranceRef.current = None;
        # Browsers end continuous recognition after silence; resume until stopped.
        if listeningRef.current and recognitionRef.current {
            try { recognitionRef.current.start(); }
            except Exception {
                listeningRef.current = False;
                listening = False;
                error = "Speech recognition stopped. Press Start listening to resume.";
            }
        } else { listening = False; }
    }
    def start() -> None {
        recognition: any = None;
        if not recognitionClass { return; }
        error = "";
        recognition = new(recognitionClass);
        recognition.lang = locale.strip();
        recognition.continuous = True;
        recognition.interimResults = True;
        recognition.onstart = lambda { nextFinalRef.current = 0; };
        recognition.onresult = lambda (e: any) { handleResult(e); };
        recognition.onerror = lambda (e: any) { handleError(e.error); };
        recognition.onend = lambda { handleEnd(); };
        recognitionRef.current = recognition;
        listeningRef.current = True;
        listening = True;
        try { recognition.start(); }
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
        if recognitionRef.current { recognitionRef.current.stop(); }
    }
    # Switching speaker mid-utterance flushes it to the previous speaker; onend restarts.
    can with [speaker] entry {
        if listeningRef.current and utteranceRef.current and recognitionRef.current {
            recognitionRef.current.stop();
        }
    }
    can with exit {
        listeningRef.current = False;
        if recognitionRef.current { recognitionRef.current.abort(); }
    }
    <section aria-label="Speech to text">
        {not recognitionClass and <p>
            Live transcription needs a browser with the Web Speech API (Chrome, Edge or Safari). You can still type turns.
        </p>}
        {recognitionClass and <div>
            <label>Recognition language <input value={locale} disabled={listening}
                onChange={lambda (e: ChangeEvent) { locale = e.target.value; }}/></label>
            {listening and <button onClick={stop}>Stop listening</button>}
            {not listening and <button disabled={not locale.strip()} onClick={start}>Start listening</button>}
            {listening and <p><em>{"Listening for " + ("me" if speaker == "learner" else "partner") + "..."}</em></p>}
            <p aria-live="polite"><em>{interim}</em></p>
        </div>}
        {error and <p role="alert">{error}</p>}
    </section>
}
