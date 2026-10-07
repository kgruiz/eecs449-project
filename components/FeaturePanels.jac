"""Feature extension slot; sibling feature PRs add one panel each."""
import from ..core.models { SessionView }
import from .TranslationPanel { TranslationPanel }
def:pub FeaturePanels(session: SessionView, onSessionChange: (SessionView) -> None) -> JsxElement {
    <section aria-label="Conversation help">
        <TranslationPanel session={session}/>
    </section>
}
