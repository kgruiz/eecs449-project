import { Hand } from "lucide-react";
import { useEffect, useRef } from "react";

// Pointer capture and global release handle drags, interruptions and lost focus.
export function HoldSpeaker({ speaking, onChange, disabled }) {
	const held = useRef(false);
	const callback = useRef(onChange);
	callback.current = onChange;
	function release() {
		if (held.current) {
			held.current = false;
			callback.current(false);
		}
	}
	useEffect(() => {
		const onVisibility = () => { if (document.hidden) release(); };
		window.addEventListener("blur", release);
		window.addEventListener("pointerup", release);
		window.addEventListener("pointercancel", release);
		document.addEventListener("visibilitychange", onVisibility);
		return () => {
			window.removeEventListener("blur", release);
			window.removeEventListener("pointerup", release);
			window.removeEventListener("pointercancel", release);
			document.removeEventListener("visibilitychange", onVisibility);
			release();
		};
	}, []);
	function press() {
		if (!held.current && !disabled) {
			held.current = true;
			callback.current(true);
		}
	}
	return <div className="hold-speaker">
		<p className="hold-speaker-status" aria-live="polite">{speaking ? "Me speaking" : "Partner speaking"}</p>
		<button type="button" className={`hold-speaker-button ${speaking ? "is-held" : ""}`} disabled={disabled}
			aria-label="Hold while you speak; assistive technology can activate to toggle" aria-pressed={speaking}
			onPointerDown={(event) => { if (event.button === 0) { event.preventDefault(); event.currentTarget.setPointerCapture(event.pointerId); press(); } }}
			onPointerUp={release} onPointerCancel={release} onLostPointerCapture={release} onBlur={release}
			onClick={(event) => { if (event.detail === 0) { if (held.current) release(); else press(); } }}
			onKeyDown={(event) => { if ((event.key === " " || event.key === "Enter") && !event.repeat) { event.preventDefault(); press(); } }}
			onKeyUp={(event) => { if (event.key === " " || event.key === "Enter") { event.preventDefault(); release(); } }}>
			<Hand size={29} aria-hidden="true"/><span>Me</span>
		</button>
		<p className="hold-speaker-help">{speaking ? "Release when you finish" : "Hold while you speak"}</p>
	</div>;
}
