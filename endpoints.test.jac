import from unittest.mock { patch }

def fallback_session() -> Conversation {

    return Conversation(native_language="English", target_language="Spanish", level="A2",
        consent_confirmed=True, turns=[TranscriptTurn(id="previous", speaker="learner", text="Hola.")]);
}

test "uncertain voice uses selected speaker instead of alternating" {

    for reason in ["short", "missing", "unavailable", "unenrolled"] {
        session = fallback_session();
        learner = LearnerProfile(voiceprint=[] if reason == "unenrolled" else [1.0]);

        with patch(__name__ + ".owned_session", return_value=session),
             patch(__name__ + ".profile", return_value=learner),
             patch(__name__ + ".learner_similarity", return_value=None,
                 side_effect=ValueError("Model unavailable") if reason == "unavailable" else None) {
            result = append_spoken_turn("session", "Otra frase.", 0.5,
                "" if reason == "missing" else "audio", "learner");
            assert result.turns[-1].speaker == "learner";
            assert result.turns[-1].speaker_source == "manual";
            assert len(result.turns) == 2;
        }
    }
}

test "voice match overrides manual fallback" {
    session = fallback_session();

    with patch(__name__ + ".owned_session", return_value=session),
         patch(__name__ + ".profile", return_value=LearnerProfile(voiceprint=[1.0])),
         patch(__name__ + ".learner_similarity", return_value=1.0) {
        result = append_spoken_turn("session", "Hola.", 2.0, "audio", "partner");
        assert result.turns[-1].speaker == "learner";
        assert result.turns[-1].speaker_source == "voice";
    }
}

test "language help does not require a recorded participant confirmation" {
    session = fallback_session();
    session.consent_confirmed = False;
    with patch(__name__ + ".owned_session", return_value=session),
         patch(__name__ + ".suggest_next_word", return_value=WordHint(word="hola", meaning="hello")),
         patch(__name__ + ".translate_to_english", return_value="Hello.") {
        assert suggest_word("session", "Hol").word == "hola";
        assert translate_sentence("session", "previous", "Hola.") == "Hello.";
    }
}

test "manual speaker turns are saved without a confirmation flag" {
    session = fallback_session();
    session.consent_confirmed = False;
    with patch(__name__ + ".owned_session", return_value=session) {
        assert append_turn("session", "learner", "Hola", 0.5).turns[-1].speaker == "learner";
        assert append_turn("session", "partner", "Buenos días", 0.5).turns[-1].speaker == "partner";
        session.status = "ended";
        with testraises(ValueError) { append_turn("session", "learner", "Late", 0.5); }
    }
}

test "uncertain voice requires valid manual selection and active session" {
    session = fallback_session();

    with patch(__name__ + ".owned_session", return_value=session),
         patch(__name__ + ".profile", return_value=LearnerProfile()) {

        for speaker in ["", "unknown"] {

            with testraises(ValueError) { append_spoken_turn("session", "Hola.", 1.0, "", speaker); }
        }
        session.status = "ended";

        with testraises(ValueError) { append_spoken_turn("session", "Hola.", 1.0, "", "learner"); }
        assert len(session.turns) == 1;
    }
}
