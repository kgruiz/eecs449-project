"""Shared contracts; raw audio is never persisted."""
node LearnerProfile {
    has native_language: str = "English", target_language: str = "Spanish", level: str = "A2";
    # Existing profiles predate onboarding and should continue to work.
    has display_name: str = "", onboarding_completed: bool = True, onboarding_step: int = 0;
    # Speaker embedding from voice enrollment (not audio); empty until enrolled.
    has voiceprint: list[float] = [];
}
obj VoiceStatus {
    has enrolled: bool;
}
obj ProfileView {
    has native_language: str, target_language: str, level: str,
        display_name: str, onboarding_completed: bool, onboarding_step: int;
}
"""speaker_source: "manual", "voice" (matched against the voiceprint),
"turn-taking" (legacy guessed attribution) or "corrected" (fixed by the learner)."""
obj TranscriptTurn {
    has id: str, speaker: str, text: str, duration_seconds: float = 0.0,
        speaker_source: str = "manual", speaker_score: float | None = None;
}
# A suggested next word for a learner who stalls mid-sentence; never stored as a turn.
obj WordHint {
    has word: str, meaning: str;
}
sem WordHint.word = "One word in the target language (a short fixed phrase only if one word cannot stand alone) that naturally continues the learner's sentence.";
sem WordHint.meaning = "A gloss of that word in the learner's native language, at most a few words.";
obj PracticePriority {
    has turn_id: str, quote: str, suggestion: str, explanation: str, practice: str;
    has kind: str = "", title: str = "";
}
obj CoachingReport {
    has summary: str, strengths: list[str], priorities: list[PracticePriority];
}
obj ConversationSummary {
    has id: str, title: str, target_language: str, level: str, created_at: str,
        turn_count: int, preview: str, has_coaching: bool, emoji: str = "💬";
}
obj SessionView {
    has id: str, native_language: str, target_language: str, level: str,
        partner_mode: str, status: str, turns: list[TranscriptTurn],
        audio_seconds: float, model_requests: int, coaching: CoachingReport | None = None, created_at: str = "";
}
node Conversation {
    has native_language: str, target_language: str, level: str,
        partner_mode: str = "human", consent_confirmed: bool = False,
        status: str = "active", turns: list[TranscriptTurn] = [],
        audio_seconds: float = 0.0, model_requests: int = 0, coaching: CoachingReport | None = None, created_at: str = "", emoji: str = "";
    def to_view() -> SessionView {
        return SessionView(id=jid(self), native_language=self.native_language,
            target_language=self.target_language, level=self.level,
            partner_mode=self.partner_mode, status=self.status, turns=self.turns,
            audio_seconds=self.audio_seconds, model_requests=self.model_requests, coaching=self.coaching, created_at=self.created_at);
    }
}

obj PracticeFeedback {
    has outcome: str, feedback: str, corrected_answer: str;
}
