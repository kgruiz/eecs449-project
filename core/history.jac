"""Compact completed-conversation records for the saved library."""
import from .models { Conversation, ConversationSummary }

def conversation_summary(session: Conversation) -> ConversationSummary {
    title = session.target_language + " conversation";

    if session.turns {
        title = session.turns[0].text[:70];
    }

    preview = session.coaching.summary[:180] if session.coaching is not None else "Your transcript is saved. Open it to review and practice.";

    return ConversationSummary(id=jid(session), title=title,
        target_language=session.target_language, level=session.level,
        created_at=session.created_at, turn_count=len(session.turns),
        preview=preview, has_coaching=session.coaching is not None, emoji=session.emoji or "💬");
}

def history_page(sessions: list[Conversation], offset: int, limit: int) -> list[ConversationSummary] {

    if offset < 0 or limit < 1 or limit > 50 {
        raise ValueError("Invalid conversation page.");
    }

    completed = [session for session in sessions if session.status == "ended"];
    completed.sort(key=lambda (session: Conversation) -> str { return session.created_at; }, reverse=True);

    return [conversation_summary(session) for session in completed[offset:offset + limit]];
}
