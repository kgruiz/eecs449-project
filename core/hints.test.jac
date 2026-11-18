import from unittest.mock { patch }
import from jaclang.byllm.lib { Model }

test "word hints use the shared model and return a structured suggestion" {
    response = {"choices": [{"message": {"role": "assistant", "content": "{\"word\": \"parque\", \"meaning\": \"park\"}"}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) {
        hint = suggest_next_word("Voy al", "partner: Hola", "Spanish", "English", "A2");
        assert hint.word == "parque";
        assert hint.meaning == "park";
        assert hint.lookup is None;
    }
}

test "word hints answer a how-do-I-say aside alongside the next word" {
    content = "{\"word\": \"del\", \"meaning\": \"some\", \"lookup\": {\"asked\": \"bread\", \"word\": \"pane\"}}";
    response = {"choices": [{"message": {"role": "assistant", "content": content}, "finish_reason": "stop"}], "usage": {}};

    with patch.object(Model, "model_call_no_stream", return_value=response) {
        hint = suggest_next_word("Vorrei comprare... come si dice bread", "partner: Buongiorno!", "Italian", "English", "A1");
        assert hint.word == "del";
        lookup = hint.lookup;
        assert lookup is not None;
        assert lookup.asked == "bread";
        assert lookup.word == "pane";
    }
}
