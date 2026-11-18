import { ArrowRight } from "lucide-react";
import { shortLanguageName } from "./language-options.js";

function shortDate(value) {
	if (!value) return "Earlier conversation";
	return new Date(value).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

// One row design for a saved conversation, shared by Home and Conversations.
// `detailed` adds the turn count and feedback status used in the full library.
export function ConversationRow({ item, onOpen, detailed = false }) {
	const meta = [shortLanguageName(item.target_language), item.level, shortDate(item.created_at)];
	if (detailed) meta.push(`${item.turn_count} ${item.turn_count === 1 ? "turn" : "turns"}`);
	return (
		<button type="button" className="home-conversation" onClick={() => onOpen(item.id)}>
			<span className="conversation-emoji" aria-hidden="true">{item.emoji}</span>
			<span className="home-conversation-copy">
				<strong>{item.title}</strong>
				<span>{meta.join(" · ")}</span>
				<small>{item.preview}</small>
			</span>
			{detailed && item.has_coaching && <span className="conversation-badge">Feedback ready</span>}
			<ArrowRight size={19} aria-hidden="true" />
		</button>
	);
}
