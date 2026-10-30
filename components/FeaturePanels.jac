"""Feature extension slot; sibling feature PRs add one panel each."""
import from ..core.models { SessionView }
def:pub FeaturePanels(session: SessionView, onSessionChange: Callable[[SessionView], None]) -> JsxElement {
    <section className="feature-placeholder" aria-label="Conversation help">
        <p>Tap a sentence to translate it. Hints and coaching are planned.</p>
    </section>
}
