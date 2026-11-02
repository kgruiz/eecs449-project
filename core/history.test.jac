import from .models { TranscriptTurn, CoachingReport }

def history_session(date: str, status: str = "ended") -> Conversation {

    return Conversation(native_language="English", target_language="Spanish", level="A2",
        status=status, created_at=date, turns=[TranscriptTurn(id="turn", speaker="learner", text="Hola")]);
}

test "history excludes active conversations and orders dated sessions newest first" {
    oldest = history_session("");
    newer = history_session("2026-11-02T20:00:00+00:00");
    older = history_session("2026-11-01T20:00:00+00:00");
    active = history_session("2026-11-03T20:00:00+00:00", "active");
    page = history_page([oldest, older, active, newer], 0, 2);
    assert len(page) == 2;
    assert page[0].created_at == newer.created_at;
    assert page[1].created_at == older.created_at;
    assert history_page([oldest, older, active, newer], 2, 2)[0].created_at == "";
    assert len(history_page([], 0, 20)) == 0;
}

test "history bounds records and does not expose complete transcripts" {
    session = history_session("");
    session.turns[0].text = "a" * 4000;
    session.coaching = CoachingReport(summary="b" * 1000, strengths=[], priorities=[]);
    item = conversation_summary(session);
    assert len(item.title) == 70;
    assert len(item.preview) == 180;
    assert item.turn_count == 1;
    assert item.has_coaching;
    session.turns = [];
    assert conversation_summary(session).title == "Spanish conversation";
}

test "history rejects invalid pagination" {

    for limits in [[-1, 20], [0, 0], [0, 51]] {
        with testraises(ValueError) { history_page([], limits[0], limits[1]); }
    }
}
