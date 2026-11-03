import { Check, ChevronDown, Search } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import { LanguageFlag } from "./language-flag.jsx";
import { languages, resolveLanguage } from "./language-options.js";

export function CustomDropdown({
	label,
	value,
	onChange,
	choices,
	searchable = false,
	flags = false,
	disabled = false,
	hideLabel = false,
	inputId,
}) {
	const id = useId();
	const root = useRef(null);
	const trigger = useRef(null);
	const search = useRef(null);
	const menu = useRef(null);
	const [open, setOpen] = useState(false);
	const [query, setQuery] = useState("");
	const [active, setActive] = useState(0);
	const selected = choices.find((option) => option[0] === value) || [
		value,
		value,
	];
	const options = choices.filter(([, name]) =>
		name.toLowerCase().includes(query.toLowerCase()),
	);

	useEffect(() => {
		if (!open) return;
		(searchable ? search : menu).current?.focus();
		const dismiss = (event) => {
			if (!root.current?.contains(event.target)) setOpen(false);
		};
		document.addEventListener("pointerdown", dismiss);
		document.addEventListener("focusin", dismiss);
		return () => {
			document.removeEventListener("pointerdown", dismiss);
			document.removeEventListener("focusin", dismiss);
		};
	}, [open, searchable]);

	useEffect(() => {
		if (open)
			document
				.getElementById(`${id}-option-${active}`)
				?.scrollIntoView({ block: "nearest" });
	}, [active, id, open]);

	function show() {
		setQuery("");
		const index = choices.findIndex(
			(option) => option[0] === value && !option[2],
		);
		setActive(index >= 0 ? index : choices.findIndex((option) => !option[2]));
		setOpen(true);
	}

	function choose(option) {
		if (!option || option[2]) return;
		onChange(option[0]);
		setOpen(false);
		trigger.current?.focus();
	}

	function navigate(event) {
		if (event.key === "Escape") {
			event.preventDefault();
			event.stopPropagation();
			setOpen(false);
			trigger.current?.focus();
		}
		if (["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) {
			if (searchable && ["Home", "End"].includes(event.key)) return;
			event.preventDefault();
			const direction = ["ArrowUp", "End"].includes(event.key) ? -1 : 1;
			let next =
				event.key === "Home"
					? 0
					: event.key === "End"
						? options.length - 1
						: active + direction;
			while (next >= 0 && next < options.length && options[next][2])
				next += direction;
			if (next >= 0 && next < options.length) setActive(next);
		}
		if (event.key === "Enter" || (!searchable && event.key === " ")) {
			event.preventDefault();
			choose(options[active]);
		}
	}

	function optionLabel(option) {
		return (
			<span className="language-option-label">
				{flags && <LanguageFlag language={option[0]} />} {option[1]}
			</span>
		);
	}

	return (
		<div className="field language-picker" ref={root}>
			<span id={`${id}-label`} hidden={hideLabel}>
				{label}
			</span>
			<button
				ref={trigger}
				id={inputId}
				type="button"
				className="language-picker-trigger"
				disabled={disabled}
				aria-labelledby={`${id}-label ${id}-value`}
				aria-haspopup="listbox"
				aria-expanded={open}
				aria-controls={open ? `${id}-list` : undefined}
				onClick={() => (open ? setOpen(false) : show())}
				onKeyDown={(event) => {
					if (["ArrowDown", "ArrowUp"].includes(event.key)) {
						event.preventDefault();
						show();
					}
				}}
			>
				<span id={`${id}-value`}>{optionLabel(selected)}</span>
				<ChevronDown size={16} aria-hidden="true" />
			</button>
			{open && (
				<div className="language-picker-popover">
					{searchable && (
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
									active >= 0 && options[active]
										? `${id}-option-${active}`
										: undefined
								}
								placeholder="Search languages"
								value={query}
								onChange={(event) => {
									setQuery(event.target.value);
									setActive(0);
								}}
								onKeyDown={navigate}
							/>
						</div>
					)}
					<div
						ref={menu}
						role="listbox"
						id={`${id}-list`}
						aria-labelledby={`${id}-label`}
						tabIndex={searchable ? undefined : 0}
						aria-activedescendant={
							!searchable && options[active]
								? `${id}-option-${active}`
								: undefined
						}
						onKeyDown={searchable ? undefined : navigate}
					>
						{options.map((option, index) => (
							<div
								role="option"
								tabIndex={-1}
								id={`${id}-option-${index}`}
								key={option[0]}
								aria-selected={selected[0] === option[0]}
								aria-disabled={Boolean(option[2])}
								className={index === active && !option[2] ? "is-active" : ""}
								onMouseDown={(event) => event.preventDefault()}
								onClick={() => choose(option)}
								onKeyDown={(event) => {
									if (event.key === "Enter" || event.key === " ") {
										event.preventDefault();
										event.stopPropagation();
										choose(option);
									}
								}}
							>
								{optionLabel(option)}
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

export function LanguagePicker({ label, value, onChange, disabled = false }) {
	return (
		<CustomDropdown
			label={label}
			value={resolveLanguage(value)[0]}
			choices={languages}
			searchable
			flags
			disabled={disabled}
			onChange={(code) => onChange(resolveLanguage(code)[1])}
		/>
	);
}

const levels = ["A1", "A2", "B1", "B2", "C1", "C2"].map((value) => [
	value,
	value,
]);
const partners = [
	["human", "Real person"],
	["ai", "AI partner (coming soon)", true],
];

export function LevelPicker({ value, onChange }) {
	return (
		<CustomDropdown
			label="Level"
			inputId="learner-level"
			hideLabel
			value={value}
			onChange={onChange}
			choices={levels}
		/>
	);
}

export function PartnerPicker({ value, onChange }) {
	return (
		<CustomDropdown
			label="Partner"
			value={value}
			onChange={onChange}
			choices={partners}
		/>
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
