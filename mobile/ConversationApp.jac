"""Native conversation workspace. Speech-to-text and typed turns share one
transcript through the same endpoints as the web app."""
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, SignupResult }
import from "@jac/mobui" {
    View, Text, TextInput, ScrollView, Switch, KeyboardAvoidingView, Platform
}
import from ..core.models { SessionView }
import from ..endpoints { save_profile, start_conversation, append_turn, end_conversation }
import from .SpeechInput { SpeechInput }
import from .theme { styles, C }
import from .ui { ActionButton, Chip }

def:pub ConversationApp -> JsxElement {
    has logged_in: bool = False, email: str = "", password: str = "",
        native_language: str = "English", target_language: str = "Spanish", level: str = "A2",
        partner_mode: str = "human", consent: bool = False, session: SessionView | None = None,
        speaker: str = "partner", text: str = "", error: str = "", busy: bool = False;
    can with entry { logged_in = jacIsLoggedIn(); }
    async def authenticate(register: bool) -> None {
        signup: SignupResult | None = None;
        ok: bool = False;
        error = ""; busy = True;
        try {
            if register {
                signup = await jacSignup(email.strip(), password);
                if not signup.success { error = signup.error; return; }
            }
            ok = await jacLogin(email.strip(), password);
            logged_in = ok;
            if not ok { error = "Sign in failed."; }
            password = "";
        } except Exception { error = "Unable to sign in. Check your connection and try again."; }
        finally { busy = False; }
    }
    def logout() -> None {
        jacLogout(); logged_in = False; session = None; consent = False;
    }
    async def start() -> None {
        created: SessionView | None = None;
        error = ""; busy = True;
        try {
            await save_profile(native_language, target_language, level);
            created = await start_conversation(consent, partner_mode);
            session = created; consent = False;
        } except Exception { error = "Could not start. Check your profile and participant consent."; }
        finally { busy = False; }
    }
    async def addTurn() -> None {
        updated: SessionView | None = None;
        if session is None or not text.strip() { return; }
        error = ""; busy = True;
        try {
            updated = await append_turn(session.id, speaker, text, 0.0);
            session = updated; text = "";
        } except Exception { error = "Could not add this turn."; }
        finally { busy = False; }
    }
    async def finish() -> None {
        updated: SessionView | None = None;
        if session is None { return; }
        error = ""; busy = True;
        try { updated = await end_conversation(session.id); session = updated; }
        except Exception { error = "Could not end this conversation."; }
        finally { busy = False; }
    }
    <KeyboardAvoidingView style={styles.screen} behavior={"padding" if Platform.OS == "ios" else "height"}>
    <ScrollView style={styles.screen} contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        <Text style={styles.title} accessibilityRole="header">Language Assistant</Text>
        <Text style={styles.subtitle}>Support during your conversation. Practice afterward.</Text>
        {(<Text style={styles.error} accessibilityRole="alert">{error}</Text>) if error else <View/>}
        {(<View style={styles.card}>
            <Text style={styles.heading} accessibilityRole="header">Welcome</Text>
            <Text style={styles.label}>Email</Text>
            <TextInput style={styles.input} value={email} keyboardType="email-address"
                autoCapitalize="none" autoComplete="email" textContentType="emailAddress"
                onChangeText={lambda (t: str) { email = t; }}/>
            <Text style={styles.label}>Password</Text>
            <TextInput style={styles.input} value={password} secureTextEntry={True}
                autoCapitalize="none" textContentType="password"
                onChangeText={lambda (t: str) { password = t; }}/>
            <ActionButton label="Sign in" disabled={busy} onPress={lambda { authenticate(False); }}/>
            <ActionButton label="Create account" variant="secondary" disabled={busy}
                onPress={lambda { authenticate(True); }}/>
        </View>) if not logged_in else <View style={{"gap": 16}}>
            <ActionButton label="Sign out" variant="secondary" onPress={logout}/>
            {(<View style={styles.card}>
                <Text style={styles.heading} accessibilityRole="header">Start a conversation</Text>
                <Text style={styles.label}>Native language</Text>
                <TextInput style={styles.input} value={native_language}
                    onChangeText={lambda (t: str) { native_language = t; }}/>
                <Text style={styles.label}>Learning language</Text>
                <TextInput style={styles.input} value={target_language}
                    onChangeText={lambda (t: str) { target_language = t; }}/>
                <Text style={styles.label}>CEFR level</Text>
                <View style={styles.row} accessibilityRole="radiogroup">
                    {[<Chip key={value} label={value} selected={level == value}
                        onPress={lambda { level = value; }}/>
                     for value in ["A1", "A2", "B1", "B2", "C1", "C2"]]}
                </View>
                <Text style={styles.label}>Partner</Text>
                <View style={styles.row} accessibilityRole="radiogroup">
                    <Chip label="Real person" selected={partner_mode == "human"}
                        onPress={lambda { partner_mode = "human"; }}/>
                    <Chip label="AI partner" selected={partner_mode == "ai"}
                        onPress={lambda { partner_mode = "ai"; }}/>
                </View>
                <View style={styles.switchRow}>
                    <Switch value={consent} onValueChange={lambda (v: bool) { consent = v; }}
                        accessibilityLabel="All participants consent"/>
                    <Text style={[styles.text, {"flex": 1}]}>
                        All participants agree to live transcription by this device's speech service, saved text, and sending conversation text to Gemini for requested help.
                    </Text>
                </View>
                <Text style={styles.muted}>
                    Raw audio is not saved. Speech is transcribed by your phone's speech service (Apple or Google may process the audio); you can also type turns.
                </Text>
                <ActionButton label="Start" disabled={busy or not consent} onPress={lambda { start(); }}/>
            </View>) if session is None or session.status == "ended" else <View/>}
            {(<View style={styles.card}>
                <Text style={styles.heading} accessibilityRole="header">{"Transcript · " + session.status}</Text>
                {(<Text style={styles.muted}>No turns yet.</Text>) if len(session.turns) == 0 else <View/>}
                {[<View key={turn.id} style={styles.turn}>
                    <Text style={styles.speakerLearner if turn.speaker == "learner" else styles.speakerPartner}>
                        {"Me" if turn.speaker == "learner" else "Partner"}
                    </Text>
                    <Text style={styles.text}>{turn.text}</Text>
                 </View> for turn in session.turns]}
                {(<View style={{"gap": 12}}>
                    <Text style={styles.label}>Who is speaking?</Text>
                    <View style={styles.row} accessibilityRole="radiogroup">
                        <Chip label="Partner" selected={speaker == "partner"}
                            onPress={lambda { speaker = "partner"; }}/>
                        <Chip label="Me" selected={speaker == "learner"}
                            onPress={lambda { speaker = "learner"; }}/>
                    </View>
                    <SpeechInput key={session.id} sessionId={session.id} speaker={speaker}
                        language={session.target_language}
                        onSessionChange={lambda (updated: SessionView) { session = updated; }}/>
                    <Text style={styles.label}>Sentence</Text>
                    <TextInput style={styles.input} value={text} placeholderTextColor={C.muted}
                        placeholder="Type a turn" returnKeyType="send"
                        onSubmitEditing={lambda { addTurn(); }}
                        onChangeText={lambda (t: str) { text = t; }}/>
                    <ActionButton label="Add turn" disabled={busy or not text.strip()}
                        onPress={lambda { addTurn(); }}/>
                    <ActionButton label="End conversation" variant="secondary" disabled={busy}
                        onPress={lambda { finish(); }}/>
                </View>) if session.status == "active" else <View/>}
            </View>) if session is not None else <View/>}
        </View>}
    </ScrollView>
    </KeyboardAvoidingView>
}
