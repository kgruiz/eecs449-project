"""Plain-text transcript formatting shared by export clients."""
import from .models { SessionView }

def format_transcript(session: SessionView) -> str {
    lines = [
        "Language Assistant transcript",
        "Learning language: " + session.target_language,
        "Native language: " + session.native_language,
        "CEFR level: " + session.level,
        "Status: " + session.status,
        ""
    ];
    for turn in session.turns {
        speaker = "Me" if turn.speaker == "learner" else "Partner";
        lines.append(speaker + ": " + turn.text);
    }
    # chr(10) produces real line breaks in both Jac and compiled browser code.
    return chr(10).join(lines) + chr(10);
}
