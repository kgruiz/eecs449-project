"""Web-platform variant of voice enrollment (react-native-web preview).
Recording lives in VoiceSetup.native.jac."""
import from "@jac/mobui" { View, Text }
import from .theme { styles }

def:pub VoiceSetup(enrolled: bool, onChange: Callable[[bool], None]) -> JsxElement {
    <View style={styles.card}>
        <Text style={styles.muted}>
            Voice recognition is set up in the iOS and Android app.
        </Text>
    </View>
}
