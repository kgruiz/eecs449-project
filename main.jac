"""Language Assistant: Jac server contracts and client entry point."""
import from .endpoints {
    save_profile, start_conversation, get_conversation, append_turn, end_conversation, translate_sentence,
    voice_status, enroll_voice, delete_voice, append_spoken_turn, set_turn_speaker
}
import from .frontend { app as ClientApp }
def:pub app -> JsxElement { <ClientApp/> }
