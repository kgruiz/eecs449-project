import from "./onboarding-language.jsx" { OnboardingLanguage }
import from "lucide-react" { ArrowRight, ArrowLeft, Check, MessageCircle, Languages, Sparkles }

def:pub Onboarding(name: str, nativeLanguage: str, targetLanguage: str, level: str,
    onName: Callable[[str], None], onNative: Callable[[str], None], onTarget: Callable[[str], None],
    onLevel: Callable[[str], None], onFinish: Callable[[], None], onProgress: Callable[[int], any], initialStep: int, busy: bool) -> JsxElement {
    has step: int = initialStep;
    async def advance() -> None {
        if step == 5 { onFinish(); return; }
        if await onProgress(step + 1) { step = step + 1; }
    }
    <section className="onboarding" aria-label="Getting started">
        <div className="onboarding-progress" aria-label={"Step " + str(step + 1) + " of 6"}>
            {[<span key={i} className={"progress-segment " + ("is-complete" if i <= step else "")}/> for i in [0, 1, 2, 3, 4, 5]]}
        </div>
        <div className="onboarding-content" key={step}>
            {step == 0 and <div><p className="eyebrow">WELCOME TO PIP</p><h1>Real conversations.<br/>Real progress.</h1><p className="onboarding-intro">Pip helps you learn from the conversations you already have.</p><div className="speech-art onboarding-art" aria-hidden="true"><span className="speech-bubble speech-bubble-back"/><span className="speech-bubble speech-bubble-front"><i/><i/><i/></span><span className="speech-spark">✦</span></div></div>}
            {step == 1 and <div><p className="eyebrow">FIRST, A LITTLE ABOUT YOU</p><h1>What should we call you?</h1><p className="onboarding-intro">Let’s make this feel like your space.</p><label className="field onboarding-field">Your name<input autoComplete="given-name" maxLength={80} placeholder="Your first name" value={name} onChange={lambda (e: ChangeEvent) { onName(e.target.value); }}/></label></div>}
            {step == 2 and <div><p className="eyebrow">YOUR FIRST LANGUAGE</p><h1>What language do you know best?</h1><p className="onboarding-intro">We’ll use it to explain feedback and help you understand your conversations.</p><div className="onboarding-field"><OnboardingLanguage label="Language you know best" value={nativeLanguage} onChange={onNative}/></div></div>}
            {step == 3 and <div><p className="eyebrow">YOUR LEARNING LANGUAGE</p><h1>What language are you learning?</h1><p className="onboarding-intro">Choose the language you want to practice. You can change it later.</p><div className="onboarding-field"><OnboardingLanguage label="Language you are learning" value={targetLanguage} onChange={onTarget}/></div></div>}
            {step == 4 and <div><p className="eyebrow">YOUR EXPERIENCE</p><h1>{"How comfortable are you in " + targetLanguage + "?"}</h1><p className="onboarding-intro">Choose what feels closest. You can change it later.</p><fieldset className="onboarding-levels"><legend>{"Your level in " + targetLanguage}</legend>{[<label key={item} className={"onboarding-level " + ("is-selected" if level == item else "")}><input type="radio" name="onboarding-level" value={item} checked={level == item} onChange={lambda { onLevel(item); }}/><span className="level-code">{item}</span><span className="level-description">{"Just starting" if item == "A1" else "The basics" if item == "A2" else "Finding my words" if item == "B1" else "Holding conversations" if item == "B2" else "Speaking comfortably" if item == "C1" else "Highly fluent"}</span>{level == item and <Check size={18} aria-hidden="true"/>}</label> for item in ["A1", "A2", "B1", "B2", "C1", "C2"]]}</fieldset><p className="onboarding-level-hint" aria-live="polite">{"I can use familiar words and phrases." if level == "A1" else "I can manage simple, everyday exchanges." if level == "A2" else "I can discuss familiar topics, with pauses." if level == "B1" else "I can discuss a range of topics with some ease." if level == "B2" else "I can express myself fluently in most situations." if level == "C1" else "I can understand and express subtle meaning."}</p></div>}
            {step == 5 and <div><p className="eyebrow">HOW PIP HELPS</p><h1>Support for real conversations.</h1><p className="onboarding-intro">Talk with someone and get help along the way.</p><div className="onboarding-benefits"><p><Sparkles size={20}/> <span><strong>Find the next word</strong><br/>Get a suggestion when you need one.</span></p><p><Languages size={20}/> <span><strong>Understand a phrase</strong><br/>Translate a conversation turn into English.</span></p><p><MessageCircle size={20}/> <span><strong>Learn from your conversation</strong><br/>Review your transcript and feedback afterward.</span></p></div></div>}
        </div>
        <div className="onboarding-actions">
            {step > 0 and <button className="button button-secondary" disabled={busy} onClick={lambda { step = step - 1; }}><ArrowLeft size={18}/> Back</button>}
            <button className="button button-primary onboarding-next" disabled={busy or (step == 1 and not name.strip())} onClick={advance}>{"Saving..." if busy else ("Go to my home" if step == 5 else ("Let’s get started" if step == 0 else "Continue"))}<ArrowRight size={18}/></button>
        </div>
    </section>
}
