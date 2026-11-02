"""Voice enrollment (web): the learner reads a passage aloud once. The recording is
captured in memory, sent to enroll_voice (which keeps only a voiceprint, never the
audio) and dropped. Shown only between conversations, when the mic is free."""
import from "./audioCapture.js" { createAudioCapture }
import from ..endpoints { enroll_voice, delete_voice }
import from ..core.speech { ENROLL_PASSAGE, ENROLL_MIN_SECONDS, ENROLL_MAX_SECONDS }

"""Pull the server's message out of a failed endpoint call, which the client
runtime reports as 'Function <name> failed: <JSON body>'."""
def endpoint_error_message(err: any, fallback: str) -> str {
    text = str(err.message if err and err.message else err) if err else "";
    start = text.find("{");
    if start >= 0 {
        try {
            body: any = JSON.parse(text[start:]);  # jac:ignore[E1032]
            if body and body.error and body.error.message { return str(body.error.message); }
        } except Exception { }
    }
    return fallback;
}

def:pub VoiceSetup(enrolled: bool, onChange: Callable[[bool], None]) -> JsxElement {
    has recording: bool = False, seconds: int = 0, consent: bool = False,
        busy: bool = False, error: str = "", notice: str = "", redo: bool = False;
    has captureRef: Ref[any] = Ref(None);
    has tickRef: Ref[any] = Ref(None);
    has startedRef: Ref[float] = Ref(0.0);

    def stopTicking() -> None {
        if tickRef.current { clearInterval(tickRef.current); }
        tickRef.current = None;
    }
    async def finish() -> None {
        capture = captureRef.current;
        stopTicking();
        recording = False;
        if not capture { return; }
        audio = capture.clip(startedRef.current, Date.now());
        capture.stop();
        captureRef.current = None;
        if not audio { error = "Nothing was recorded. Check microphone access and try again."; return; }
        busy = True;
        try {
            await enroll_voice([audio], True);
            notice = "Voice recognition is set up.";
            redo = False;
            onChange(True);
        } except Exception as e {
            error = endpoint_error_message(e, "Could not save your voiceprint. Try again.");
        } finally { busy = False; }
    }
    async def start() -> None {
        capture = createAudioCapture();
        error = ""; notice = "";
        try { await capture.start(); }
        except Exception {
            error = "Could not use the microphone. Allow microphone access in your browser and try again.";
            return;
        }
        captureRef.current = capture;
        startedRef.current = Date.now();
        seconds = 0;
        recording = True;
        tickRef.current = setInterval(lambda {
            seconds = int((Date.now() - startedRef.current) / 1000);
            if seconds >= ENROLL_MAX_SECONDS { finish(); }
        }, 500);
    }
    async def remove() -> None {
        busy = True; error = ""; notice = "";
        try { await delete_voice(); onChange(False); notice = "Your voiceprint was deleted."; }
        except Exception { error = "Could not delete your voiceprint."; }
        finally { busy = False; }
    }
    can with exit {
        stopTicking();
        if captureRef.current { captureRef.current.stop(); }
    }

    <section className="voice-setup" aria-label="Voice recognition">
        <p className="eyebrow">Voice recognition</p>
        {(enrolled and not redo) and <div className="form-stack">
            <p className="muted">Pip recognizes your voice, so it can tell when you are speaking and when your partner is.</p>
            <div className="voice-actions">
                <button className="button button-secondary" disabled={busy}
                    onClick={lambda { consent = False; notice = ""; redo = True; }}>Record again</button>
                <button className="button button-quiet" disabled={busy}
                    onClick={lambda { remove(); }}>Delete my voiceprint</button>
            </div>
        </div>}
        {(not enrolled or redo) and <div className="form-stack">
            <p className="muted">Optional: read the passage below aloud, in your normal voice, so Pip can tell you apart from your partner.</p>
            <blockquote className="voice-passage">{ENROLL_PASSAGE}</blockquote>
            <label className="consent-box"><input type="checkbox" checked={consent} disabled={recording or busy}
                onChange={lambda (e: ChangeEvent) { consent = e.target.checked; }}/>
                <span>I agree to store a voiceprint: a numeric summary of my voice, not a recording. I can delete it anytime.</span>
            </label>
            {recording and <div className="voice-actions">
                <span className="voice-recording" aria-live="polite"><span className="status-dot"/>{"Recording... " + str(seconds) + "s"}</span>
                <button className="button button-primary" disabled={seconds < ENROLL_MIN_SECONDS}
                    onClick={lambda { finish(); }}>Done</button>
            </div>}
            <div className="voice-actions">
                {not recording and <button className="button button-secondary" disabled={busy or not consent}
                    onClick={lambda { start(); }}>{"Saving..." if busy else "Start recording"}</button>}
                {(enrolled and not recording) and <button className="button button-quiet" disabled={busy}
                    onClick={lambda { redo = False; }}>Keep my current voiceprint</button>}
            </div>
        </div>}
        {notice and <p className="notice" aria-live="polite">{notice}</p>}
        {error and <p className="voice-error" role="alert">{error}</p>}
    </section>
}
