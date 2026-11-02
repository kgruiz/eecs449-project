"""Feature extension slot; sibling feature PRs add one panel each."""
import from ..core.models { SessionView }
def:pub FeaturePanels(session: SessionView, onSessionChange: Callable[[SessionView], None]) -> JsxElement {
    <></>
}
