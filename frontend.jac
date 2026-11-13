"""Web conversation workspace with hold-to-mark speaker attribution."""
import from "lucide-react" { X, Home as HomeIcon, MessageCircle, Plus }
import from "./components/hold-speaker.jsx" { HoldSpeaker }
import from "./components/scroll-bounce.jsx" { ScrollBounce }
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, SignupResult }
import from .core.models { SessionView, TranscriptTurn }
import from .endpoints {
    get_profile, save_onboarding_draft, complete_onboarding, decorate_conversation, start_conversation, end_conversation, voice_status, set_turn_speaker
}
import from "./components/language-picker.jsx" { LanguagePicker, LevelPicker }
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
        endRequested: bool = False,
        displayName: str = "", profileReady: bool = False, onboarding: bool = False, onboardingStep: int = 0;

    async def loadVoice() -> None {
        try { status = await voice_status(); voice_enrolled = status.enrolled; }
        except Exception { voice_enrolled = False; }
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
        error = ""; busy = True;
        try {
            if register {
                signup = await jacSignup(email, password);
                if not signup.success { error = signup.error; return; }
            }
            ok = await jacLogin(email, password);
            logged_in = ok;
            if not ok { error = "Sign in failed."; }
            password = "";
        } except Exception { error = "Unable to sign in. Please try again."; }
        finally { busy = False; }
    }
    def logout() -> None {
        jacLogout(); page = "home"; historyId = ""; logged_in = False; session = None; voice_enrolled = False; profileReady = False; displayName = "";
    }
    async def start() -> None {
        created: SessionView | None = None;
        error = ""; busy = True;
        try {
            created = await start_conversation(False, "human");
            speaker = "partner"; endRequested = False; session = created; page = "talk";
        } except Exception { error = "Could not start your conversation. Please try again."; }
        finally { busy = False; }
    }
    # Only the learner's own unfinished speech counts toward struggle detection.
    def trackSpeech(who: str, spoken: str) -> None {
        spokenDraft = spoken if who == "learner" else "";
    }
    def returnToSetup() -> None {

        if busy or speechBusy { return; }
        if session is not None and session.status == "active" { page = "talk"; }
        else { historyId = ""; start(); }
    }

    async def finish(returnToSetup: bool = False) -> None {
        if busy or speechBusy { return; }
        updated: SessionView | None = None;
        if session is None { return; }
        error = ""; busy = True;
        try {
            updated = await end_conversation(session.id); historyId = updated.id;
            # Finish decoration before mounting recap generation to avoid concurrent writes.
            try { await decorate_conversation(updated.id); } except Exception { }
            session = None; spokenDraft = "";

            if returnToSetup {
                historyId = ""; page = "home";
            } else { page = "conversations"; }
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
                <button className={"main-tab " + ("is-selected" if page == "conversations" else "")} aria-pressed={page == "conversations"} disabled={busy or speechBusy} onClick={lambda { historyId = ""; page = "conversations"; }}>Conversations</button>
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
                                onChange={lambda (e: ChangeEvent) { email = e.target.value; }}/>
                        </label>
                        <label className="field">Password
                            <input type="password" autoComplete="current-password" placeholder="Your password" value={password}
                                onChange={lambda (e: ChangeEvent) { password = e.target.value; }}/>
                        </label>
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
            {logged_in and profileReady and not onboarding and page == "home" and <Home name={displayName} active={session is not None} onNew={returnToSetup} onOpen={lambda (id: str) { historyId = id; page = "conversations"; }} onAll={lambda { historyId = ""; page = "conversations"; }}/>}
            {logged_in and profileReady and not onboarding and page == "profile" and <section className="card profile-card"><h1>Your profile</h1><p className="muted">Update your name and learning preferences.</p><div className="form-stack"><label className="field">Name<input maxLength={80} value={displayName} onChange={lambda (e: ChangeEvent) { displayName = e.target.value; }}/></label><LanguagePicker label="Your language" value={native_language} onChange={lambda (value: str) { native_language = value; }}/><LanguagePicker label="Learning language" value={target_language} onChange={lambda (value: str) { target_language = value; }}/><label className="field">Level<LevelPicker value={level} onChange={lambda (value: str) { level = value; }}/></label><button className="button button-primary" disabled={busy or not displayName.strip()} onClick={saveOnboarding}>Save profile</button></div><div className="profile-voice"><h2>Voice recognition</h2><p className="muted">Voice recognition is available in the native app. Web conversations use the hold-to-speak control.</p><VoiceSetup enrolled={voice_enrolled} onChange={lambda (v: bool) { voice_enrolled = v; }}/></div><div className="profile-signout"><button className="button button-secondary" disabled={busy or speechBusy} onClick={logout}>Sign out</button></div></section>}
            {logged_in and profileReady and not onboarding and page == "talk" and session is not None and <section className="live-conversation">
                <header className="live-header">
                    <span className="live-brand"><BrandMark/><span>pip</span></span>
                    <span className="live-language">{session.target_language + " · " + session.level}</span>
                    <button className="live-end" disabled={busy or endRequested} onClick={lambda { endRequested = True; }} aria-label="End conversation"><X size={20}/><span>End</span></button>
                </header>
                <div className="live-status">
                    <SpeechInput key={session.id} sessionId={session.id} speaker={speaker}
                        language={session.target_language} voiceEnabled={False} autoStart={True} stopRequested={endRequested}
                        onBusyChange={lambda (value: bool) { speechBusy = value; }}
                        onSessionChange={lambda (updated: SessionView) { session = updated; }}
                        onDraft={trackSpeech}/>
                </div>
                <div className="live-transcript">
                    {len(session.turns) == 0 and <div className="transcript-empty"><h2>Start talking</h2><p>Your conversation will appear here.</p></div>}
                    <TranscriptScroll key={session.id} session={session} onSwapSpeaker={swapSpeaker}/>
                </div>
                <div className="live-bottom">
                    <WordHelper key={"words-" + session.id} sessionId={session.id} learnerSpeaking={speaker == "learner"} draft={spokenDraft}/>
                    <HoldSpeaker speaking={speaker == "learner"} disabled={busy or endRequested}
                        onChange={lambda (held: bool) { speaker = "learner" if held else "partner"; spokenDraft = ""; }}/>
                    {endRequested and <p role="status" className="live-saving">Finishing and saving your conversation…</p>}
                </div>
            </section>}
            {logged_in and profileReady and not onboarding and page == "conversations" and <Conversations key={historyId} initialSessionId={historyId} active={session is not None} onTalk={returnToSetup}/>}

        </main>
        {logged_in and profileReady and not onboarding and not (page == "talk" and session is not None) and <nav className="mobile-nav" aria-label="Main navigation"><button disabled={busy or speechBusy} className={"mobile-nav-item " + ("is-selected" if page == "home" else "")} onClick={lambda { page = "home"; }}><HomeIcon size={22}/><span>Home</span></button><button className="mobile-nav-new" disabled={busy or speechBusy} aria-label="Start a new conversation" onClick={returnToSetup}><Plus size={30}/></button><button disabled={busy or speechBusy} className={"mobile-nav-item " + ("is-selected" if page == "conversations" else "")} onClick={lambda { historyId = ""; page = "conversations"; }}><MessageCircle size={22}/><span>Conversations</span></button></nav>}
    </div>
}
