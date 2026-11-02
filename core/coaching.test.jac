import from unittest.mock { patch }
import from jaclang.byllm.lib { Model, OutputConversionError }
import from .models { TranscriptTurn, PracticePriority }

def sample_session() -> Conversation {
    return Conversation(native_language="English", target_language="Spanish", level="A2",
        status="ended", consent_confirmed=True,
        turns=[TranscriptTurn(id="me", speaker="learner", text="Yo ir al parque."),
            TranscriptTurn(id="them", speaker="partner", text="Hola.")]);
}

def sample_report() -> CoachingReport {
    return CoachingReport(summary="You discussed going to the park.", strengths=["You used parque appropriately."],
        priorities=[PracticePriority(turn_id="me", quote="Yo ir", suggestion="Yo voy al parque.",
            explanation="Use voy for the first-person present tense.", practice="Say three places you go using voy a.")]);
}

test "coaching parses structured output and saves it once" {
    session = sample_session();
    response = {"choices": [{"message": {"role": "assistant", "content": json.dumps({
        "summary": "You discussed going to the park.", "strengths": [], "priorities": [{
            "turn_id": "me", "quote": "Yo ir", "suggestion": "Yo voy al parque.",
            "explanation": "Use voy.", "practice": "Name three places using voy a."}]})}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) as provider {
        first = build_report(session);
        second = build_report(session);
        assert first.summary == second.summary;
        assert session.coaching is not None;
        assert session.model_requests == 1;
        assert provider.call_count == 1;
    }
}

test "coaching rejects partner attribution and fabricated quotes" {

    for kind in ["partner", "fabricated"] {
        session = sample_session();
        feedback = sample_report();

        if kind == "partner" { feedback.priorities[0].turn_id = "them"; feedback.priorities[0].quote = "Hola"; }
        else { feedback.priorities[0].quote = "never said this"; }

        with patch(__name__ + ".generate_report", return_value=feedback) {
            with testraises(ValueError) { build_report(session); }
            assert session.coaching is None;
        }
    }
}

test "coaching requires completed consented learner conversation" {

    for kind in ["active", "consent", "empty", "partner", "long"] {
        session = sample_session();

        if kind == "active" { session.status = "active"; }
        elif kind == "consent" { session.consent_confirmed = False; }
        elif kind == "empty" { session.turns = []; }
        elif kind == "partner" { session.turns = [session.turns[1]]; }
        else { session.turns[0].text = "x" * 100001; }

        with patch(__name__ + ".generate_report") as provider {
            with testraises(ValueError) { build_report(session); }
            assert provider.call_count == 0;
            assert session.model_requests == 0;
        }
    }
}

test "coaching failures preserve ended session and allow retry" {
    session = sample_session();

    with patch(__name__ + ".generate_report", side_effect=ValueError("Provider unavailable")) {
        with testraises(ValueError) { build_report(session); }
    }
    assert session.status == "ended";
    assert session.coaching is None;

    with patch(__name__ + ".generate_report", return_value=sample_report()) {
        assert build_report(session).summary != "";
        assert session.model_requests == 2;
    }
}

test "coaching accepts no corrections but rejects incomplete reports" {
    session = sample_session();
    feedback = CoachingReport(summary="A brief exchange with limited evidence.", strengths=[], priorities=[]);

    with patch(__name__ + ".generate_report", return_value=feedback) {
        assert len(build_report(session).priorities) == 0;
    }

    for kind in ["summary", "practice", "count"] {
        session = sample_session();
        feedback = sample_report();

        if kind == "summary" { feedback.summary = " "; }
        elif kind == "practice" { feedback.priorities[0].practice = ""; }
        else { feedback.priorities = feedback.priorities * 4; }

        with patch(__name__ + ".generate_report", return_value=feedback) {
            with testraises(ValueError) { build_report(session); }
            assert session.coaching is None;
        }
    }
}

test "coaching rejects malformed structured output" {
    response = {"choices": [{"message": {"role": "assistant", "content": "not a feedback"}, "finish_reason": "stop"}], "usage": {}};
    session = sample_session();

    with patch.object(Model, "model_call_no_stream", return_value=response) {
        with testraises(OutputConversionError) { build_report(session); }
        assert session.coaching is None;
    }
}
