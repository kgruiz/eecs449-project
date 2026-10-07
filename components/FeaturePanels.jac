"""Feature extension slot; sibling feature PRs add one panel each."""
import from ..core.models { SessionView }
def:pub FeaturePanels(session: SessionView, onSessionChange: (SessionView) -> None) -> JsxElement {
    <section aria-label="Conversation help">
        <p>Conversation help panels will be added in the feature PRs.</p>
    </section>
}
