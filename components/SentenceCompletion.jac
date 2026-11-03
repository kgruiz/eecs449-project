"""Ephemeral completions for an unchanged learner draft."""
import from ..core.models { SentenceCompletion }
import from ..endpoints { suggest_completion }

glob COMPLETION_PAUSE_MS: int = 4000;

def:pub CompletionOptions(sessionId: str, draft: str, contextKey: str, enabled: bool) -> JsxElement {
    has options: list[str] = [];
    has timer: Ref[any] = Ref(None), generation: Ref[int] = Ref(0);

    async def request(partial: str, requestGeneration: int) -> None {
        result: SentenceCompletion | None = None;
        try {
            result = await suggest_completion(sessionId, partial);
            if generation.current == requestGeneration and result.needed { options = result.options; }
        } except Exception {
            # A transient suggestion failure should not interrupt the conversation.
        }
    }

    can with (draft, contextKey, enabled) entry {
        generation.current += 1;
        options = [];
        if timer.current { clearTimeout(timer.current); timer.current = None; }
        partial = draft.strip();
        if enabled and partial and len(partial) <= 500 {
            requestGeneration = generation.current;
            timer.current = setTimeout(lambda { request(partial, requestGeneration); }, COMPLETION_PAUSE_MS);
        }
    }
    can with exit {
        generation.current += 1;
        if timer.current { clearTimeout(timer.current); }
    }

    <div className="completion-options" aria-label="Sentence completions" aria-live="polite">
        {enabled and [<span key={option} className="completion-option">{option}</span> for option in options]}
    </div>
}
