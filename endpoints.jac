"""Shared authenticated pipeline. Audio adapters submit finalized turns here."""
import from .core.models { LearnerProfile, TranscriptTurn, Conversation, SessionView, WordHint }
import from .core.hints { suggest_next_word }
import from uuid { uuid4 }
def profile() -> LearnerProfile {
    profiles = [root -->][?:LearnerProfile];
    if profiles { return profiles[0]; }
    return root ++> LearnerProfile();
}
def owned_session(session_id: str) -> Conversation {
    for session in [root -->][?:Conversation] {
        if jid(session) == session_id { return session; }
    }
    raise ValueError("Conversation not found in your account.");
}
def:protect save_profile(native_language: str, target_language: str, level: str) -> LearnerProfile {
    if not native_language.strip() or not target_language.strip() {
        raise ValueError("Choose both languages.");
    }
    if level not in ["A1", "A2", "B1", "B2", "C1", "C2"] {
        raise ValueError("Choose a CEFR level from A1 to C2.");
    }
    learner = profile();
    learner.native_language = native_language.strip();
    learner.target_language = target_language.strip();
    learner.level = level;
    return learner;
}
def:protect start_conversation(consent_confirmed: bool, partner_mode: str = "human") -> SessionView {
    if not consent_confirmed {
        raise ValueError("All participants must consent to transcription and AI processing.");
    }
    if partner_mode not in ["human", "ai"] { raise ValueError("Unknown partner mode."); }
    learner = profile();
    session = root ++> Conversation(native_language=learner.native_language,
        target_language=learner.target_language, level=learner.level,
        partner_mode=partner_mode, consent_confirmed=True);
    return session.to_view();
}
def:protect get_conversation(session_id: str) -> SessionView {
    return owned_session(session_id).to_view();
}
def:protect append_turn(session_id: str, speaker: str, text: str, duration_seconds: float = 0.0) -> SessionView {
    session = owned_session(session_id);
    if session.status != "active" { raise ValueError("Conversation has ended."); }
    if speaker not in ["learner", "partner"] { raise ValueError("Unknown speaker."); }
    if not text.strip() or len(text) > 4000 { raise ValueError("Provide 1-4000 characters."); }
    if duration_seconds < 0.0 { raise ValueError("Duration cannot be negative."); }
    session.turns = session.turns + [TranscriptTurn(id=str(uuid4()), speaker=speaker,
        text=text.strip(), duration_seconds=duration_seconds)];
    session.audio_seconds += duration_seconds;
    return session.to_view();
}
def:protect end_conversation(session_id: str) -> SessionView {
    session = owned_session(session_id);
    session.status = "ended";
    return session.to_view();
}
def conversation_context(session: Conversation, limit: int = 12) -> str {
    return "\n".join([f"{turn.speaker}: {turn.text}" for turn in session.turns[-limit:]]);
}
# Only the learner's in-progress text is sent; it is not saved as a turn.
def:protect suggest_word(session_id: str, partial_sentence: str) -> WordHint {
    session = owned_session(session_id);
    if session.status != "active" { raise ValueError("Conversation has ended."); }
    if not session.consent_confirmed { raise ValueError("Participant consent is required."); }
    partial = partial_sentence.strip();
    if len(partial) > 500 { raise ValueError("Provide at most 500 characters."); }
    if not partial and not session.turns { raise ValueError("Start the conversation before asking for a word."); }
    session.model_requests += 1;
    return suggest_next_word(partial, conversation_context(session), session.target_language,
        session.native_language, session.level);
}
