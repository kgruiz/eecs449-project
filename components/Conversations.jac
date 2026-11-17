import from "lucide-react" { ArrowLeft }

# The alias avoids a duplicate class name in Jac 0.37.23 list-return bridges.
import from ..core.models { SessionView, ConversationSummary as HistoryItem, TranscriptTurn }
import from ..endpoints { list_conversations, get_conversation }
import from .CoachingPanel { CoachingPanel }
import from .TranscriptScroll { TranscriptScroll }
import from .TranscriptDownload { TranscriptDownload }
import from "./conversation-row.jsx" { ConversationRow }
import from "./language-options.js" { shortLanguageName }

def conversation_date(value: str) -> str {

    if not value { return "Earlier conversation"; }

    return new(Date, value).toLocaleString("en-US", {"month": "2-digit", "day": "2-digit", "year": "numeric", "hour": "numeric", "minute": "2-digit", "timeZoneName": "short"});
}

# onSelect reports the open conversation ("" for the list) so the page address can follow.
def:pub Conversations(initialSessionId: str, onTalk: Callable[[], None], active: bool, onSelect: Callable[[str], None]) -> JsxElement {
    has items: list[HistoryItem] = [], selected: SessionView | None = None,
        section: str = "overview", loading: bool = True, opening: bool = False,
        error: str = "", more: bool = False, page: int = 0, requestedId: str = initialSessionId;
    has requestRef: Ref[int] = Ref(0);
    async def loadPage(nextPage: int) -> None {
        loading = True; error = "";

        try {
            loaded = await list_conversations(nextPage * 20, 21);
            items = loaded[:20]; page = nextPage; more = len(loaded) > 20;
        } except Exception { error = "Could not load conversations. Please try again."; }
        finally { loading = False; }
    }
    async def openConversation(id: str) -> None {
        requestRef.current = (requestRef.current or 0) + 1;
        request = requestRef.current;
        requestedId = id; opening = True; error = ""; onSelect(id);

        try {
            loaded = await get_conversation(id);

            if request != requestRef.current { return; }

            selected = loaded; section = "overview";
        } except Exception {

            if request == requestRef.current { error = "Could not open this conversation. Please try again."; }
        } finally {

            if request == requestRef.current { opening = False; }
        }
    }
    def back() -> None {
        requestRef.current = (requestRef.current or 0) + 1;
        selected = None; requestedId = ""; opening = False; error = ""; onSelect("");
        loadPage(page);
    }
    can with entry {
        if initialSessionId { loading = False; openConversation(initialSessionId); }
        else { loadPage(0); }
    }
    can with exit { requestRef.current = (requestRef.current or 0) + 1; }
    <section className={"history-workspace" + (" history-transcript-view" if selected is not None and not opening and section == "transcript" else "")} aria-label="Saved conversations">
        {selected is not None and not opening and <button className="button button-quiet history-back" onClick={back}><ArrowLeft size={16} strokeWidth={1.75} aria-hidden="true"/>All conversations</button>}
        <div className="history-heading">
            <div><h1>{"Conversations" if selected is None else (selected.turns[0].text[:70] if selected.turns else selected.target_language + " conversation")}</h1>
                {selected is not None and <p className="muted">{shortLanguageName(selected.target_language) + " · " + selected.level + " · " + conversation_date(selected.created_at)}</p>}</div>
            <button className={"button history-start " + ("button-secondary" if selected is not None else "button-primary")} onClick={onTalk}>{"Return to conversation" if active else "New conversation"}</button>
        </div>
        {error and <div className="error-banner" role="alert"><p>{error}</p><button className="button button-secondary" onClick={lambda { openConversation(requestedId) if requestedId else loadPage(page); }}>Try again</button></div>}
        {opening and <p role="status">Opening conversation…</p>}
        {selected is None and not opening and <div>
            {loading and <p role="status">Loading your conversations…</p>}
            {not loading and not error and len(items) == 0 and <div className="card history-empty"><h2>No saved conversations</h2><p>After you finish a conversation, find its transcript and practice suggestions here.</p><button className="button button-secondary" onClick={onTalk}>{"Return to conversation" if active else "Start a conversation"}</button></div>}
            {not loading and <div className="home-list">{[<ConversationRow key={item.id} item={item} detailed={True} onOpen={openConversation}/> for item in items]}</div>}
            <div className="history-pagination">
                {page > 0 and <button className="button button-secondary" disabled={loading} onClick={lambda { loadPage(page - 1); }}>Previous</button>}
                {more and <button className="button button-secondary" disabled={loading} onClick={lambda { loadPage(page + 1); }}>Next</button>}
            </div>
        </div>}
        {selected is not None and not opening and <div className="history-detail">
            <nav className="detail-tabs" aria-label="Conversation sections">
                {[<button key={value} className={"detail-tab " + ("is-selected" if section == value else "")} aria-pressed={section == value} onClick={lambda { section = value; }}>{"Practice suggestions" if value == "practice" else value.capitalize()}</button> for value in ["overview", "transcript", "practice"]]}
            </nav>
            <div hidden={section == "transcript"}><CoachingPanel key={selected.id} session={selected} section={section}/></div>
            <div hidden={section != "transcript"} className="card history-transcript">
                <div className="section-heading"><h2>Transcript</h2><TranscriptDownload key={selected.id} session={selected}/></div>
                {len(selected.turns) == 0 and <p className="muted">No turns were recorded in this conversation.</p>}
                <TranscriptScroll key={selected.id} session={selected} onSwapSpeaker={lambda (turn: TranscriptTurn) { }}
                    marks={selected.coaching.priorities if selected.coaching is not None else []}/>
            </div>
        </div>}
    </section>
}
