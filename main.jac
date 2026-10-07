"""Language Assistant: Jac server contracts and client entry point."""
import from .endpoints { save_profile, start_conversation, get_conversation, append_turn, end_conversation }
import from .frontend { app as ClientApp }
def:pub app -> JsxElement { <ClientApp/> }
