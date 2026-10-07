"""Conversation workspace. Typed turns stand in for the future ASR stream."""
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn, SignupResult }
import from .core.models { LearnerProfile, SessionView }
import from .endpoints { save_profile, start_conversation, append_turn, end_conversation }
import from .components.FeaturePanels { FeaturePanels }
def:pub app -> JsxElement {
    has logged_in: bool = jacIsLoggedIn(), email: str = "", password: str = "",
        native_language: str = "English", target_language: str = "Spanish", level: str = "A2",
        partner_mode: str = "human", consent: bool = False, session: SessionView | None = None,
        speaker: str = "partner", text: str = "", error: str = "", busy: bool = False;
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
        jacLogout(); logged_in = False; session = None; consent = False;
    }
    async def start() -> None {
        saved: LearnerProfile | None = None;
        created: SessionView | None = None;
        error = ""; busy = True;
        try {
            saved = await save_profile(native_language, target_language, level);
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
            updated = await append_turn(session.id, speaker, text);
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
    <main style={{"maxWidth": "850px", "margin": "2rem auto", "padding": "1rem", "fontFamily": "system-ui"}}>
        <h1>Language Assistant</h1>
        <p>Support during your conversation. Practice afterward.</p>
        {error and <p role="alert">{error}</p>}
        {not logged_in and <section>
            <h2>Welcome</h2>
            <label>Email <input type="email" value={email} onChange={lambda (e: ChangeEvent) { email = e.target.value; }}/></label>
            <label>Password <input type="password" value={password} onChange={lambda (e: ChangeEvent) { password = e.target.value; }}/></label>
            <button disabled={busy} onClick={lambda { authenticate(False); }}>Sign in</button>
            <button disabled={busy} onClick={lambda { authenticate(True); }}>Create account</button>
        </section>}
        {logged_in and <section>
            <button onClick={logout}>Sign out</button>
            {(session is None or session.status == "ended") and <section>
                <h2>Start a conversation</h2>
                <label>Native language <input value={native_language} onChange={lambda (e: ChangeEvent) { native_language = e.target.value; }}/></label>
                <label>Learning language <input value={target_language} onChange={lambda (e: ChangeEvent) { target_language = e.target.value; }}/></label>
                <label>CEFR level <select value={level} onChange={lambda (e: ChangeEvent) { level = e.target.value; }}>
                    {[<option key={value} value={value}>{value}</option> for value in ["A1", "A2", "B1", "B2", "C1", "C2"]]}
                </select></label>
                <label>Partner <select value={partner_mode} onChange={lambda (e: ChangeEvent) { partner_mode = e.target.value; }}>
                    <option value="human">Real person</option><option value="ai">AI partner</option>
                </select></label>
                <label><input type="checkbox" checked={consent} onChange={lambda (e: ChangeEvent) { consent = e.target.checked; }}/>
                    All participants agree to transcription, saved text, and sending conversation text to Gemini for requested help.
                </label>
                <p>Raw audio is not saved. This first version accepts typed transcript turns.</p>
                <button disabled={busy or not consent} onClick={start}>Start</button>
            </section>}
            {session is not None and <section>
                <h2>Transcript ? {session.status}</h2>
                <ol>{[<li key={turn.id}><strong>{turn.speaker}: </strong>{turn.text}</li> for turn in session.turns]}</ol>
                {session.status == "active" and <div>
                    <label>Speaker <select value={speaker} onChange={lambda (e: ChangeEvent) { speaker = e.target.value; }}>
                        <option value="partner">Partner</option><option value="learner">Me</option>
                    </select></label>
                    <label>Sentence <input value={text} onChange={lambda (e: ChangeEvent) { text = e.target.value; }}/></label>
                    <button disabled={busy or not text.strip()} onClick={addTurn}>Add turn</button>
                    <button disabled={busy} onClick={finish}>End conversation</button>
                </div>}
                <FeaturePanels key={session.id} session={session} onSessionChange={lambda (updated: SessionView) { session = updated; }}/>
            </section>}
        </section>}
    </main>
}
