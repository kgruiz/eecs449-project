"""Web-platform variant of the mobile speech adapter (react-native-web preview).
Native speech recognition lives in SpeechInput.native.jac; in a browser, use
the web app's adapter or type turns."""
import from "@jac/mobui" { View, Text }
import from ..core.models { SessionView }
import from .theme { styles }

def:pub SpeechInput(sessionId: str, speaker: str, language: str,
                    onSessionChange: Callable[[SessionView], None]) -> JsxElement {
    <View style={styles.card}>
        <Text style={styles.muted}>
            Live transcription runs in the iOS and Android app. You can still type turns here.
        </Text>
    </View>
}
