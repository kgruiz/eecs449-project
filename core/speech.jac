"""Speech-to-text helpers shared by the web and mobile adapters."""

glob SPEECH_LOCALES: dict[str, str] = {
    "arabic": "ar-SA", "chinese": "zh-CN", "mandarin": "zh-CN", "dutch": "nl-NL",
    "english": "en-US", "french": "fr-FR", "german": "de-DE", "hindi": "hi-IN",
    "italian": "it-IT", "japanese": "ja-JP", "korean": "ko-KR", "portuguese": "pt-BR",
    "russian": "ru-RU", "spanish": "es-ES",
    "arabic (saudi arabia)": "ar-SA", "chinese (china)": "zh-CN",
    "dutch (netherlands)": "nl-NL", "english (united states)": "en-US",
    "english (united kingdom)": "en-GB", "french (france)": "fr-FR",
    "french (canada)": "fr-CA", "german (germany)": "de-DE",
    "hindi (india)": "hi-IN", "italian (italy)": "it-IT",
    "japanese (japan)": "ja-JP", "korean (south korea)": "ko-KR",
    "portuguese (brazil)": "pt-BR", "portuguese (portugal)": "pt-PT",
    "russian (russia)": "ru-RU", "spanish (spain)": "es-ES",
    "spanish (mexico)": "es-MX"
};
# Web Speech API codes; expo-speech-recognition reuses them and adds a few native ones.
glob SPEECH_ERRORS: dict[str, str] = {
    "not-allowed": "Microphone or speech recognition access was blocked. Allow it in settings to transcribe.",
    "service-not-allowed": "The speech recognition service is unavailable here.",
    "audio-capture": "Could not capture audio from the microphone. Check that the app has microphone access (in the Simulator, the Mac must allow it too).",
    "network": "The speech recognition service could not be reached.",
    "language-not-supported": "Speech recognition cannot transcribe that language. Try a code such as es-ES.",
    "interrupted": "Transcription was interrupted by another app, call or alarm.",
    "busy": "The speech recognizer is busy. Try again in a moment."
};
# Silence timeouts and our own aborts; the adapters restart while still listening.
glob ROUTINE_SPEECH_ERRORS: list[str] = ["no-speech", "aborted", "speech-timeout"];
# Transient start failures (the audio session is still settling after the last
# session) retried with a growing delay before an error is shown.
glob RETRYABLE_SPEECH_ERRORS: list[str] = ["audio-capture", "busy"];
glob MAX_SPEECH_RETRIES: int = 3;
glob RESTART_DELAY_MS: int = 300;
# Voice enrollment: a passage to read aloud; recording stops itself at the
# maximum and "Done" unlocks at the minimum (the server needs ~6s of speech).
glob ENROLL_PASSAGE: str = "I'm practicing a new language by talking with people every day. Some days it feels easy, and other days I forget simple words, but each conversation helps me listen better and speak with more confidence. Today I want to ask good questions and learn something new.";
glob ENROLL_MIN_SECONDS: int = 10;
glob ENROLL_MAX_SECONDS: int = 25;

"""Map a profile language name to a BCP-47 tag; codes pass through unchanged."""
def speech_locale(language: str) -> str {
    key = language.strip().lower();
    return SPEECH_LOCALES[key] if key in SPEECH_LOCALES else language.strip();
}

def speech_error_message(code: str) -> str {
    return SPEECH_ERRORS[code] if code in SPEECH_ERRORS else "Speech recognition error: " + code + ".";
}
