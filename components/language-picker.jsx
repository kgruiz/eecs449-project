import { Check, ChevronDown, Search } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";

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

export function LanguagePicker({ label, value, onChange, disabled = false }) {
	const id = useId();
	const root = useRef(null);
	const trigger = useRef(null);
	const search = useRef(null);
	const [open, setOpen] = useState(false);
	const [query, setQuery] = useState("");
	const [active, setActive] = useState(0);
	const selected = resolveLanguage(value);
	const options = languages.filter(([, name]) =>
		name.toLowerCase().includes(query.toLowerCase()),
	);

	useEffect(() => {
		if (!open) return;
		search.current?.focus();
		const dismiss = (event) => {
			if (!root.current?.contains(event.target)) setOpen(false);
		};
		document.addEventListener("pointerdown", dismiss);
		document.addEventListener("focusin", dismiss);
		return () => {
			document.removeEventListener("pointerdown", dismiss);
			document.removeEventListener("focusin", dismiss);
		};
	}, [open]);

	useEffect(() => {
		if (open)
			document
				.getElementById(`${id}-option-${active}`)
				?.scrollIntoView({ block: "nearest" });
	}, [active, id, open]);

	function choose(option) {
		onChange(option[1]);
		setOpen(false);
		trigger.current?.focus();
	}

	return (
		<div className="field language-picker" ref={root}>
			<span id={`${id}-label`}>{label}</span>
			<button
				ref={trigger}
				type="button"
				className="language-picker-trigger"
				disabled={disabled}
				aria-labelledby={`${id}-label ${id}-value`}
				aria-haspopup="listbox"
				aria-expanded={open}
				onClick={() => {
					setOpen(!open);
					setQuery("");
					setActive(0);
				}}
			>
				<span id={`${id}-value`}>{selected[1]}</span>
				<ChevronDown size={16} aria-hidden="true" />
			</button>
			{open && (
				<div className="language-picker-popover">
					<div className="language-search">
						<Search size={16} aria-hidden="true" />
						<input
							ref={search}
							role="combobox"
							aria-label={`Search ${label.toLowerCase()}`}
							aria-expanded="true"
							aria-controls={`${id}-list`}
							aria-autocomplete="list"
							aria-activedescendant={
								options.length ? `${id}-option-${active}` : undefined
							}
							placeholder="Search languages"
							value={query}
							onChange={(event) => {
								setQuery(event.target.value);
								setActive(0);
							}}
							onKeyDown={(event) => {
								if (event.key === "Escape") {
									event.preventDefault();
									event.stopPropagation();
									setOpen(false);
									trigger.current?.focus();
								}
								if (event.key === "ArrowDown" || event.key === "ArrowUp") {
									event.preventDefault();
									setActive(
										Math.max(
											0,
											Math.min(
												options.length - 1,
												active + (event.key === "ArrowDown" ? 1 : -1),
											),
										),
									);
								}
								if (event.key === "Enter" && options[active]) {
									event.preventDefault();
									choose(options[active]);
								}
							}}
						/>
					</div>
					<div role="listbox" id={`${id}-list`} aria-labelledby={`${id}-label`}>
						{options.map((option, index) => (
							<div
								role="option"
								tabIndex={-1}
								onKeyDown={(event) => {
									if (event.key === "Enter" || event.key === " ") {
										event.preventDefault();
										choose(option);
									}
								}}
								id={`${id}-option-${index}`}
								key={option[0]}
								aria-selected={selected[0] === option[0]}
								className={index === active ? "is-active" : ""}
								onMouseDown={(event) => event.preventDefault()}
								onClick={() => choose(option)}
							>
								{option[1]}
								{selected[0] === option[0] && (
									<Check size={16} aria-hidden="true" />
								)}
							</div>
						))}
					</div>
					{!options.length && (
						<p className="language-no-results" role="status">
							No languages found
						</p>
					)}
				</div>
			)}
		</div>
	);
}

export function ListeningLanguage({ value, onChange, disabled }) {
	const dialog = useRef(null);
	const [draft, setDraft] = useState(value);
	const id = useId();
	return (
		<div className="listening-language">
			<span>
				Listening language: <strong>{resolveLanguage(value)[1]}</strong>
			</span>
			<button
				type="button"
				className="language-change"
				disabled={disabled}
				onClick={() => {
					setDraft(value);
					dialog.current.showModal();
				}}
			>
				Change
			</button>
			<dialog ref={dialog} className="language-dialog" aria-labelledby={id}>
				<h2 id={id}>Listening language</h2>
				<LanguagePicker label="Language" value={draft} onChange={setDraft} />
				<div className="language-dialog-actions">
					<button
						type="button"
						className="button button-secondary"
						onClick={() => dialog.current.close()}
					>
						Cancel
					</button>
					<button
						type="button"
						className="button button-primary"
						onClick={() => {
							onChange(resolveLanguage(draft)[0]);
							dialog.current.close();
						}}
					>
						Apply
					</button>
				</div>
			</dialog>
		</div>
	);
}
