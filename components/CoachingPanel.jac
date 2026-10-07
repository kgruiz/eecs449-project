import from ..core.models { SessionView }
import from ..features.coaching { CoachingView, PracticeLesson, request_coaching, request_lesson }
def:pub CoachingPanel(session: SessionView) -> JsxElement {
    has coaching: CoachingView | None = None, lesson: PracticeLesson | None = None,
        busy: bool = False, error: str = "", show_answers: bool = False;
    async def getReport() -> None {
        result: CoachingView | None = None;
        error = ""; busy = True;
        try { result = await request_coaching(session.id); coaching = result; }
        except Exception { error = "Could not create a report. End the conversation with learner turns and retry."; }
        finally { busy = False; }
    }
    async def getLesson() -> None {
        result: PracticeLesson | None = None;
        error = ""; busy = True;
        try { result = await request_lesson(session.id); lesson = result; show_answers = False; }
        except Exception { error = "Could not create your practice lesson. Try again."; }
        finally { busy = False; }
    }
    <section>
        <h3>Post-conversation coaching</h3>
        {session.status != "ended" and <p>End your conversation to get personalized feedback.</p>}
        <button disabled={busy or session.status != "ended"} onClick={getReport}>Get coaching report</button>
        {busy and <p role="status">Preparing your feedback...</p>}
        {error and <p role="alert">{error}</p>}
        {coaching is not None and <div aria-live="polite">
            <p>{coaching.analysis.summary}</p>
            <h4>What went well</h4>
            <ul>{[<li key={idx}>{strength}</li> for (idx, strength) in enumerate(coaching.analysis.strengths)]}</ul>
            <h4>Specific feedback</h4>
            {len(coaching.analysis.feedback) == 0 and <p>No clear grammar or vocabulary mistakes were identified.</p>}
            {[<article key={idx}>
                <strong>{item.category}</strong><p>You said: {item.original}</p>
                <p>Try: {item.correction}</p><p>{item.explanation}</p>
            </article> for (idx, item) in enumerate(coaching.analysis.feedback)]}
            <h4>Next steps</h4>
            <ul>{[<li key={idx}>{step}</li> for (idx, step) in enumerate(coaching.analysis.next_steps)]}</ul>
            <p>{coaching.pronunciation_note}</p><p>{coaching.fluency_note}</p>
            <button disabled={busy or len(coaching.analysis.feedback) == 0} onClick={getLesson}>Create practice lesson</button>
        </div>}
        {lesson is not None and <section>
            <h4>{lesson.title}</h4><p>{lesson.objective}</p>
            <ol>{[<li key={idx}><p>{exercise.prompt}</p>
                {show_answers and <div><p>{exercise.answer}</p><p>{exercise.explanation}</p></div>}
            </li> for (idx, exercise) in enumerate(lesson.exercises)]}</ol>
            <button onClick={lambda { show_answers = not show_answers; }}>{show_answers and "Hide answers" or "Reveal answers"}</button>
        </section>}
    </section>
}
