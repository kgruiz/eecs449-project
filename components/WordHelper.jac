"""Suggests the next target-language word when the learner seems stuck.
Struggling means the learner's in-progress sentence (interim speech or typing)
has not changed for PAUSE_MS. Drafts and hints never enter the transcript."""
import from ..core.models { WordHint }
import from ..endpoints { suggest_word }

glob PAUSE_MS: int = 4000;

def:pub WordHelper(sessionId: str, draft: str, learnerSpeaking: bool) -> JsxElement {
    has hint: WordHint | None = None, hintFor: str = "", loading: bool = False,
        failed: bool = False, auto: bool = True;
    has timerRef: Ref[any] = Ref(None);
    has pendingRef: Ref[bool] = Ref(False);
    has draftRef: Ref[str] = Ref(draft);
    draftRef.current = draft;

    async def requestHint() -> None {
        result: WordHint | None = None;
        requested = (draftRef.current or "").strip();
        if pendingRef.current { return; }
        pendingRef.current = True; loading = True; failed = False;
        try {
            result = await suggest_word(sessionId, requested);
            # Drop a late hint if the learner kept going while it loaded.
            if (draftRef.current or "").strip() == requested { hint = result; hintFor = requested; }
        } except Exception { failed = True; }
        finally { pendingRef.current = False; loading = False; }
    }
    def looksFinished(text: str) -> bool {
        source: any = text;
        return bool(new(RegExp, "[.!?。！？]$").test(source));
    }
    # Restart the pause timer whenever the draft changes; a stale hint is cleared.
    can with (draft, learnerSpeaking, auto) entry {
        current = draft.strip();
        if timerRef.current { clearTimeout(timerRef.current); timerRef.current = None; }
        if hint is not None and current != hintFor { hint = None; }
        if auto and learnerSpeaking and current and current != hintFor and not looksFinished(current) {
            timerRef.current = setTimeout(lambda { requestHint(); }, PAUSE_MS);
        }
    }
    can with exit {
        if timerRef.current { clearTimeout(timerRef.current); }
    }
    <section className="word-helper" aria-label="Word suggestions">
        <div className="word-helper-heading">
            <p className="eyebrow">Need a word?</p>
            <label className="word-helper-toggle">
                <input type="checkbox" checked={auto} onChange={lambda (e: ChangeEvent) { auto = e.target.checked; }}/>
                Suggest when I pause
            </label>
        </div>
        {hint is not None and <p className="word-hint" role="status">
            <span className="word-hint-word">{hint.word}</span>
            <span className="word-hint-meaning">{hint.meaning}</span>
        </p>}
        {loading and <p className="word-helper-status" role="status">Finding a word...</p>}
        {failed and <p className="word-helper-error" role="alert">Could not suggest a word. Try again.</p>}
        <button className="button button-secondary" disabled={loading} onClick={requestHint}>Suggest a word</button>
    </section>
}
