import from unittest.mock { patch }

test "emoji accepts only the supported set" {
    with patch.dict(os.environ, {"GEMINI_API_KEY": "offline-test"}),
         patch(__name__ + ".select_emoji", return_value=EmojiChoice(emoji="☕")) {
        assert choose_conversation_emoji("coffee") == "☕";
    }
    with patch.dict(os.environ, {"GEMINI_API_KEY": "offline-test"}),
         patch(__name__ + ".select_emoji", return_value=EmojiChoice(emoji="not an emoji")) {
        assert choose_conversation_emoji("coffee") == "💬";
    }
}

test "emoji falls back without a configured provider" {
    with patch.dict(os.environ, {}, clear=True), patch(__name__ + ".select_emoji") as select {
        assert choose_conversation_emoji("coffee") == "💬";
        select.assert_not_called();
    }
}
