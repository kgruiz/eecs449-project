"""Web conversation workspace with manual or voiceprint speaker attribution."""
import from "lucide-react" { X, Home as HomeIcon, MessageCircle, Plus, ChevronRight, LogOut, Mic }
import from "./components/hold-speaker.jsx" { HoldSpeaker }
import from "./components/language-flag.jsx" { LanguageFlag }
import from "./components/scroll-bounce.jsx" { ScrollBounce }
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, SignupResult }
import from .core.models { SessionView, TranscriptTurn }
import from .endpoints {
    get_profile, save_onboarding_draft, complete_onboarding, decorate_conversation, start_conversation, append_turn, end_conversation, voice_status, set_voice_detection, set_turn_speaker
}
import from "./components/language-picker.jsx" { LanguagePicker, LevelPicker }
import from "./components/language-options.js" { sameLanguage, shortLanguageName }
import from .components.SpeechInput { SpeechInput }
import from .components.WordHelper { WordHelper }
import from .components.VoiceSetup { VoiceSetup }
import from .components.TranscriptDownload { TranscriptDownload }
import from .components.WebArtwork { BrandMark }
import from .components.TranscriptScroll { TranscriptScroll }
import from .components.Conversations { Conversations }
import from .components.Onboarding { Onboarding }
import from .components.Home { Home }
import "./web.css";
def:pub app -> JsxElement {
    has logged_in: bool = jacIsLoggedIn(), email: str = "", password: str = "",
        native_language: str = "English", target_language: str = "Spanish", level: str = "A2",
        session: SessionView | None = None,
        speaker: str = "partner", error: str = "", busy: bool = False,
        page: str = "home", historyId: str = "", voice_enrolled: bool = False, speechBusy: bool = False, spokenDraft: str = "",
        endRequested: bool = False, voice_enabled: bool = False, sessionVoice: bool = False, voicePreferenceBusy: bool = False,
        displayName: str = "", profileReady: bool = False, onboarding: bool = False, onboardingStep: int = 0,
        consent: bool = False, typedText: str = "", typedSpeaker: str = "learner", micOn: bool = False,
        routeHash: str = "", routeReady: bool = False, convRoute: str = "", routeNonce: int = 0, authError: str = "";
    has consentDialogRef: Ref[any] = Ref(None);
    has popRef: Ref[any] = Ref(None);

    # Hash routes keep Back, Forward, refresh and links working without server
    # rewrites: #/, #/conversations, #/conversations/<id>, #/profile, #/talk.
    def currentRoute() -> str {
        if page == "conversations" { return ("#/conversations/" + convRoute) if convRoute else "#/conversations"; }
        if page == "profile" { return "#/profile"; }
        if page == "talk" and session is not None { return "#/talk"; }
        return "#/";
    }
    def showConversations(id: str) -> None {
        historyId = id; convRoute = id; routeNonce = routeNonce + 1; page = "conversations";
    }
    def applyRoute(hash: str) -> None {
        path = hash[2:] if hash.startswith("#/") else "";
        if path.startswith("conversations/") { showConversations(path[14:]); }
        elif path == "conversations" { showConversations(""); }
        elif path == "profile" { page = "profile"; }
        elif path == "talk" and session is not None { page = "talk"; }
        else { page = "home"; }
    }
    can with entry {
        browser: any = window;
        # jac.toml sets the built page title; the dev server's template does not.
        browser.document.title = "Pip";
        routeHash = browser.location.hash;
        popRef.current = lambda { routeHash = browser.location.hash; };
        browser.addEventListener("popstate", popRef.current);
    }
    can with exit {
        browser: any = window;
        if popRef.current { browser.removeEventListener("popstate", popRef.current); }
    }
    can with [routeHash, logged_in, profileReady, onboarding] entry {
        browser: any = window;
        if not (logged_in and profileReady and not onboarding) { return; }
        current = currentRoute();
        if routeReady and routeHash == current { return; }
        # Leaving mid-save would drop turns; undo the browser navigation instead.
        if routeReady and (busy or speechBusy) {
            if browser.location.hash != current { browser.history.pushState(None, "", current); }
            routeHash = current;
            return;
        }
        applyRoute(routeHash); routeReady = True;
    }
    can with [page, convRoute, session, routeReady] entry {
        browser: any = window;
        if not routeReady { return; }
        route = currentRoute();
        if browser.location.hash != route { browser.history.pushState(None, "", route); }
        # Mirror the address so a later Back to an earlier hash still registers as a change.
        routeHash = route;
    }

    async def loadVoice() -> None {
        try { status = await voice_status(); voice_enrolled = status.enrolled; voice_enabled = status.enabled; }
        except Exception { voice_enrolled = False; voice_enabled = False; }
    }
    async def updateVoicePreference(enabled: bool) -> None {
        voicePreferenceBusy = True; error = "";
        try { status = await set_voice_detection(enabled); voice_enabled = status.enabled; }
        except Exception { error = "Could not update voice recognition. Please try again."; }
        finally { voicePreferenceBusy = False; }
    }
    async def loadProfile() -> None {
        profileReady = False; error = "";
        try {
            learner = await get_profile();
            native_language = learner.native_language; target_language = learner.target_language; level = learner.level;
            displayName = learner.display_name; onboarding = not learner.onboarding_completed; onboardingStep = learner.onboarding_step;
            profileReady = True; loadVoice();
        } except Exception { error = "Could not load your profile. Please try again."; }
    }
    can with [logged_in] entry { if logged_in { loadProfile(); } }
    async def saveOnboarding() -> None {
        error = ""; busy = True;
        try { await complete_onboarding(displayName, native_language, target_language, level); onboarding = False; page = "home"; }
        except Exception { error = "Could not save your profile. Please try again."; }
        finally { busy = False; }
    }
    async def saveProgress(step: int) -> bool {
        error = ""; busy = True;
        try { await save_onboarding_draft(displayName, native_language, target_language, level, step); return True; }
        except Exception { error = "Could not save your progress. Please try again."; return False; }
        finally { busy = False; }
    }
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
        authError = "";
        if "@" not in email.strip() or "." not in email.strip().split("@")[-1] { authError = "Enter a valid email address."; return; }
        if not password { authError = "Enter your password."; return; }
        error = ""; busy = True;
        try {
            if register {
                signup = await jacSignup(email.strip(), password);
                if not signup.success {
                    authError = "Could not create your account. If you already have one, sign in instead." if not signup.error or signup.error == "Signup failed" else signup.error;
                    return;
                }
            }
            ok = await jacLogin(email.strip(), password);
            logged_in = ok;
            if not ok { authError = "That email and password don't match. Check them and try again."; }
            password = "";
        } except Exception { authError = "Unable to sign in right now. Please try again."; }
        finally { busy = False; }
    }
    def logout() -> None {
        browser: any = window;
        jacLogout(); page = "home"; historyId = ""; convRoute = ""; logged_in = False; session = None; voice_enrolled = False; profileReady = False; displayName = "";
        routeReady = False; routeHash = "#/"; browser.history.replaceState(None, "", "#/");
    }
    # Every new conversation starts with participant consent (see the dialog below).
    def askConsent() -> None {
        consent = False; error = "";
        if consentDialogRef.current { consentDialogRef.current.showModal(); }
    }
    def closeConsent() -> None {
        if consentDialogRef.current { consentDialogRef.current.close(); }
    }
    async def start() -> None {
        created: SessionView | None = None;
        if not consent or busy { return; }
        error = ""; busy = True;
        try {
            created = await start_conversation(True, "human");
            speaker = "partner"; typedText = ""; typedSpeaker = "learner"; endRequested = False;
            sessionVoice = voice_enrolled and voice_enabled; session = created; page = "talk";
            closeConsent();
        } except Exception { error = "Could not start your conversation. Please try again."; }
        finally { busy = False; consent = False; }
    }
    async def addTyped() -> None {
        updated: SessionView | None = None;
        message = typedText.strip();
        if session is None or not message or busy or endRequested { return; }
        error = ""; busy = True;
        try {
            updated = await append_turn(session.id, typedSpeaker, message, 0.0);
            session = updated; typedText = "";
        } except Exception { error = "Could not add this message. Please try again."; }
        finally { busy = False; }
    }
    # Only the learner's own unfinished speech counts toward struggle detection.
    def trackSpeech(who: str, spoken: str) -> None {
        spokenDraft = spoken if who == "learner" else "";
    }
    def returnToSetup() -> None {

        if busy or speechBusy { return; }
        if session is not None and session.status == "active" { page = "talk"; }
        else { historyId = ""; askConsent(); }
    }

    async def finish(returnToSetup: bool = False) -> None {
        if busy or speechBusy { return; }
        updated: SessionView | None = None;
        if session is None { return; }
        error = ""; busy = True;
        try {
            updated = await end_conversation(session.id);
            # Finish decoration before mounting recap generation to avoid concurrent writes.
            try { await decorate_conversation(updated.id); } except Exception { }
            session = None; spokenDraft = ""; typedText = "";

            # Nothing was said, so there is nothing to review; history hides it too.
            if returnToSetup or len(updated.turns) == 0 {
                historyId = ""; convRoute = ""; page = "home";
            } else { showConversations(updated.id); }
        }
        except Exception { error = "Could not end this conversation."; }
        finally { busy = False; endRequested = False; }
    }
    can with [endRequested, speechBusy] entry {
        if endRequested and not speechBusy and not busy { finish(False); }
    }
    <div className="pip-app">
        <ScrollBounce />
        <a className="skip-link" href="#workspace">Skip to conversation</a>
        {not (logged_in and page == "talk" and session is not None) and <header className="topbar">
            <a className="brand" href="#workspace" aria-label="Pip Language Assistant"
                aria-disabled={busy or speechBusy}
                onClick={lambda (event: any) { event.preventDefault(); if not busy and not speechBusy and profileReady and not onboarding { page = "home"; } }}>
                <BrandMark/>
                <span className="wordmark">pip</span>
            </a>
            {logged_in and profileReady and not onboarding and <nav className="main-tabs" aria-label="Main navigation">
                <button className={"main-tab " + ("is-selected" if page == "home" else "")} aria-pressed={page == "home"} disabled={busy or speechBusy} onClick={lambda { page = "home"; }}>Home</button>
                <button className={"main-tab " + ("is-selected" if page == "conversations" else "")} aria-pressed={page == "conversations"} disabled={busy or speechBusy} onClick={lambda { showConversations(""); }}>Conversations</button>
            </nav>}
            <div className="account-controls">
                {logged_in and profileReady and not onboarding and <button type="button" className="account-avatar" aria-label="Open profile" disabled={busy or speechBusy} onClick={lambda { page = "profile"; }}>{displayName[:1].upper() if displayName else "P"}</button>}
                {logged_in and profileReady and onboarding and <button className="button button-quiet" disabled={busy} onClick={logout}>Sign out</button>}
            </div>
        </header>}
        <main id="workspace" className="workspace">
            {error and <p className="error-banner" role="alert">{error}</p>}
            {not logged_in and <div className="welcome-layout">
                <section className="card auth-card">
                    <div className="auth-intro"><p className="eyebrow">A LITTLE MORE CONFIDENCE, EVERY DAY</p><h1>Welcome to Pip</h1>
                    <p>Make more of every conversation.</p>
                    <div className="speech-art auth-art" aria-hidden="true"><span className="speech-bubble speech-bubble-back"/><span className="speech-bubble speech-bubble-front"><i/><i/><i/></span><span className="speech-spark">✦</span></div></div>
                    <div className="form-stack">
                        <label className="field">Email
                            <input type="email" autoComplete="email" placeholder="you@example.com" value={email}
                                onChange={lambda (e: ChangeEvent) { email = e.target.value; authError = ""; }}/>
                        </label>
                        <label className="field">Password
                            <input type="password" autoComplete="current-password" placeholder="Your password" value={password}
                                onChange={lambda (e: ChangeEvent) { password = e.target.value; authError = ""; }}/>
                        </label>
                        {authError and <p className="auth-error" role="alert">{authError}</p>}
                        <button className="button button-primary" disabled={busy} onClick={lambda { authenticate(False); }}>
                            {"Please wait..." if busy else "Sign in"}
                        </button>
                        <button className="button button-secondary" disabled={busy} onClick={lambda { authenticate(True); }}>Create account</button>
                    </div>
                    <p className="auth-footnote">Your conversations, your learning.</p>
                </section>
            </div>}
            {logged_in and not profileReady and <div className="profile-loading"><p role="status">{error if error else "Preparing your space…"}</p>{error and <button className="button button-secondary" onClick={loadProfile}>Try again</button>}</div>}
            {logged_in and profileReady and onboarding and <Onboarding name={displayName} nativeLanguage={native_language} targetLanguage={target_language} level={level} onName={lambda (value: str) { displayName = value; }} onNative={lambda (value: str) { native_language = value; }} onTarget={lambda (value: str) { target_language = value; }} onLevel={lambda (value: str) { level = value; }} onFinish={saveOnboarding} onProgress={saveProgress} initialStep={onboardingStep} busy={busy}/>}
            {logged_in and profileReady and not onboarding and page == "home" and <Home name={displayName} active={session is not None} onNew={returnToSetup} onOpen={lambda (id: str) { showConversations(id); }} onAll={lambda { showConversations(""); }}/>}
            {logged_in and profileReady and not onboarding and page == "profile" and <section className="profile-page">
                <div className="profile-heading"><p className="eyebrow">YOUR SPACE</p><h1>Your profile</h1><p>Make Pip feel like yours.</p></div>
                <div className="profile-grid">
                    <div className="profile-main">
                        <div className="profile-identity"><span className="profile-initial" aria-hidden="true">{displayName[:1].upper() if displayName else "P"}</span><div><strong>{displayName if displayName else "Your profile"}</strong><span><LanguageFlag language={target_language}/>{" " + target_language + " · " + level}</span></div><span className="profile-identity-spark" aria-hidden="true">✦</span></div>
                        <div className="profile-fields"><div className="profile-section-heading"><h2>Learning preferences</h2><p>These help tailor your conversations and feedback.</p></div>
                            <div className="profile-form"><label className="field">Name<input maxLength={80} autoComplete="given-name" value={displayName} onChange={lambda (e: ChangeEvent) { displayName = e.target.value; }}/></label>
                                <LanguagePicker label="Language you know" value={native_language} onChange={lambda (value: str) { native_language = value; }}/>
                                <LanguagePicker label="Learning language" value={target_language} onChange={lambda (value: str) { target_language = value; }}/>
                                <div className="field"><label htmlFor="learner-level">Your level</label><LevelPicker value={level} onChange={lambda (value: str) { level = value; }}/></div>
                                {sameLanguage(native_language, target_language) and <p className="profile-language-error" role="alert">Choose a learning language different from the language you know.</p>}
                                <button className="button button-primary profile-save" disabled={busy or not displayName.strip() or sameLanguage(native_language, target_language)} onClick={saveOnboarding}>{"Saving..." if busy else "Save changes"}</button>
                            </div>
                        </div>
                    </div>
                    <aside className="profile-extras"><div className="profile-voice-card"><div className="profile-voice-icon"><Mic size={21} aria-hidden="true"/></div><h2>Voice recognition</h2><p>Identify your voice during conversations. When off, hold Me while you speak.</p>{voice_enrolled and <label className="voice-preference"><span><strong>Use in conversations</strong><small>Automatically identify your voice</small></span><input type="checkbox" role="switch" checked={voice_enabled} disabled={voicePreferenceBusy} onChange={lambda (e: ChangeEvent) { updateVoicePreference(e.target.checked); }}/></label>}<details className="profile-voice-details"><summary><span>{"Manage voice recognition" if voice_enrolled else "Set up voice recognition"}</span><ChevronRight size={18} aria-hidden="true"/></summary><VoiceSetup enrolled={voice_enrolled} onChange={lambda (v: bool) { voice_enrolled = v; if not v { voice_enabled = False; } }}/></details></div>
                        <div className="profile-signout"><button className="profile-signout-button" disabled={busy or speechBusy} onClick={logout}><LogOut size={18} aria-hidden="true"/>Sign out</button></div>
                    </aside>
                </div>
            </section>}
            {logged_in and profileReady and not onboarding and page == "talk" and session is not None and <section className="live-conversation">
                <header className="live-header">
                    <span className="live-brand"><BrandMark/><span>pip</span></span>
                    <span className="live-language">{shortLanguageName(session.target_language) + " · " + session.level}</span>
                    <button className="live-end" disabled={busy or endRequested} onClick={lambda { endRequested = True; }} aria-label="End conversation"><X size={20}/><span>End</span></button>
                </header>
                <div className="live-status">
                    <SpeechInput key={session.id} sessionId={session.id} speaker={speaker}
                        language={session.target_language} voiceEnabled={sessionVoice} autoStart={True} stopRequested={endRequested}
                        onBusyChange={lambda (value: bool) { speechBusy = value; }}
                        onSessionChange={lambda (updated: SessionView) { session = updated; }}
                        onDraft={trackSpeech} onVoiceUnavailable={lambda { sessionVoice = False; }}
                        onListeningChange={lambda (value: bool) { micOn = value; }}/>
                </div>
                <div className="live-transcript">
                    {len(session.turns) == 0 and <div className="transcript-empty"><h2>Start talking</h2><p>Your conversation will appear here.</p></div>}
                    <TranscriptScroll key={session.id} session={session} onSwapSpeaker={swapSpeaker}/>
                </div>
                <div className="live-bottom">
                    <WordHelper key={"words-" + session.id} sessionId={session.id}
                        learnerSpeaking={(typedSpeaker == "learner") if typedText.strip() else (bool(spokenDraft) if sessionVoice else speaker == "learner")}
                        draft={typedText if typedSpeaker == "learner" and typedText.strip() else spokenDraft}/>
                    {sessionVoice and <p className="voice-auto-status">Voice recognition is on. Check speaker labels as you go.</p>}
                    {not sessionVoice and <HoldSpeaker speaking={speaker == "learner"} listening={micOn} disabled={busy or endRequested}
                        onChange={lambda (held: bool) { speaker = "learner" if held else "partner"; spokenDraft = ""; }}/>
                    }
                    <form className="live-composer" aria-label="Type a message"
                        onSubmit={lambda (event: any) { event.preventDefault(); addTyped(); }}>
                        <div className="live-composer-speaker" role="group" aria-label="Who is this message from?">
                            <button type="button" className={"live-composer-option " + ("is-selected" if typedSpeaker == "learner" else "")}
                                aria-pressed={typedSpeaker == "learner"} onClick={lambda { typedSpeaker = "learner"; }}>Me</button>
                            <button type="button" className={"live-composer-option " + ("is-selected" if typedSpeaker == "partner" else "")}
                                aria-pressed={typedSpeaker == "partner"} onClick={lambda { typedSpeaker = "partner"; }}>Partner</button>
                        </div>
                        <input className="live-composer-input" aria-label="Message" placeholder="Or type a message…" maxLength={4000}
                            value={typedText} disabled={endRequested} onChange={lambda (e: ChangeEvent) { typedText = e.target.value; }}/>
                        <button type="submit" className="button button-primary live-composer-send"
                            disabled={busy or endRequested or not typedText.strip()}>Send</button>
                    </form>
                    {endRequested and <p role="status" className="live-saving">Finishing and saving your conversation…</p>}
                </div>
            </section>}
            {logged_in and profileReady and not onboarding and page == "conversations" and <Conversations key={historyId + "|" + str(routeNonce)} initialSessionId={historyId} active={session is not None} onTalk={returnToSetup}
                onSelect={lambda (id: str) { convRoute = id; }}/>}
            <dialog ref={consentDialogRef} className="language-dialog consent-dialog" aria-labelledby="consent-title"
                aria-describedby="consent-description" onCancel={lambda (event: any) { if busy { event.preventDefault(); } }}>
                <h2 id="consent-title">Before you start</h2>
                <p id="consent-description" className="muted">Pip transcribes everyone in the conversation, so check that your partner is happy to take part. Your browser may then ask to use the microphone; you can also type messages.</p>
                <label className="consent-box"><input type="checkbox" checked={consent} disabled={busy}
                    onChange={lambda (e: ChangeEvent) { consent = e.target.checked; }}/>
                    <span>{"All participants agree to live transcription by the browser's speech service, "
                        + ("sending each spoken turn's audio to our server to recognize who is speaking, " if voice_enrolled and voice_enabled else "")
                        + "saved text, and sending conversation text to Gemini for language help and an automatic recap after ending."}</span>
                </label>
                <p className="form-footnote">{"Raw audio is not saved. Speech is transcribed by your browser's speech service (Chrome and Edge send audio to their provider); you can also type turns."
                    + (" Speaker recognition uses each turn's audio once and then discards it." if voice_enrolled and voice_enabled else "")}</p>
                {error and <p role="alert" className="speech-error">{error}</p>}
                <div className="language-dialog-actions">
                    <button type="button" className="button button-secondary" disabled={busy} onClick={closeConsent}>Cancel</button>
                    <button type="button" className="button button-primary" disabled={busy or not consent} onClick={start}>
                        {"Starting..." if busy else "Start conversation"}</button>
                </div>
            </dialog>

        </main>
        {logged_in and profileReady and not onboarding and not (page == "talk" and session is not None) and <nav className="mobile-nav" aria-label="Main navigation"><button disabled={busy or speechBusy} className={"mobile-nav-item " + ("is-selected" if page == "home" else "")} onClick={lambda { page = "home"; }}><HomeIcon size={22}/><span>Home</span></button><button className="mobile-nav-new" disabled={busy or speechBusy} aria-label="Start a new conversation" onClick={returnToSetup}><Plus size={30}/></button><button disabled={busy or speechBusy} className={"mobile-nav-item " + ("is-selected" if page == "conversations" else "")} onClick={lambda { showConversations(""); }}><MessageCircle size={22}/><span>Conversations</span></button></nav>}
    </div>
}
