"""Web-platform variant of the mobile speech adapter (react-native-web preview).
Native speech recognition lives in SpeechInput.native.jac; in a browser, use
the web app's adapter."""
import from "@jac/mobui" { View, Text }
import from ..core.models { SessionView }
import from .theme { styles }

def:pub SpeechInput(sessionId: str, speaker: str, language: str, voiceEnabled: bool,
                    onSessionChange: Callable[[SessionView], None],
                    onBusyChange: Callable[[bool], None] | None = None) -> JsxElement {
    <View style={styles.card}>
        <Text style={styles.muted}>
            Live transcription runs in the iOS and Android app.
        </Text>
    </View>
}
