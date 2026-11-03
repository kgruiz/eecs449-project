"""Translate a full turn while keeping the original transcript visible."""
import from "lucide-react" { Languages, LoaderCircle }
import from ..endpoints { translate_sentence }

def:pub TranscriptText(sessionId: str, turnId: str, text: str, speaker: str,
                       speakerSource: str, canCorrect: bool, onSpeakerClick: Callable[[], None]) -> JsxElement {
    has english: str = "", showingEnglish: bool = False, loading: bool = False, failed: bool = False;
    has pending: Ref[bool] = Ref(False);

    async def toggle() -> None {

        if pending.current { return; }

        if english { showingEnglish = not showingEnglish; return; }

        pending.current = True; loading = True; failed = False;

        try {
            english = await translate_sentence(sessionId, turnId, text.strip());
            showingEnglish = True;
        } except Exception { failed = True; }
        finally { pending.current = False; loading = False; }
    }

    label = "Translating..." if loading else ("Hide translation" if showingEnglish else ("Retry translation" if failed else "Translate to English"));
    <div className="turn-content">
        <div className="turn-heading">
            <button type="button" className="eyebrow speaker-switch" disabled={not canCorrect}
                title="Switch between Me and Partner" onClick={onSpeakerClick}>
                {("Me" if speaker == "learner" else "Partner")
                    + (" · guessed" if speakerSource == "turn-taking" else "")}
            </button>
            <div className="translation-action">
                <button type="button" className={"translate-button " + ("is-active" if showingEnglish else "")}
                    onClick={toggle} disabled={loading} aria-label={label} aria-expanded={showingEnglish}
                    aria-controls={"translation-" + turnId}>
                    {loading and <LoaderCircle className="translation-spinner" size={20} strokeWidth={1.75} aria-hidden="true"/>}
                    {not loading and <Languages size={20} strokeWidth={1.75} aria-hidden="true"/>}
                </button>
                <span className="translation-tooltip" aria-hidden="true">{label}</span>
            </div>
        </div>
        <p className="turn-text">{text}</p>
        <div id={"translation-" + turnId} hidden={not showingEnglish} className="translation-result" lang="en">
            <p className="translation-label">English</p>
            <p className="translation-text">{english}</p>
        </div>
        {loading and <span className="sr-only" role="status">Translating to English...</span>}
        {failed and <p className="translation-error" role="alert">{"This turn is too long to translate (4,000 characters maximum)." if len(text.strip()) > 4000 else "Could not translate. Use the translate icon to retry."}</p>}
    </div>
}
