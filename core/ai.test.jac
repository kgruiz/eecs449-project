import from unittest.mock { patch }
import from jaclang.byllm.lib { OutputConversionError }

test "translation extracts text from a structured model response" {
    response = {"choices": [{"message": {"role": "assistant", "content": "{\"text\": \"hello\"}"}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) {
        assert translate_to_english("hola") == "hello";
    }
}

test "translation rejects malformed output instead of displaying it" {
    response = {"choices": [{"message": {"role": "assistant", "content": "('hello', '')"}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) {
        with testraises(OutputConversionError) {
            translate_to_english("hola");
        }
    }
}

test "translation preserves punctuation in the text field" {
    response = {"choices": [{"message": {"role": "assistant", "content": "{\"text\": \"Hello (friend), how are you?\"}"}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) {
        assert translate_to_english("Hola (amigo), ¿cómo estás?") == "Hello (friend), how are you?";
    }
}

test "translation rejects an empty text field" {
    response = {"choices": [{"message": {"role": "assistant", "content": "{\"text\": \"   \"}"}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) {
        with testraises(ValueError) {
            translate_to_english("hola");
        }
    }
}
