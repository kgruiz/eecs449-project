"""Feature extension slot; sibling feature PRs add one panel each."""
import from ..core.models { SessionView }
def:pub FeaturePanels(session: SessionView, onSessionChange: Callable[[SessionView], None]) -> JsxElement {
    <section className="feature-placeholder" aria-label="Conversation help">
        <p>Hints, translation, and coaching are planned for a future update.</p>
    </section>
}
