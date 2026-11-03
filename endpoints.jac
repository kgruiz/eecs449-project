"""Shared authenticated pipeline. Audio adapters submit finalized turns here."""
import from .core.models { LearnerProfile, TranscriptTurn, Conversation, SessionView, VoiceStatus, WordHint, ConversationSummary, PracticeFeedback }
import from .core.voiceprint { enroll, learner_similarity, MATCH_THRESHOLD }
import from .core.hints { suggest_next_word }
import from uuid { uuid4 }
import from datetime { datetime, timezone }
import from .core.history { history_page }
import from .core.coaching { build_report }
import from .core.practice { check_answer }
import from .core.ai { translate_to_english }
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
        partner_mode=partner_mode, consent_confirmed=True, created_at=datetime.now(timezone.utc).isoformat());
    return session.to_view();
}
def:protect get_conversation(session_id: str) -> SessionView {
    return owned_session(session_id).to_view();
}
def add_turn(session: Conversation, speaker: str, text: str, duration_seconds: float,
             speaker_source: str = "manual", speaker_score: float | None = None) -> SessionView {
    if session.status != "active" { raise ValueError("Conversation has ended."); }
    if speaker not in ["learner", "partner"] { raise ValueError("Unknown speaker."); }
    if not text.strip() or len(text) > 4000 { raise ValueError("Provide 1-4000 characters."); }
    if duration_seconds < 0.0 { raise ValueError("Duration cannot be negative."); }
    session.turns = session.turns + [TranscriptTurn(id=str(uuid4()), speaker=speaker,
        text=text.strip(), duration_seconds=duration_seconds, speaker_source=speaker_source,
        speaker_score=speaker_score)];
    session.audio_seconds += duration_seconds;
    return session.to_view();
}
def:protect append_turn(session_id: str, speaker: str, text: str, duration_seconds: float = 0.0) -> SessionView {
    return add_turn(owned_session(session_id), speaker, text, duration_seconds);
}
def:protect voice_status() -> VoiceStatus {
    return VoiceStatus(enrolled=len(profile().voiceprint) > 0);
}
"""Store the learner's voiceprint from one or more WAV clips of a single
enrollment (joined in order); the audio itself is discarded."""
def:protect enroll_voice(audio_clips: list[str], consent_confirmed: bool) -> VoiceStatus {
    if not consent_confirmed {
        raise ValueError("Agree to storing a voiceprint to set up voice recognition.");
    }
    learner = profile();
    if not audio_clips or len(audio_clips) > 50 { raise ValueError("Send 1-50 audio clips."); }
    learner.voiceprint = enroll(audio_clips);
    return VoiceStatus(enrolled=True);
}
def:protect delete_voice() -> VoiceStatus {
    profile().voiceprint = [];
    return VoiceStatus(enrolled=False);
}
"""Append a spoken turn, attributing it by voice. The WAV is used only for the
match and never stored. Speech too short to judge alternates with the last turn."""
def:protect append_spoken_turn(session_id: str, text: str, duration_seconds: float,
                               audio_b64: str) -> SessionView {
    session = owned_session(session_id);
    voiceprint = profile().voiceprint;
    score: float | None = None;
    if voiceprint and audio_b64 {
        # Bad audio or an unavailable model must not lose the turn; fall back below.
        try { score = learner_similarity(audio_b64, voiceprint); }
        except Exception { score = None; }
    }
    if score is None {
        last = session.turns[-1].speaker if session.turns else "learner";
        return add_turn(session, "learner" if last == "partner" else "partner", text,
            duration_seconds, "turn-taking");
    }
    return add_turn(session, "learner" if score >= MATCH_THRESHOLD else "partner", text,
        duration_seconds, "voice", round(score, 3));
}
def:protect set_turn_speaker(session_id: str, turn_id: str, speaker: str) -> SessionView {
    session = owned_session(session_id);
    if speaker not in ["learner", "partner"] { raise ValueError("Unknown speaker."); }
    if session.status != "active" { raise ValueError("Conversation has ended."); }
    found = False;
    turns: list[TranscriptTurn] = [];
    for turn in session.turns {
        if turn.id == turn_id {
            found = True;
            turns.append(TranscriptTurn(id=turn.id, speaker=speaker, text=turn.text,
                duration_seconds=turn.duration_seconds, speaker_source="corrected",
                speaker_score=turn.speaker_score));
        } else { turns.append(turn); }
    }
    if not found { raise ValueError("Turn not found."); }
    session.turns = turns;
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

def:protect translate_sentence(session_id: str, turn_id: str, sentence: str) -> str {
    session = owned_session(session_id);
    if not session.consent_confirmed { raise ValueError("Participant consent is required."); }
    if not sentence.strip() or len(sentence) > 4000 { raise ValueError("Invalid sentence."); }
    for turn in session.turns {
        if turn.id == turn_id and sentence.strip() in turn.text {
            return translate_to_english(sentence.strip());
        }
    }
    raise ValueError("Sentence not found in this conversation.");
}

# Feedback generation is separate so a provider failure cannot undo completion.
def:protect conversation_feedback(session_id: str) -> SessionView {
    session = owned_session(session_id);
    build_report(session);

    return session.to_view();
}

def:protect list_conversations(offset: int, limit: int) -> list[ConversationSummary] {

    return history_page([root -->][?:Conversation], offset, limit);
}

# Practice answers are assessed separately and never appended to the transcript.
def:protect check_practice_answer(session_id: str, priority_index: int, answer: str) -> PracticeFeedback {

    return check_answer(owned_session(session_id), priority_index, answer);
}
