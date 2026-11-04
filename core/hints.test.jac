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

test "sentence completion returns ranked continuations" {
    response = {"choices": [{"message": {"role": "assistant", "content": "{\"needed\": true, \"options\": [\"al parque\", \"a casa\"]}"}, "finish_reason": "stop"}], "usage": {}};
    with patch.object(Model, "model_call_no_stream", return_value=response) {
        result = complete_sentence("Voy", "partner: ¿Adónde vas?", "Spanish", "A2");
        assert result.needed;
        assert result.options == ["al parque", "a casa"];
    }
}

test "sentence completion can decline to suggest" {
    response = {"choices": [{"message": {"role": "assistant", "content": "{\"needed\": false, \"options\": []}"}, "finish_reason": "stop"}], "usage": {}};
    with patch.object(Model, "model_call_no_stream", return_value=response) {
        result = complete_sentence("Estoy bien.", "partner: ¿Cómo estás?", "Spanish", "A2");
        assert not result.needed;
        assert result.options == [];
    }
}
