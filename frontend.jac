"""Conversation workspace. Speech-to-text and typed turns share one transcript.
With a voiceprint enrolled, the server attributes spoken turns by voice and the
learner can switch a turn's speaker; otherwise the learner picks who is speaking."""
import from "lucide-react" { Info, Check, ChevronRight, Home as HomeIcon, MessageCircle, Plus }
import from "./components/language-flag.jsx" { LanguageFlag }
import from "./components/scroll-bounce.jsx" { ScrollBounce }
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, SignupResult }
import from .core.models { SessionView, TranscriptTurn }
import from .endpoints {
    save_profile, get_profile, save_onboarding_draft, complete_onboarding, decorate_conversation, start_conversation, append_turn, end_conversation, voice_status, set_turn_speaker
}
import from "./components/language-picker.jsx" { LanguagePicker, LevelPicker, PartnerPicker }
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
        partner_mode: str = "human", consent: bool = False, session: SessionView | None = None,
        speaker: str = "partner", text: str = "", error: str = "", busy: bool = False,
        page: str = "home", historyId: str = "", levelHelpOpen: bool = False, voice_enrolled: bool = False, speechBusy: bool = False, spokenDraft: str = "",
        displayName: str = "", profileReady: bool = False, onboarding: bool = False, onboardingStep: int = 0;
    has returnDialogRef: Ref[any] = Ref(None);

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
        jacLogout(); page = "home"; historyId = ""; logged_in = False; session = None; consent = False; voice_enrolled = False; profileReady = False; displayName = "";
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
            session = updated; text = ""; spokenDraft = "";
        } except Exception { error = "Could not add this turn."; }
        finally { busy = False; }
    }
    # Only the learner's own unfinished speech counts toward struggle detection.
    def trackSpeech(who: str, spoken: str) -> None {
        spokenDraft = spoken if who == "learner" else "";
    }
    def returnToSetup() -> None {

        if busy or speechBusy { return; }

        if session is not None and session.status == "active" {
            error = "";

            if returnDialogRef.current { returnDialogRef.current.showModal(); }
        } else {
            historyId = ""; page = "talk";
        }
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
            session = None; text = ""; spokenDraft = "";

            if returnToSetup {
                historyId = ""; page = "talk"; consent = False;
                if returnDialogRef.current { returnDialogRef.current.close(); }
            } else { page = "conversations"; }
        }
        except Exception { error = "Could not end this conversation."; }
        finally { busy = False; }
    }
    <div className="pip-app">
        <ScrollBounce />
        <a className="skip-link" href="#workspace">Skip to conversation</a>
        <header className="topbar">
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
                {logged_in and profileReady and not onboarding and <details className="account-menu"><summary className="account-avatar" aria-label="Account menu">{displayName[:1].upper() if displayName else "P"}</summary><div className="account-popover"><strong>{displayName if displayName else "Your account"}</strong><span>{target_language + " · " + level}</span><button onClick={lambda { page = "profile"; }}>Edit profile</button><button onClick={logout}>Sign out</button></div></details>}
                {logged_in and profileReady and onboarding and <button className="button button-quiet" disabled={busy} onClick={logout}>Sign out</button>}
            </div>
        </header>
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
            {logged_in and profileReady and not onboarding and page == "home" and <Home name={displayName} active={session is not None} onNew={lambda { page = "talk"; }} onOpen={lambda (id: str) { historyId = id; page = "conversations"; }} onAll={lambda { historyId = ""; page = "conversations"; }}/>}
            {logged_in and profileReady and not onboarding and page == "profile" and <section className="card profile-card"><h1>Your profile</h1><p className="muted">Update your name and learning preferences.</p><div className="form-stack"><label className="field">Name<input maxLength={80} value={displayName} onChange={lambda (e: ChangeEvent) { displayName = e.target.value; }}/></label><LanguagePicker label="Your language" value={native_language} onChange={lambda (value: str) { native_language = value; }}/><LanguagePicker label="Learning language" value={target_language} onChange={lambda (value: str) { target_language = value; }}/><label className="field">Level<LevelPicker value={level} onChange={lambda (value: str) { level = value; }}/></label><button className="button button-primary" disabled={busy or not displayName.strip()} onClick={saveOnboarding}>Save profile</button></div></section>}
            {logged_in and profileReady and not onboarding and page == "talk" and <div className="conversation-layout">
                {(session is None or session.status == "ended") and <section className="card setup-card">
                    <div className="section-heading">
                        <h1>Start a conversation</h1>

                    </div>
                    <p className="muted">Choose your languages and confirm participant consent.</p>
                    <div className="field-grid">
                        <LanguagePicker label="Native language" value={native_language} onChange={lambda (value: str) { native_language = value; }}/>
                        <LanguagePicker label="Learning language" value={target_language} onChange={lambda (value: str) { target_language = value; }}/>
                        <div className="field">
                            <div className="field-label-row">
                                <label htmlFor="learner-level">Level</label>
                                <span className="level-help" onMouseEnter={lambda { levelHelpOpen = True; }} onMouseLeave={lambda { levelHelpOpen = False; }}>
                                    <button type="button" className="info-button" aria-label="About language levels" aria-describedby="level-help"
                                        onFocus={lambda { levelHelpOpen = True; }} onBlur={lambda { levelHelpOpen = False; }}
                                        onClick={lambda { levelHelpOpen = True; }}
                                        onKeyDown={lambda (e: any) { if e.key == "Escape" { levelHelpOpen = False; } }}>
                                        <Info size={18} strokeWidth={1.75} aria-hidden="true"/>
                                    </button>
                                    <span className="level-tooltip" id="level-help" role="tooltip" hidden={not levelHelpOpen}>CEFR scale: A1–A2 beginner, B1–B2 intermediate, C1–C2 advanced.</span>
                                </span>
                            </div>
                            <LevelPicker value={level} onChange={lambda (value: str) { level = value; }}/>
                        </div>
                        <PartnerPicker value={partner_mode} onChange={lambda (value: str) { partner_mode = value; }}/>
                    </div>
                    <label className="consent-box"><input type="checkbox" checked={consent}
                        onChange={lambda (e: ChangeEvent) { consent = e.target.checked; }}/>
                        <span>{"All participants agree to live transcription by the browser's speech service, "
                            + ("sending each spoken turn's audio to our server to recognize who is speaking, " if voice_enrolled else "")
                            + "saved text, and sending conversation text to Gemini for language help, a topic emoji, and an automatic recap after ending."}</span>
                    </label>
                    <p className="form-footnote">{"Raw audio is not saved. Speech is transcribed by your browser's speech service (Chrome and Edge send audio to their provider); you can also type turns."
                        + (" Speaker recognition uses each turn's audio once and then discards it." if voice_enrolled else "")}</p>
                    <button className="button button-primary start-button" disabled={busy or not consent} onClick={start}>
                        {"Starting..." if busy else "Start conversation"}
                    </button>
                    <details className="voice-options"><summary><ChevronRight className="disclosure-chevron" size={16} strokeWidth={1.75} aria-hidden="true"/>Speaker recognition (optional)</summary>
                        <VoiceSetup enrolled={voice_enrolled} onChange={lambda (v: bool) { voice_enrolled = v; }}/>
                    </details>
                </section>}
                {session is not None and <section className="card transcript-card">
                    <div className="transcript-header">
                        <p className="eyebrow">{session.target_language + " · " + session.level}</p>
                        <div className="transcript-actions">
                            <span className={"status-badge " + ("status-active" if session.status == "active" else "status-ended")}>
                                <span className="status-dot"/>{"Active" if session.status == "active" else "Ended"}
                            </span>
                            <TranscriptDownload key={"download-" + session.id} session={session}/>
                        </div>
                    </div>
                    <h2>Conversation</h2>
                    {len(session.turns) == 0 and <div className="transcript-empty">
                        <h3>No messages yet</h3>
                        <p>{"Start listening or type a message." if session.status == "active" else "No messages were added to this session."}</p>
                    </div>}
                    <TranscriptScroll key={session.id} session={session} onSwapSpeaker={swapSpeaker}/>
                    {session.status == "ended" and <p className="session-ended-note">Conversation ended. The transcript is saved to your account.</p>}
                </section>}
                {session is not None and session.status == "active" and <aside className="card controls-card">
                    {voice_enrolled and <p className="muted">Speakers are recognized by voice. If recognition is unavailable or uncertain, the selected speaker below is used. Click a speaker name to correct it.</p>}
                    <fieldset className="speaker-picker">
                        <legend>{"Speaker for typed turns and voice fallback" if voice_enrolled else "Who is speaking?"}</legend>
                        <div className="speaker-segments">
                            {[<label key={value} className="speaker-option">
                                <input type="radio" name="conversation-speaker" value={value} checked={speaker == value}
                                    onChange={lambda (e: ChangeEvent) { speaker = e.target.value; spokenDraft = ""; }}/>
                                <span className="speaker-option-content">
                                    <span className={"speaker-choice-avatar " + value} aria-hidden="true">{"M" if value == "learner" else "P"}</span>
                                    <span>{"Me" if value == "learner" else "Partner"}</span>
                                    <Check className="speaker-check" size={20} strokeWidth={1.75} aria-hidden="true"/>
                                </span>
                            </label> for value in ["learner", "partner"]]}
                        </div>
                    </fieldset>
                    <SpeechInput key={session.id} sessionId={session.id} speaker={speaker}
                        language={session.target_language} voiceEnabled={voice_enrolled}
                        onBusyChange={lambda (value: bool) { speechBusy = value; }}
                        onSessionChange={lambda (updated: SessionView) { session = updated; }}
                        onDraft={trackSpeech}/>
                    <WordHelper key={"words-" + session.id} sessionId={session.id} learnerSpeaking={speaker == "learner" if text.strip() else bool(spokenDraft)}
                        draft={text if speaker == "learner" and text.strip() else spokenDraft}/>
                    <div className="typed-composer">
                        <label className="field">Message
                            <textarea rows={3} value={text} placeholder="Type a message..."
                                onChange={lambda (e: ChangeEvent) { text = e.target.value; }}/>
                        </label>
                        <div className="composer-actions">
                            <button className="button button-secondary" disabled={busy or not text.strip()} onClick={addTurn}>Add message</button>
                            {speechBusy and <p className="muted" role="status">Stop listening and wait for your turns to save before leaving Talk or ending.</p>}
                            <button className="button button-end" disabled={busy or speechBusy} onClick={lambda { finish(False); }}>{"Saving..." if busy else "End conversation"}</button>
                            <button className="button button-quiet" disabled={busy or speechBusy}
                                onClick={returnToSetup}>Return to setup</button>
                        </div>
                    </div>
                </aside>}
            </div>}
            {logged_in and profileReady and not onboarding and page == "conversations" and <Conversations key={historyId} initialSessionId={historyId} active={session is not None} onTalk={lambda { page = "talk"; }}/>}

            <dialog ref={returnDialogRef} className="language-dialog" aria-labelledby="return-setup-title"
                aria-describedby="return-setup-description" onCancel={lambda (event: any) { if busy { event.preventDefault(); } }}>
                <h2 id="return-setup-title">Return to setup?</h2>
                <p id="return-setup-description">End and save this conversation before starting another. You can find it in Conversations.</p>
                {text.strip() and <p className="muted">Your unsent message will not be included. Choose Keep talking to add it first.</p>}
                {error and <p role="alert">{error}</p>}
                <div className="language-dialog-actions">
                    <button className="button button-secondary" autoFocus={True} disabled={busy}
                        onClick={lambda { if returnDialogRef.current { returnDialogRef.current.close(); } }}>Keep talking</button>
                    <button className="button button-primary" disabled={busy or speechBusy}
                        onClick={lambda { finish(True); }}>{"Saving..." if busy else "End and return to setup"}</button>
                </div>
            </dialog>
        </main>
        {logged_in and profileReady and not onboarding and <nav className="mobile-nav" aria-label="Main navigation"><button disabled={busy or speechBusy} className={"mobile-nav-item " + ("is-selected" if page == "home" else "")} onClick={lambda { page = "home"; }}><HomeIcon size={22}/><span>Home</span></button><button className="mobile-nav-new" disabled={busy or speechBusy} aria-label="Start a new conversation" onClick={returnToSetup}><Plus size={30}/></button><button disabled={busy or speechBusy} className={"mobile-nav-item " + ("is-selected" if page == "conversations" else "")} onClick={lambda { historyId = ""; page = "conversations"; }}><MessageCircle size={22}/><span>Conversations</span></button></nav>}
    </div>
}
