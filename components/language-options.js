export const languages = [
	["ar-SA", "Arabic (Saudi Arabia)"],
	["zh-CN", "Chinese (China)"],
	["nl-NL", "Dutch (Netherlands)"],
	["en-US", "English (United States)"],
	["en-GB", "English (United Kingdom)"],
	["fr-FR", "French (France)"],
	["fr-CA", "French (Canada)"],
	["de-DE", "German (Germany)"],
	["hi-IN", "Hindi (India)"],
	["it-IT", "Italian (Italy)"],
	["ja-JP", "Japanese (Japan)"],
	["ko-KR", "Korean (South Korea)"],
	["pt-BR", "Portuguese (Brazil)"],
	["pt-PT", "Portuguese (Portugal)"],
	["ru-RU", "Russian (Russia)"],
	["es-ES", "Spanish (Spain)"],
	["es-MX", "Spanish (Mexico)"],
];

export function resolveLanguage(value) {
	const key = value.trim().toLowerCase();
	return (
		languages.find(
			([code, label]) =>
				code.toLowerCase() === key || label.toLowerCase() === key,
		) ||
		languages.find(
			([, label]) => label.split(" (")[0].toLowerCase() === key,
		) || [value, value]
	);
}

// Regional variants count as one language: English (US) and English (UK) match.
export function sameLanguage(first, second) {
	const base = (value) => resolveLanguage(value || "")[0].split("-")[0].toLowerCase();
	return base(first) === base(second);
}

// "Russian (Russia)" -> "Russian", for use in sentences and labels.
export function shortLanguageName(value) {
	return resolveLanguage(value || "")[1].split(" (")[0];
}
