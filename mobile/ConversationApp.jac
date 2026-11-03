"""Native conversation workspace. Turns come from speech-to-text and share one
transcript through the same endpoints as the web app. With a voiceprint enrolled,
the server attributes each turn by voice and the learner can tap a turn to fix it;
without one, the learner picks who is speaking."""
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, SignupResult }
import from "@jac/mobui" {
    View, Text, TextInput, ScrollView, Switch, KeyboardAvoidingView, Platform, Pressable
}
import from ..core.models { SessionView, TranscriptTurn }
import from ..endpoints {
    save_profile, start_conversation, end_conversation, voice_status, set_turn_speaker
}
import from .SpeechInput { SpeechInput }
import from .VoiceSetup { VoiceSetup }
import from .theme { styles }
import from .CoachingPanel { CoachingPanel }
import from .ui { ActionButton, Chip }

def:pub ConversationApp -> JsxElement {
    has logged_in: bool = False, email: str = "", password: str = "",
        native_language: str = "English", target_language: str = "Spanish",
        consent: bool = False, session: SessionView | None = None,
        speaker: str = "partner", error: str = "", busy: bool = False,
        voice_enrolled: bool = False, speechBusy: bool = False;
    can with entry { logged_in = jacIsLoggedIn(); }
    async def loadVoice() -> None {
        try { status = await voice_status(); voice_enrolled = status.enrolled; }
        except Exception { voice_enrolled = False; }
    }
    can with [logged_in] entry { if logged_in { loadVoice(); } }
    async def swapSpeaker(turn: TranscriptTurn) -> None {
        updated: SessionView | None = None;
        if session is None or session.status != "active" { return; }
        try {
            updated = await set_turn_speaker(session.id, turn.id,
                "partner" if turn.speaker == "learner" else "learner");
            session = updated;
        } except Exception { error = "Could not change the speaker."; }
    }
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
        jacLogout(); logged_in = False; session = None; consent = False; voice_enrolled = False;
    }
    async def start() -> None {
        created: SessionView | None = None;
        error = ""; busy = True;
        try {
            # The level picker is hidden for now; the server still requires one.
            await save_profile(native_language, target_language, "A2");
            created = await start_conversation(consent, "human");
            session = created; consent = False;
        } except Exception { error = "Could not start. Check your profile and participant consent."; }
        finally { busy = False; }
    }
    async def finish() -> None {
        if speechBusy { return; }
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
                <View style={styles.switchRow}>
                    <Switch value={consent} onValueChange={lambda (v: bool) { consent = v; }}
                        accessibilityLabel="All participants consent"/>
                    <Text style={[styles.text, {"flex": 1}]}>
                        {"All participants agree to live transcription by this device's speech service, "
                            + ("sending each spoken turn's audio to our server to recognize who is speaking, " if voice_enrolled else "")
                            + "saved text, and sending conversation text to Gemini for language help and an automatic recap after ending."}
                    </Text>
                </View>
                <Text style={styles.muted}>
                    {"Raw audio is not saved. Speech is transcribed by your phone's speech service (Apple or Google may process the audio)."
                        + (" Speaker recognition uses each turn's audio once and then discards it." if voice_enrolled else "")}
                </Text>
                <ActionButton label="Start" disabled={busy or not consent} onPress={lambda { start(); }}/>
            </View>) if session is None or session.status == "ended" else <View/>}
            {(<VoiceSetup enrolled={voice_enrolled}
                onChange={lambda (v: bool) { voice_enrolled = v; }}/>)
                if session is None or session.status == "ended" else <View/>}
            {(<View style={styles.card}>
                <Text style={styles.heading} accessibilityRole="header">{"Transcript · " + session.status}</Text>
                {(<Text style={styles.muted}>No turns yet.</Text>) if len(session.turns) == 0 else <View/>}
                {[<Pressable key={turn.id} style={styles.turn}
                    disabled={session.status != "active"} onPress={lambda { swapSpeaker(turn); }}
                    accessibilityRole="button"
                    accessibilityHint="Switches this turn between Me and Partner">
                    <Text style={styles.speakerLearner if turn.speaker == "learner" else styles.speakerPartner}>
                        {("Me" if turn.speaker == "learner" else "Partner")
                            + (" (guessed)" if turn.speaker_source == "turn-taking" else "")}
                    </Text>
                    <Text style={styles.text}>{turn.text}</Text>
                 </Pressable> for turn in session.turns]}
                {(<View style={{"gap": 12}}>
                    {(<Text style={styles.muted}>
                        Speakers are recognized by voice. Tap a turn to switch its speaker.
                    </Text>) if voice_enrolled else (<View style={{"gap": 12}}>
                        <Text style={styles.label}>Who is speaking?</Text>
                        <View style={styles.row} accessibilityRole="radiogroup">
                            <Chip label="Partner" selected={speaker == "partner"}
                                onPress={lambda { speaker = "partner"; }}/>
                            <Chip label="Me" selected={speaker == "learner"}
                                onPress={lambda { speaker = "learner"; }}/>
                        </View>
                    </View>)}
                    <SpeechInput key={session.id} sessionId={session.id} speaker={speaker}
                        language={session.target_language} voiceEnabled={voice_enrolled}
                        onBusyChange={lambda (value: bool) { speechBusy = value; }}
                        onSessionChange={lambda (updated: SessionView) { session = updated; }}/>
                    {(<Text style={styles.muted}>Stop listening and wait for your turns to save before ending.</Text>) if speechBusy else <View/>}
                    <ActionButton label="End conversation" variant="secondary" disabled={busy or speechBusy}
                        onPress={lambda { finish(); }}/>
                </View>) if session.status == "active" else <View/>}
            </View>) if session is not None else <View/>}
        </View>}
        {(<CoachingPanel key={"coaching-" + session.id} session={session}/>) if session is not None and session.status == "ended" else <View/>}
    </ScrollView>
    </KeyboardAvoidingView>
}
