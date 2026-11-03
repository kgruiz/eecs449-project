test "saved regional language choices resolve for native speech" {
    assert speech_locale("Spanish (Mexico)") == "es-MX";
    assert speech_locale("Spanish (Spain)") == "es-ES";
    assert speech_locale("English (United Kingdom)") == "en-GB";
    assert speech_locale("French (Canada)") == "fr-CA";
    assert speech_locale("Portuguese (Portugal)") == "pt-PT";
}

test "existing profile names and custom locale tags still resolve" {
    assert speech_locale(" Spanish ") == "es-ES";
    assert speech_locale("Mandarin") == "zh-CN";
    assert speech_locale("en-AU") == "en-AU";
}
