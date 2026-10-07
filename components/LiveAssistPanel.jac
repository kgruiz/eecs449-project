import from ..core.models { SessionView }
import from ..features.live_assist { ReplyHint, request_hint, request_partner_turn }
def:pub LiveAssistPanel(session: SessionView, onSessionChange: (SessionView) -> None) -> JsxElement {
    has intent: str = "", hint: ReplyHint | None = None, busy: bool = False, error: str = "";
    async def askHint() -> None {
        result: ReplyHint | None = None;
        error = ""; busy = True;
        try { result = await request_hint(session.id, intent); hint = result; }
        except Exception { error = "Could not get a hint. Add a turn and try again."; }
        finally { busy = False; }
    }
    async def askPartner() -> None {
        result: SessionView | None = None;
        error = ""; busy = True;
        try { result = await request_partner_turn(session.id); onSessionChange(result); }
        except Exception { error = "The AI partner could not reply. Try again."; }
        finally { busy = False; }
    }
    <section>
        <h3>Live conversation assist</h3>
        {session.status == "active" and <div>
            <label>What do you want to say? <input value={intent} maxLength={500}
                onChange={lambda (e: ChangeEvent) { intent = e.target.value; }}/></label>
            <button disabled={busy or len(session.turns) == 0} onClick={askHint}>Help me reply</button>
            {session.partner_mode == "ai" and <button disabled={busy} onClick={askPartner}>Ask AI partner to speak</button>}
        </div>}
        {busy and <p role="status">Thinking...</p>}
        {error and <p role="alert">{error}</p>}
        {hint is not None and <div aria-live="polite"><p>{hint.suggestion}</p><p>{hint.explanation}</p></div>}
    </section>
}
