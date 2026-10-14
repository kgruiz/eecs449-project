"""Native mobile entry (React Native through @jac/mobui). The app has no server
of its own: its endpoint calls go to the web app's server."""
import from ..endpoints { save_profile, start_conversation, get_conversation, append_turn, end_conversation }
import from .ConversationApp { ConversationApp }
def:pub app -> JsxElement { <ConversationApp/> }
