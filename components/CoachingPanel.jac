import from ..core.models { SessionView }
import from ..endpoints { conversation_feedback }

def:pub CoachingPanel(session: SessionView, section: str = "overview") -> JsxElement {
    has current: SessionView = session, busy: bool = False, error: str = "";
    async def load() -> None {
        busy = True; error = "";

        try { current = await conversation_feedback(session.id); }
        except Exception { error = "Could not generate feedback. Your transcript is saved. Please try again."; }
        finally { busy = False; }
    }
    can with entry {

        if current.coaching is None and any(turn.speaker == "learner" for turn in session.turns) { load(); }
    }
    <section className="card coaching-card" aria-label="Conversation recap" aria-busy={busy}>
        <h2>{"What to practice" if section == "practice" else "Summary"}</h2>
        {busy and <p role="status">Preparing your summary and practice suggestions…</p>}
        {error and <div role="alert"><p>{error}</p><button className="button button-secondary" disabled={busy} onClick={lambda { load(); }}>Retry feedback</button></div>}
        {not any(turn.speaker == "learner" for turn in session.turns) and <p>Add a turn as Me in your next conversation to receive personalized feedback.</p>}
        {current.coaching is not None and <div>
            <div hidden={section != "overview"}><p className="recap-summary">{current.coaching.summary}</p>
            {len(current.coaching.strengths) > 0 and <div><h3>What went well</h3><ul>{[<li key={strength}>{strength}</li> for strength in current.coaching.strengths]}</ul></div>}
            </div>
            <div hidden={section != "practice"}>
            {len(current.coaching.priorities) == 0 and <p>No specific corrections were identified in this transcript.</p>}
            {[<article className="coaching-priority" key={item.turn_id + item.quote}>
                <p className="muted">You said</p><blockquote>{item.quote}</blockquote><p><strong>Try: </strong>{item.suggestion}</p>
                <p>{item.explanation}</p><p><strong>Practice: </strong>{item.practice}</p>
            </article> for item in current.coaching.priorities]}
            </div>
            <p className="coaching-footnote">Based on the saved transcript. Speech recognition can make mistakes.</p>
        </div>}
    </section>
}
