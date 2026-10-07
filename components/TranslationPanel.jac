import from ..core.models { SessionView }
import from ..features.translation { TranslationView, request_translation }
def:pub TranslationPanel(session: SessionView) -> JsxElement {
    has selected_turn: str = "", translation: TranslationView | None = None,
        busy: bool = False, error: str = "";
    async def translate(turn_id: str) -> None {
        result: TranslationView | None = None;
        error = ""; busy = True;
        try { result = await request_translation(session.id, turn_id); translation = result; }
        except Exception { error = "Could not translate this sentence. Choose a finalized turn and try again."; }
        finally { busy = False; }
    }
    <section>
        <h3>Tap to translate</h3>
        <button disabled={busy or len(session.turns) == 0} onClick={lambda { translate(""); }}>Translate latest partner sentence</button>
        <label>Or choose a turn <select value={selected_turn}
            onChange={lambda (e: ChangeEvent) { selected_turn = e.target.value; }}>
            <option value="">Select a sentence</option>
            {[<option key={turn.id} value={turn.id}>{turn.speaker}: {turn.text}</option> for turn in session.turns]}
        </select></label>
        <button disabled={busy or not selected_turn} onClick={lambda { translate(selected_turn); }}>Translate selected sentence</button>
        {busy and <p role="status">Translating...</p>}
        {error and <p role="alert">{error}</p>}
        {translation is not None and <div aria-live="polite">
            <p>{translation.source_text}</p>
            <p><strong>{translation.destination_language}: </strong>{translation.translated_text}</p>
        </div>}
    </section>
}
