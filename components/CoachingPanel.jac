import from ..core.models { SessionView }
import from ..endpoints { conversation_feedback }

def:pub CoachingPanel(session: SessionView) -> JsxElement {
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
        <p className="eyebrow">Your next conversation starts here</p>
        <h2>Conversation recap</h2>
        {busy and <p role="status">Preparing your summary and practice suggestions…</p>}
        {error and <div role="alert"><p>{error}</p><button className="button button-secondary" disabled={busy} onClick={lambda { load(); }}>Retry feedback</button></div>}
        {not any(turn.speaker == "learner" for turn in session.turns) and <p>Add a turn as Me in your next conversation to receive personalized feedback.</p>}
        {current.coaching is not None and <div>
            <p>{current.coaching.summary}</p>
            {len(current.coaching.strengths) > 0 and <div><h3>What went well</h3><ul>{[<li key={strength}>{strength}</li> for strength in current.coaching.strengths]}</ul></div>}
            <h3>Work on next time</h3>
            {len(current.coaching.priorities) == 0 and <p>No specific corrections suggested from this transcript. Keep practicing with a longer conversation.</p>}
            {[<article className="coaching-priority" key={item.turn_id + item.quote}>
                <blockquote>{item.quote}</blockquote><p><strong>Try: </strong>{item.suggestion}</p>
                <p>{item.explanation}</p><p><strong>Practice: </strong>{item.practice}</p>
            </article> for item in current.coaching.priorities]}
            <p className="muted">Based on the saved transcript. Speech recognition can make mistakes.</p>
        </div>}
    </section>
}
