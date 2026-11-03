import {
	ArrowRight,
	Check,
	Mic,
	RotateCcw,
	Square,
	Volume2,
} from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import { resolveLanguage } from "./language-options.js";

export function PracticeExercises({
	priorities,
	language,
	onCheck,
	compareWords,
}) {
	const [index, setIndex] = useState(0);
	const [done, setDone] = useState(false);

	if (done) {
		return (
			<div className="practice-complete">
				<Check size={24} aria-hidden="true" />
				<h3>Practice reviewed</h3>
				<p>Try these phrases in your next conversation.</p>
				<button
					type="button"
					className="button button-secondary"
					onClick={() => {
						setIndex(0);
						setDone(false);
					}}
				>
					<RotateCcw size={16} aria-hidden="true" />
					Practice again
				</button>
			</div>
		);
	}

	return (
		<PracticeExercise
			key={index}
			item={priorities[index]}
			index={index}
			total={priorities.length}
			language={language}
			onCheck={onCheck}
			compareWords={compareWords}
			onNext={() => {
				if (index + 1 < priorities.length) {
					setIndex(index + 1);
				} else {
					setDone(true);
				}
			}}
		/>
	);
}

function PracticeExercise({
	compareWords,
	item,
	index,
	total,
	language,
	onCheck,
	onNext,
}) {
	const [answer, setAnswer] = useState("");
	const [result, setResult] = useState(null);
	const [busy, setBusy] = useState(false);
	const [listening, setListening] = useState(false);
	const [speaking, setSpeaking] = useState(false);
	const [error, setError] = useState("");
	const recognition = useRef(null);
	const utterance = useRef(null);
	const request = useRef(0);
	const input = useRef(null);
	const id = useId();
	const locale = resolveLanguage(language)[0];
	const Recognizer =
		globalThis.SpeechRecognition || globalThis.webkitSpeechRecognition;
	const canSpeak = Boolean(
		globalThis.speechSynthesis && globalThis.SpeechSynthesisUtterance,
	);

	useEffect(
		() => () => {
			request.current++;

			if (recognition.current) {
				recognition.current.onresult = null;
				recognition.current.onerror = null;
				recognition.current.onend = null;
				recognition.current.abort();
			}

			if (utterance.current) {
				utterance.current.onend = null;
				utterance.current.onerror = null;
				globalThis.speechSynthesis?.cancel();
			}
		},
		[],
	);

	function listen() {
		setError("");

		if (speaking) {
			globalThis.speechSynthesis.cancel();
			setSpeaking(false);
			return;
		}
		const synth = globalThis.speechSynthesis;
		const voices = synth.getVoices();
		const voice =
			voices.find((v) => v.lang.toLowerCase() === locale.toLowerCase()) ||
			voices.find((v) => v.lang.split("-")[0] === locale.split("-")[0]);

		if (!voice) {
			setError("No voice is available for this language on this device.");
			return;
		}
		const speech = new SpeechSynthesisUtterance(item.suggestion);
		speech.lang = locale;
		speech.voice = voice;
		speech.rate = 0.85;
		speech.onend = () => {
			setSpeaking(false);
			utterance.current = null;
		};
		speech.onerror = (event) => {
			setSpeaking(false);
			utterance.current = null;

			if (event.error !== "canceled" && event.error !== "interrupted") {
				setError("Could not play this phrase. Try listening again.");
			}
		};
		utterance.current = speech;
		setSpeaking(true);
		synth.speak(speech);
	}

	function record() {
		if (recognition.current) {
			recognition.current.stop();
			return;
		}
		setError("");
		setResult(null);
		const recognizer = new Recognizer();
		const prefix = answer.trim();
		recognizer.lang = locale;
		recognizer.continuous = false;
		recognizer.interimResults = true;
		recognizer.onresult = (event) => {
			const spoken = Array.from(
				event.results,
				(part) => part[0].transcript,
			).join(" ");
			setAnswer([prefix, spoken].filter(Boolean).join(" ").slice(0, 2000));
		};
		recognizer.onerror = (event) => {
			if (event.error !== "aborted") {
				setError(
					event.error === "not-allowed"
						? "Microphone access was denied. Allow access or type your answer."
						: "Speech could not be captured. Try again or type your answer.",
				);
			}
		};
		recognizer.onend = () => {
			recognition.current = null;
			setListening(false);
		};
		recognition.current = recognizer;
		setListening(true);

		try {
			recognizer.start();
		} catch {
			recognition.current = null;
			setListening(false);
			setError(
				"Could not start the microphone. You can type your answer instead.",
			);
		}
	}

	async function check(event) {
		event.preventDefault();

		if (busy || listening || !answer.trim()) {
			return;
		}
		const token = ++request.current;
		setBusy(true);
		setError("");
		setResult(null);

		try {
			const feedback = await onCheck(index, answer.trim());

			if (token === request.current) {
				setResult(feedback);
			}
		} catch {
			if (token === request.current) {
				setError(
					"Could not check your answer. Your text is still here; please try again.",
				);
			}
		} finally {
			if (token === request.current) {
				setBusy(false);
			}
		}
	}

	return (
		<article className="practice-exercise">
			<p className="practice-count">
				{item.kind === "correction"
					? "Correction"
					: item.kind === "improvement"
						? "Optional improvement"
						: "Practice note"}{" "}
				· {index + 1} of {total}
			</p>
			<div className="practice-reason">
				{item.title && <h3>{item.title}</h3>}
				<p>{item.explanation}</p>
			</div>
			<div className="practice-comparison">
				<div>
					<span className="practice-label">You said</span>
					<p lang={locale}>{item.quote}</p>
				</div>
				<ArrowRight
					className="practice-comparison-arrow"
					size={20}
					aria-hidden="true"
				/>
				<div className="practice-suggestion">
					<span className="practice-label">
						{item.kind === "correction"
							? "Correction"
							: item.kind === "improvement"
								? "Another way to say it"
								: "Suggested wording"}
					</span>
					<p lang={locale}>
						{compareWords(item.quote, item.suggestion).map((word, wordIndex) =>
							word.changed ? (
								<mark key={`${wordIndex}-${word.text}`}>{word.text}</mark>
							) : (
								word.text
							),
						)}
					</p>
					<button
						type="button"
						className="button button-quiet practice-listen"
						onClick={listen}
						disabled={!canSpeak || listening || busy}
					>
						{speaking ? (
							<Square size={16} aria-hidden="true" />
						) : (
							<Volume2 size={16} aria-hidden="true" />
						)}
						{speaking ? "Stop playback" : "Listen"}
					</button>
					{!canSpeak && (
						<small>Audio playback is unavailable in this browser.</small>
					)}
				</div>
			</div>
			<form onSubmit={check} className="practice-answer">
				<h3>Try it yourself</h3>
				<p id={`${id}-prompt`}>{item.practice}</p>
				<label htmlFor={id}>Your answer</label>
				<textarea
					ref={input}
					id={id}
					aria-describedby={`${id}-prompt ${id}-note`}
					lang={locale}
					dir="auto"
					maxLength={2000}
					rows={3}
					value={answer}
					disabled={busy || listening}
					placeholder="Type your answer…"
					onChange={(event) => {
						setAnswer(event.target.value);
						setResult(null);
						setError("");
					}}
				/>
				<div className="practice-actions">
					{Recognizer && (
						<button
							type="button"
							className="button button-secondary"
							disabled={busy || speaking}
							onClick={record}
						>
							{listening ? (
								<Square size={16} aria-hidden="true" />
							) : (
								<Mic size={16} aria-hidden="true" />
							)}
							{listening ? "Stop listening" : "Speak answer"}
						</button>
					)}
					<button
						type="submit"
						className="button button-primary"
						disabled={busy || listening || speaking || !answer.trim()}
					>
						{busy ? "Checking…" : "Check answer"}
					</button>
				</div>
				<p id={`${id}-note`} className="practice-note">
					Answers are sent to AI when you check them and aren't added to your
					transcript.{" "}
					{Recognizer
						? "Speech uses your browser's transcription service; you can edit the text before checking."
						: "Voice input is unavailable in this browser; type your answer instead."}
				</p>
				{listening && <p role="status">Listening…</p>}
				{busy && <p role="status">Checking your wording…</p>}
				{error && (
					<p className="error-banner" role="alert">
						{error}
					</p>
				)}
				{result && (
					<div className="practice-feedback" role="status">
						<strong>
							{result.outcome === "correct"
								? "That works"
								: result.outcome === "revise"
									? "Try a small change"
									: "Needs another look"}
						</strong>
						<p>{result.feedback}</p>
						{result.outcome === "revise" && result.corrected_answer && (
							<p lang={locale}>
								<span className="practice-label">Suggested wording</span>
								{result.corrected_answer}
							</p>
						)}
						<div className="practice-actions">
							<button
								type="button"
								className="button button-secondary"
								onClick={() => {
									setResult(null);
									input.current?.focus();
								}}
							>
								<RotateCcw size={16} aria-hidden="true" />
								Try again
							</button>
							<button
								type="button"
								className="button button-primary"
								onClick={onNext}
							>
								{index + 1 === total ? "Finish practice" : "Next suggestion"}
								<ArrowRight size={16} aria-hidden="true" />
							</button>
						</div>
					</div>
				)}
			</form>
		</article>
	);
}
