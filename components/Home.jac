import from "lucide-react" { ArrowRight, MessageCircle, Plus }
import from ..core.models { ConversationSummary as HomeItem }
import from ..endpoints { list_conversations }

def:pub Home(name: str, active: bool, onNew: Callable[[], None], onOpen: Callable[[str], None], onAll: Callable[[], None]) -> JsxElement {
    has items: list[HomeItem] = [], loading: bool = True, error: bool = False;
    async def load() -> None {
        loading = True; error = False;
        try { items = await list_conversations(0, 3); }
        except Exception { error = True; }
        finally { loading = False; }
    }
    can with entry { load(); }
    <section className="home-screen">
        <div className="home-hero"><div><p className="eyebrow">YOUR SPACE TO GROW</p><h1>{"Welcome back, " + name if name else "Welcome to Pip"}</h1><p>Every conversation is a chance to learn.</p><button className="button button-primary home-start" onClick={onNew}><Plus size={20}/>{"Return to conversation" if active else "Start a conversation"}</button></div><div className="speech-art home-hero-art" aria-hidden="true"><span className="speech-bubble speech-bubble-back"/><span className="speech-bubble speech-bubble-front"><i/><i/><i/></span><span className="speech-spark">✦</span></div></div>
        <div className="home-heading"><h2>Recent conversations</h2><button className="home-view-all" onClick={onAll}>View all <ArrowRight size={17}/></button></div>
        {loading and <p role="status" className="muted">Loading your conversations…</p>}
        {error and <div className="error-banner" role="alert">Could not load conversations. <button onClick={load}>Try again</button></div>}
        {not loading and not error and len(items) == 0 and <div className="home-empty"><div className="home-empty-icon"><MessageCircle size={34}/></div><h3>Your conversations will live here.</h3><p>Start a conversation to save a transcript and revisit your learning.</p><button className="button button-primary" onClick={onNew}>{"Return to conversation" if active else "Start a conversation"}</button></div>}
        {not loading and <div className="home-list">{[<button key={item.id} className="home-conversation" onClick={lambda { onOpen(item.id); }}><span className="conversation-emoji" aria-hidden="true">{item.emoji}</span><span className="home-conversation-copy"><strong>{item.title}</strong><span>{item.target_language + " · " + (new(Date, item.created_at).toLocaleDateString() if item.created_at else "Earlier conversation")}</span><small>{item.preview}</small></span><ArrowRight size={19}/></button> for item in items]}</div>}
    </section>
}
