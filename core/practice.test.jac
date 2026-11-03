import from unittest.mock { patch }
import from jaclang.byllm.lib { Model }
import from .models { TranscriptTurn, CoachingReport, PracticePriority }

def practice_session() -> Conversation {
    return Conversation(native_language="English", target_language="Spanish", level="A2", status="ended", consent_confirmed=True,
        turns=[TranscriptTurn(id="me", speaker="learner", text="Yo ir al parque.")],
        coaching=CoachingReport(summary="A visit to the park.", strengths=[], priorities=[PracticePriority(
            turn_id="me", quote="Yo ir", suggestion="Yo voy", explanation="Use voy.", practice="Say where you go on Saturdays.")]));
}

test "practice validates session and input before calling provider" {

    for kind in ["active", "consent", "missing", "index", "negative", "empty", "long", "partner"] {
        session = practice_session();
        index = 0;
        answer = "Voy a la biblioteca.";

        if kind == "active" { session.status = "active"; }
        elif kind == "consent" { session.consent_confirmed = False; }
        elif kind == "missing" { session.coaching = None; }
        elif kind == "index" { index = 1; }
        elif kind == "negative" { index = -1; }
        elif kind == "empty" { answer = " "; }
        elif kind == "long" { answer = "x" * 2001; }
        else { session.turns[0].speaker = "partner"; }

        with patch(__name__ + ".evaluate_answer") as provider {
            with testraises(ValueError) { check_answer(session, index, answer); }
            assert provider.call_count == 0;
            assert session.model_requests == 0;
        }
    }
}

test "practice parses provider feedback without modifying saved transcript" {
    session = practice_session();
    response = {"choices": [{"message": {"role": "assistant", "content": json.dumps({
        "outcome": "correct", "feedback": "You used voy correctly to describe where you go.", "corrected_answer": ""})}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) as provider {
        result = check_answer(session, 0, "Voy a la biblioteca.");
        assert result.outcome == "correct";
        assert provider.call_count == 1;
        assert session.model_requests == 1;
        assert len(session.turns) == 1;
        assert session.turns[0].text == "Yo ir al parque.";
        assert session.coaching is not None;
        assert session.coaching.summary == "A visit to the park.";
    }
}

test "practice rejects invalid feedback and preserves retry" {
    session = practice_session();

    for feedback in [PracticeFeedback(outcome="wrong", feedback="Try again.", corrected_answer=""),
        PracticeFeedback(outcome="correct", feedback="", corrected_answer=""),
        PracticeFeedback(outcome="revise", feedback="Use voy.", corrected_answer="")] {

        with patch(__name__ + ".evaluate_answer", return_value=feedback) {
            with testraises(ValueError) { check_answer(session, 0, "Yo ir."); }
        }
    }

    with patch(__name__ + ".evaluate_answer", side_effect=ValueError("offline")) {
        with testraises(ValueError) { check_answer(session, 0, "Yo ir."); }
    }

    with patch(__name__ + ".evaluate_answer", return_value=PracticeFeedback(outcome="revise", feedback="Use voy.", corrected_answer="Yo voy.")) {
        assert check_answer(session, 0, "Yo ir.").corrected_answer == "Yo voy.";
        assert len(session.turns) == 1;
    }
}
