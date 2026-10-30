"""Translate individual transcript sentences on demand, keeping results in the view."""
import from ..endpoints { translate_sentence }

def:pub TranslationSentence(sessionId: str, turnId: str, sentence: str) -> JsxElement {
    has english: str = "", showingEnglish: bool = False, loading: bool = False, failed: bool = False;
    has pending: Ref[bool] = Ref(False);
    async def toggle() -> None {
        if pending.current { return; }
        if english { showingEnglish = not showingEnglish; return; }
        pending.current = True; loading = True; failed = False;
        try {
            english = await translate_sentence(sessionId, turnId, sentence.strip());
            showingEnglish = True;
        } except Exception { failed = True; }
        finally { pending.current = False; loading = False; }
    }
    <span className="sentence-wrap">
        <button type="button" className={"sentence " + ("sentence-loading" if loading else "")}
            onClick={toggle} disabled={loading} aria-pressed={showingEnglish}
            aria-label={("Show original: " + english) if showingEnglish else ("Translate to English: " + sentence.strip())}>
            {english if showingEnglish else sentence.strip()}
        </button>{" "}
        {loading and <span className="sr-only" role="status">Translating...</span>}
        {failed and <span className="translation-error" role="alert">Could not translate. Tap to retry.</span>}
    </span>
}

def:pub TranscriptText(sessionId: str, turnId: str, text: str) -> JsxElement {
    source: any = text;
    sentences: any = source.match(new(RegExp, "[^.!?。！？]+[.!?。！？]*|[.!?。！？]+", "g")) or [text];
    <span className="turn-text">{[<TranslationSentence key={str(i)} sessionId={sessionId} turnId={turnId} sentence={sentences[i]}/> for i in range(len(sentences))]}</span>
}
