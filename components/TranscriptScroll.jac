"""Bounded transcript viewport that follows new turns until the reader scrolls up."""
import from "lucide-react" { ArrowDown }
import from react { useEffect }
import from ..core.models { SessionView, TranscriptTurn }
import from .Translation { TranscriptText }
import from .SentenceCompletion { CompletionOptions }

def:pub TranscriptScroll(session: SessionView, onSwapSpeaker: Callable[[TranscriptTurn], None],
                         draft: str = "", spoken: bool = False, completions: bool = False) -> JsxElement {
    has away: bool = False;
    has viewport: Ref[any] = Ref(None), content: Ref[any] = Ref(None);
    has following: Ref[bool] = Ref(True);

    def trackScroll() -> None {
        box = viewport.current;

        if not box { return; }

        following.current = box.scrollHeight - box.clientHeight - box.scrollTop <= 48;
        away = not following.current;
    }

    def latest() -> None {
        box = viewport.current;

        if not box { return; }

        following.current = True;
        box.scrollTop = box.scrollHeight;
        away = False;
    }

    # Content can grow after a translation or font loads, not only after new turns.
    useEffect(lambda {
        browser: any = window;
        observer = new(browser.ResizeObserver, lambda {

            if following.current { latest(); }
            else { trackScroll(); }
        });
        observer.observe(content.current);
        observer.observe(viewport.current);

        return lambda { observer.disconnect(); };
    }, []);

    last = session.turns[-1] if session.turns else None;
    savedDraft = bool(spoken and last is not None and last.speaker == "learner" and last.text.strip() == draft.strip());
    contextKey = str([(turn.id, turn.speaker, turn.text) for turn in session.turns]);
    <div className="transcript-scroll-shell">
        <div className="transcript-scroll" ref={viewport} onScroll={trackScroll}
            tabIndex={0} role="region" aria-label="Conversation transcript">
            <ol className="transcript-list" ref={content} aria-live="polite" aria-relevant="additions text">
                {[<li key={turn.id} className={"transcript-turn " + ("turn-learner" if turn.speaker == "learner" else "turn-partner")}>
                    <span className="speaker-avatar" aria-hidden="true">{"M" if turn.speaker == "learner" else "P"}</span>
                    <div className="turn-content"><TranscriptText sessionId={session.id} turnId={turn.id} text={turn.text} speaker={turn.speaker}
                        speakerSource={turn.speaker_source} canCorrect={session.status == "active"}
                        onSpeakerClick={lambda { onSwapSpeaker(turn); }}/>
                    {savedDraft and last is not None and turn.id == last.id and <CompletionOptions sessionId={session.id} draft={draft} contextKey={contextKey} enabled={completions}/>}
                    </div>
                </li> for turn in session.turns]}
                {completions and draft.strip() and not savedDraft and <li className="transcript-turn turn-learner draft-turn">
                    <span className="speaker-avatar" aria-hidden="true">M</span>
                    <div className="turn-content"><p className="eyebrow">Me · in progress</p><p className="turn-text">{draft}</p>
                        <CompletionOptions sessionId={session.id} draft={draft} contextKey={contextKey} enabled={completions}/>
                    </div>
                </li>}
            </ol>
        </div>
        {away and <button type="button" className="latest-button" onClick={latest}
            aria-label="Scroll to latest turn"><ArrowDown size={16} strokeWidth={1.75} aria-hidden="true"/> Latest</button>}
    </div>
}
