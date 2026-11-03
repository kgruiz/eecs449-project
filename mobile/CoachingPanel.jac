import from ..core.models { SessionView }
import from ..endpoints { conversation_feedback }
import from "@jac/mobui" { View, Text }
import from .theme { styles }
import from .ui { ActionButton }

def:pub CoachingPanel(session: SessionView) -> JsxElement {
    has current: SessionView = session, busy: bool = False, error: str = "";
    async def load() -> None {
        busy = True; error = "";

        try { current = await conversation_feedback(session.id); }
        except Exception { error = "Could not generate feedback. Your transcript is saved. Please try again."; }
        finally { busy = False; }
    }
    can with entry {

        if current.coaching is None and any(turn.speaker == "learner" for turn in session.turns) { load(); }
    }
    <View style={styles.card}>
        <Text style={styles.heading} accessibilityRole="header">Conversation recap</Text>
        {(<Text style={styles.muted}>Preparing your summary and practice suggestions…</Text>) if busy else <View/>}
        {(<View><Text style={styles.error} accessibilityRole="alert">{error}</Text><ActionButton label="Retry feedback" disabled={busy} onPress={lambda { load(); }}/></View>) if error else <View/>}
        {(<Text style={styles.muted}>Add a turn as Me in your next conversation to receive personalized feedback.</Text>) if not any(turn.speaker == "learner" for turn in session.turns) else <View/>}
        {(<View style={{"gap": 12}}>
            <Text style={styles.text}>{current.coaching.summary}</Text>
            <Text style={styles.label}>What went well</Text>
            {[<Text key={strength} style={styles.text}>{strength}</Text> for strength in current.coaching.strengths]}
            <Text style={styles.label}>Work on next time</Text>
            {(<Text style={styles.muted}>No specific corrections suggested from this transcript. Keep practicing with a longer conversation.</Text>) if len(current.coaching.priorities) == 0 else <View/>}
            {[<View key={item.turn_id + item.quote} style={{"gap": 8}}>
                <Text style={styles.muted}>{item.quote}</Text><Text style={styles.text}>{"Try: " + item.suggestion}</Text>
                <Text style={styles.text}>{item.explanation}</Text><Text style={styles.text}>{"Practice: " + item.practice}</Text>
            </View> for item in current.coaching.priorities]}
            <Text style={styles.muted}>Based on the saved transcript. Speech recognition can make mistakes.</Text>
        </View>) if current.coaching is not None else <View/>}
    </View>
}
