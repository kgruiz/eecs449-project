import { Check, Search } from "lucide-react";
import { useId, useState } from "react";
import { languages, resolveLanguage } from "./language-options.js";
import { LanguageFlag } from "./language-flag.jsx";

export function OnboardingLanguage({ label, value, onChange }) {
	const [query, setQuery] = useState("");
	const id = useId();
	const selected = resolveLanguage(value)[0];
	const ordered = [...languages].sort((a, b) => {
		if (a[0] === selected) return -1;
		if (b[0] === selected) return 1;
		return a[1].localeCompare(b[1]);
	});
	const options = ordered.filter(([, name]) => name.toLowerCase().includes(query.toLowerCase()));
	return (
		<div className="onboarding-languages">
			<label className="onboarding-search" htmlFor={id}><Search size={18} aria-hidden="true" /><input type="search" id={id} value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search languages" aria-label={`Search ${label}`} /></label>
			<fieldset className="onboarding-language-options"><legend>{label}</legend>
				{options.map(([code, name]) => <label className={`onboarding-language-option ${code === selected ? "is-selected" : ""}`} key={code}><input type="radio" name={id} value={code} checked={code === selected} onChange={() => onChange(name)} /><LanguageFlag language={code} /><span>{name}</span>{code === selected && <Check size={18} aria-hidden="true" />}</label>)}
				{options.length === 0 && <p className="muted">No languages found. Try a different search.</p>}
			</fieldset>
		</div>
	);
}
