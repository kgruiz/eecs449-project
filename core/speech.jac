"""Speech-to-text helpers shared by the web and mobile adapters."""

glob SPEECH_LOCALES: dict[str, str] = {
    "arabic": "ar-SA", "chinese": "zh-CN", "mandarin": "zh-CN", "dutch": "nl-NL",
    "english": "en-US", "french": "fr-FR", "german": "de-DE", "hindi": "hi-IN",
    "italian": "it-IT", "japanese": "ja-JP", "korean": "ko-KR", "portuguese": "pt-BR",
    "russian": "ru-RU", "spanish": "es-ES"
};
# Web Speech API codes; expo-speech-recognition reuses them and adds a few native ones.
glob SPEECH_ERRORS: dict[str, str] = {
    "not-allowed": "Microphone or speech recognition access was blocked. Allow it in settings to transcribe.",
    "service-not-allowed": "The speech recognition service is unavailable here.",
    "audio-capture": "No microphone was found.",
    "network": "The speech recognition service could not be reached.",
    "language-not-supported": "Speech recognition cannot transcribe that language. Try a code such as es-ES.",
    "interrupted": "Transcription was interrupted by another app, call or alarm.",
    "busy": "The speech recognizer is busy. Try again in a moment."
};
# Silence timeouts and our own aborts; the adapters restart while still listening.
glob ROUTINE_SPEECH_ERRORS: list[str] = ["no-speech", "aborted", "speech-timeout"];

"""Map a profile language name to a BCP-47 tag; codes pass through unchanged."""
def speech_locale(language: str) -> str {
    key = language.strip().lower();
    return SPEECH_LOCALES[key] if key in SPEECH_LOCALES else language.strip();
}

def speech_error_message(code: str) -> str {
    return SPEECH_ERRORS[code] if code in SPEECH_ERRORS else "Speech recognition error: " + code + ".";
}
