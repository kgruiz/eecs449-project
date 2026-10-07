"""Feature extension slot; sibling feature PRs add one panel each."""
import from ..core.models { SessionView }
import from .LiveAssistPanel { LiveAssistPanel }
def:pub FeaturePanels(session: SessionView, onSessionChange: (SessionView) -> None) -> JsxElement {
    <section aria-label="Conversation help">
        <LiveAssistPanel session={session} onSessionChange={onSessionChange}/>
    </section>
}
