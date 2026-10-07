"""Feature extension slot; sibling feature PRs add one panel each."""
import from ..core.models { SessionView }
import from .CoachingPanel { CoachingPanel }
def:pub FeaturePanels(session: SessionView, onSessionChange: (SessionView) -> None) -> JsxElement {
    <section aria-label="Conversation help">
        <CoachingPanel session={session}/>
    </section>
}
