"""Suggests the next target-language word when the learner seems stuck.
Struggling means the learner's in-progress sentence (interim speech or typing)
has not changed for PAUSE_MS. If the draft asks how to say a word ("how do I
say bread", "come si dice bread"), that answer is shown above the next word.
Drafts and hints never enter the transcript."""
import from "lucide-react" { Lightbulb }
import from ..core.models { WordHint }
import from ..endpoints { suggest_word }

glob PAUSE_MS: int = 4000;
glob ASKS_FOR_WORD: str = "how (do|would|can|should) (i|you|we) say|how to say|what('s| is) the word for|c[oó]mo se (dice|diz)|c[oó]mo (digo|se llama)|come si dice|comment (dit-on|dit on|on dit|dire)|wie sagt man|wie hei(ß|ss)t|hoe zeg (je|ik)|как (сказать|будет|по-)|怎么说|なんて言う|何と言う|어떻게 말|뭐라고|कैसे (कहते|बोलते|कहें)|كيف (أقول|اقول|نقول|تقول)";

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
        return bool(new(RegExp, "[.!?。！？]$").test(source)) and not asksForWord(text);
    }
    # Common "how do I say X?" phrasings in the app's languages. This only keeps
    # such asides from counting as finished sentences; the model decides whether
    # the draft really asks for a word.
    def asksForWord(text: str) -> bool {
        source: any = text;
        return bool(new(RegExp, ASKS_FOR_WORD, "i").test(source));
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
    # Hints appear above one slim bar so the transcript keeps most of the screen.
    <section className="word-helper" aria-label="Word suggestions">
        {hint is not None and hint.lookup and <p className="word-hint word-hint-lookup" role="status">
            <span className="word-hint-meaning">{"“" + hint.lookup.asked + "”"}</span>
            <span className="word-hint-word">{hint.lookup.word}</span>
        </p>}
        {hint is not None and <p className="word-hint" role="status">
            <span className="word-hint-word">{hint.word}</span>
            <span className="word-hint-meaning">{hint.meaning}</span>
        </p>}
        <div className="word-helper-bar">
            <button type="button" className="word-helper-ask" disabled={loading} onClick={requestHint}>
                <Lightbulb size={16} strokeWidth={1.9} aria-hidden="true"/>{"Finding a word…" if loading else "Suggest a word"}
            </button>
            {failed and <span className="word-helper-error" role="alert">Couldn’t suggest a word. Try again.</span>}
            <label className="word-helper-toggle">
                <input type="checkbox" checked={auto} onChange={lambda (e: ChangeEvent) { auto = e.target.checked; }}/>
                Suggest when I pause
            </label>
        </div>
    </section>
}
