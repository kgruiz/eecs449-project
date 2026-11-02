import from unittest.mock { patch }
import from jaclang.byllm.lib { Model }

test "word hints use the shared model and return a structured suggestion" {
    response = {"choices": [{"message": {"role": "assistant", "content": "{\"word\": \"parque\", \"meaning\": \"park\"}"}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) {
        hint = suggest_next_word("Voy al", "partner: Hola", "Spanish", "English", "A2");
        assert hint.word == "parque";
        assert hint.meaning == "park";
    }
}
