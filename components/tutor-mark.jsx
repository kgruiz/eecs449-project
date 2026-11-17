import { changedWords } from "./practice-diff.js";

// Keep the space after a word outside the mark so strikes and underlines
// stop at the word itself.
function Word({ word, Mark }) {
	if (!word.changed) return <span>{word.text}</span>;
	const text = word.text.trimEnd();
	return <>
		<Mark>{text}</Mark>
		{word.text.slice(text.length)}
	</>;
}

// A tutor's red-pen mark: the learner's words with removed words struck
// through, then the suggested wording with the new words written in.
// `kind` is "correction" (a clear error) or "improvement" (optional polish).
export function TutorMark({ original, suggestion, kind = "correction" }) {
	const struck = changedWords(suggestion, original);
	const written = changedWords(original, suggestion);
	return (
		<span className={`tutor-mark is-${kind === "improvement" ? "improvement" : "correction"}`}>
			<span className="tutor-mark-original">
				<span className="sr-only">You said: </span>
				{struck.map((word, index) => <Word key={index} word={word} Mark="del" />)}
			</span>
			<span className="tutor-mark-fix">
				<span className="sr-only">Try: </span>
				{written.map((word, index) => <Word key={index} word={word} Mark="ins" />)}
			</span>
		</span>
	);
}
