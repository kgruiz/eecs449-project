"""Shared contracts; raw audio is never persisted."""
node LearnerProfile {
    has native_language: str = "English", target_language: str = "Spanish", level: str = "A2";
    # Speaker embedding from voice enrollment (not audio); empty until enrolled.
    has voiceprint: list[float] = [];
}
obj VoiceStatus {
    has enrolled: bool;
}
"""speaker_source: "manual", "voice" (matched against the voiceprint),
"turn-taking" (too short to judge) or "corrected" (fixed by the learner)."""
obj TranscriptTurn {
    has id: str, speaker: str, text: str, duration_seconds: float = 0.0,
        speaker_source: str = "manual", speaker_score: float | None = None;
}
obj SessionView {
    has id: str, native_language: str, target_language: str, level: str,
        partner_mode: str, status: str, turns: list[TranscriptTurn],
        audio_seconds: float, model_requests: int;
}
node Conversation {
    has native_language: str, target_language: str, level: str,
        partner_mode: str = "human", consent_confirmed: bool = False,
        status: str = "active", turns: list[TranscriptTurn] = [],
        audio_seconds: float = 0.0, model_requests: int = 0;
    def to_view() -> SessionView {
        return SessionView(id=jid(self), native_language=self.native_language,
            target_language=self.target_language, level=self.level,
            partner_mode=self.partner_mode, status=self.status, turns=self.turns,
            audio_seconds=self.audio_seconds, model_requests=self.model_requests);
    }
}
