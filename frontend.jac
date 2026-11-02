"""Conversation workspace. Speech-to-text and typed turns share one transcript.
With a voiceprint enrolled, the server attributes spoken turns by voice and the
learner can switch a turn's speaker; otherwise the learner picks who is speaking."""
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, SignupResult }
import from .core.models { SessionView, TranscriptTurn }
import from .endpoints {
    save_profile, start_conversation, append_turn, end_conversation, voice_status, set_turn_speaker
}
import from .components.SpeechInput { SpeechInput }
import from .components.WordHelper { WordHelper }
import from .components.VoiceSetup { VoiceSetup }
import from .components.TranscriptDownload { TranscriptDownload }
import from .components.WebArtwork { BrandMark, PipCompanion }
import from .components.TranscriptScroll { TranscriptScroll }
import from .components.Conversations { Conversations }
import "./web.css";
def:pub app -> JsxElement {
    has logged_in: bool = jacIsLoggedIn(), email: str = "", password: str = "",
        native_language: str = "English", target_language: str = "Spanish", level: str = "A2",
        partner_mode: str = "human", consent: bool = False, session: SessionView | None = None,
        speaker: str = "partner", text: str = "", error: str = "", busy: bool = False,
        page: str = "talk", historyId: str = "", voice_enrolled: bool = False, speechBusy: bool = False, spokenDraft: str = "";
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
        jacLogout(); page = "talk"; historyId = ""; logged_in = False; session = None; consent = False; voice_enrolled = False;
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
    async def finish() -> None {
        if speechBusy { return; }
        updated: SessionView | None = None;
        if session is None { return; }
        error = ""; busy = True;
        try {
            updated = await end_conversation(session.id); historyId = updated.id;
            session = None; text = ""; spokenDraft = ""; page = "conversations";
        }
        except Exception { error = "Could not end this conversation."; }
        finally { busy = False; }
    }
    <div className="pip-app">
        <a className="skip-link" href="#workspace">Skip to conversation</a>
        <header className="topbar">
            <a className="brand" href="#workspace" aria-label="Pip Language Assistant">
                <BrandMark/>
                <span className="wordmark">pip</span>
            </a>
            {logged_in and <nav className="main-tabs" aria-label="Main navigation">
                <button className={"main-tab " + ("is-selected" if page == "talk" else "")} aria-pressed={page == "talk"} onClick={lambda { page = "talk"; }}>Talk</button>
                <button className={"main-tab " + ("is-selected" if page == "conversations" else "")} aria-pressed={page == "conversations"} disabled={busy or speechBusy} onClick={lambda { historyId = ""; page = "conversations"; }}>Conversations</button>
            </nav>}
            <div className="account-controls">
                {logged_in and <span className="language-badge">{target_language + " · " + level}</span>}
                {logged_in and <button className="button button-quiet" onClick={logout}>Sign out</button>}
            </div>
        </header>
        <main id="workspace" className="workspace">
            {session is None and page == "talk" and <div className="page-heading">
                <p className="eyebrow">Language Assistant</p>
                <h1>Stay in the conversation.</h1>
                <p className="page-description">Your words, a little more at home.</p>
            </div>}
            {error and <p className="error-banner" role="alert">{error}</p>}
            {not logged_in and <div className="welcome-layout">
                <section className="welcome-story" aria-label="Welcome to Pip">
                    <div className="companion-scene">
                        <span className="scene-orbit orbit-outer"/>
                        <span className="scene-orbit orbit-inner"/>
                        <span className="scene-spark spark-one">✦</span>
                        <span className="scene-spark spark-two">✧</span>
                        <PipCompanion/>
                        <span className="companion-label">hello, conversation.</span>
                    </div>
                    <h2>A little space to find your voice.</h2>
                    <p>Bring a real conversation into focus. Speak or type, and keep your words together in one transcript.</p>
                    <div className="privacy-note"><span aria-hidden="true">◎</span><p>Conversation text is saved to your account. Raw audio is never stored by this app.</p></div>
                </section>
                <section className="card auth-card">
                    <p className="eyebrow">Make yourself at home</p>
                    <h2>Welcome to pip.</h2>
                    <p className="muted">Sign in or create an account to get started.</p>
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
                    <p className="form-footnote">A real conversation starts with a little hello.</p>
                </section>
            </div>}
            {logged_in and page == "talk" and <div className="conversation-layout">
                {(session is None or session.status == "ended") and <section className="card setup-card">
                    <div className="section-heading">
                        <div><p className="eyebrow">Before you begin</p><h2>Start a conversation</h2></div>
                        <span className="small-companion"><PipCompanion/></span>
                    </div>
                    <p className="muted">Choose your languages, then make sure everyone is comfortable joining in.</p>
                    <div className="field-grid">
                        <label className="field">Native language
                            <input value={native_language} onChange={lambda (e: ChangeEvent) { native_language = e.target.value; }}/>
                        </label>
                        <label className="field">Learning language
                            <input value={target_language} onChange={lambda (e: ChangeEvent) { target_language = e.target.value; }}/>
                        </label>
                        <label className="field">CEFR level
                            <select value={level} onChange={lambda (e: ChangeEvent) { level = e.target.value; }}>
                                {[<option key={value} value={value}>{value}</option> for value in ["A1", "A2", "B1", "B2", "C1", "C2"]]}
                            </select>
                        </label>
                        <label className="field">Partner
                            <select value={partner_mode} onChange={lambda (e: ChangeEvent) { partner_mode = e.target.value; }}>
                                <option value="human">Real person</option><option value="ai">AI partner (mode only)</option>
                            </select>
                        </label>
                    </div>
                    {partner_mode == "ai" and <p className="notice">AI partner mode records your choice. Automatic replies are not available yet.</p>}
                    <label className="consent-box"><input type="checkbox" checked={consent}
                        onChange={lambda (e: ChangeEvent) { consent = e.target.checked; }}/>
                        <span>{"All participants agree to live transcription by the browser's speech service, "
                            + ("sending each spoken turn's audio to our server to recognize who is speaking, " if voice_enrolled else "")
                            + "saved text, and sending conversation text to Gemini for language help and an automatic recap after ending."}</span>
                    </label>
                    <p className="form-footnote">{"Raw audio is not saved. Speech is transcribed by your browser's speech service (Chrome and Edge send audio to their provider); you can also type turns."
                        + (" Speaker recognition uses each turn's audio once and then discards it." if voice_enrolled else "")}</p>
                    <button className="button button-primary start-button" disabled={busy or not consent} onClick={start}>
                        {"Starting..." if busy else "Start conversation"}<span aria-hidden="true">↗</span>
                    </button>
                    <VoiceSetup enrolled={voice_enrolled} onChange={lambda (v: bool) { voice_enrolled = v; }}/>
                </section>}
                {session is None and <aside className="ready-card">
                    <span className="ready-art"><PipCompanion/></span>
                    <p className="eyebrow">One conversation at a time</p>
                    <h2>Be here.<br/>The words can follow.</h2>
                    <p>Choose who is speaking, then start listening. Prefer to type? That works too.</p>
                    <div className="ready-detail"><span className="status-dot"/>Your transcript starts when you do.</div>
                </aside>}
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
                    <h2>Your conversation</h2>
                    {len(session.turns) == 0 and <div className="transcript-empty">
                        <PipCompanion/>
                        <h3>{"A little hello goes a long way." if session.status == "active" else "A quiet conversation."}</h3>
                        <p>{"Start listening or add a typed turn. Your conversation will appear here." if session.status == "active" else "No turns were added to this session."}</p>
                    </div>}
                    <TranscriptScroll key={session.id} session={session} onSwapSpeaker={swapSpeaker}/>
                    {session.status == "ended" and <p className="session-ended-note">Conversation ended. The transcript is saved to your account.</p>}
                </section>}
                {session is not None and session.status == "active" and <aside className="card controls-card">
                    <h2>Make room for words.</h2>
                    {voice_enrolled and <p className="muted">Speakers are recognized by voice. Click a speaker name to correct it.</p>}
                    <fieldset className="speaker-picker">
                        <legend>{"Typed turns are from" if voice_enrolled else "Who is speaking?"}</legend>
                        <div className="speaker-segments">
                            {[<label key={value} className="speaker-option">
                                <input type="radio" name="conversation-speaker" value={value} checked={speaker == value}
                                    onChange={lambda (e: ChangeEvent) { speaker = e.target.value; spokenDraft = ""; }}/>
                                <span className="speaker-option-content">
                                    <span className={"speaker-choice-avatar " + value} aria-hidden="true">{"M" if value == "learner" else "P"}</span>
                                    <span>{"Me" if value == "learner" else "Partner"}</span>
                                    <svg className="speaker-check" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
                                        <path d="m5 12 4 4L19 6"/>
                                    </svg>
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
                        <label className="field">Or type a turn
                            <textarea rows={3} value={text} placeholder="A sentence, in your own words..."
                                onChange={lambda (e: ChangeEvent) { text = e.target.value; }}/>
                        </label>
                        <div className="composer-actions">
                            <button className="button button-secondary" disabled={busy or not text.strip()} onClick={addTurn}>Add turn</button>
                            {speechBusy and <p className="muted" role="status">Stop listening and wait for your turns to save before leaving Talk or ending.</p>}
                            <button className="button button-end" disabled={busy or speechBusy} onClick={finish}>End conversation</button>
                        </div>
                    </div>
                </aside>}
            </div>}
            {logged_in and page == "conversations" and <Conversations key={historyId} initialSessionId={historyId} active={session is not None} onTalk={lambda { page = "talk"; }}/>}
            <footer className="page-footer"><span className="footer-mark" aria-hidden="true">✦</span>A little more present. One conversation at a time.</footer>
        </main>
    </div>
}
