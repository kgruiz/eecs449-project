import { ArrowRight, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";

const browsers = ["Safari", "Chrome", "Google app", "Other"];

function environment() {
	const ua = navigator.userAgent;
	const ios = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
	const standalone = navigator.standalone === true || window.matchMedia("(display-mode: standalone)").matches;
	let browser = "Other";
	if (/CriOS/i.test(ua)) browser = "Chrome";
	else if (/GSA\//i.test(ua)) browser = "Google app";
	else if (/Safari/i.test(ua) && !/FxiOS|EdgiOS|OPiOS|DuckDuckGo|YaBrowser/i.test(ua)) browser = "Safari";
	return { ios, standalone, browser };
}

// These links are present on every page, including sign-in and onboarding.
export function WebAppMetadata() {
	return <><link rel="manifest" href="/static/assets/pip.webmanifest" /><link rel="apple-touch-icon" href="/static/assets/pip-icon-180.png" /><meta name="apple-mobile-web-app-capable" content="yes" /><meta name="apple-mobile-web-app-title" content="Pip" /><meta name="theme-color" content="#f8f7f2" /></>;
}

export function HomeScreenInstall() {
	const [detected] = useState(environment);
	const [preview, setPreview] = useState(null);
	const [browser, setBrowser] = useState(detected.browser);
	const [dismissed, setDismissed] = useState(false);
	const [open, setOpen] = useState(false);
	const dialog = useRef(null);

	// TEMPORARY QA: S/C/G/O preview browsers; P previews standalone; R resets.
	useEffect(() => {
		if (!import.meta.env.DEV) return;
		const keys = { s: "Safari", c: "Chrome", g: "Google app", o: "Other" };
		const onKey = (event) => {
			if (event.ctrlKey || event.metaKey || event.altKey || event.target?.closest("input, textarea, select, [contenteditable=true]")) return;
			const key = event.key.toLowerCase();
			if (key === "r") { setPreview(null); setBrowser(detected.browser); setDismissed(false); }
			else if (key === "p") { setOpen(false); setPreview("standalone"); }
			else if (keys[key]) { setPreview(keys[key]); setBrowser(keys[key]); setDismissed(false); }
		};
		window.addEventListener("keydown", onKey);
		return () => window.removeEventListener("keydown", onKey);
	}, [detected.browser]);
	useEffect(() => {
		if (open && !dialog.current?.open) dialog.current?.showModal();
		else if (!open && dialog.current?.open) dialog.current.close();
	}, [open]);

	if (preview === "standalone" || ((!detected.ios || detected.standalone || dismissed) && !preview)) return null;
	return <>
		<div className="install-prompt">
			<span className="install-prompt-icon" aria-hidden="true">⚠️</span>
			<button className="install-prompt-main" onClick={() => setOpen(true)}><strong>You’re using Pip on the web.</strong><span>Add to your Home Screen for easier practice <ArrowRight size={15} aria-hidden="true" /></span></button>
			<button className="install-prompt-dismiss" aria-label="Dismiss Home Screen suggestion" onClick={() => { setDismissed(true); setPreview(null); }}><X size={17} aria-hidden="true" /></button>
		</div>
		<dialog ref={dialog} className="install-dialog" aria-labelledby="install-title" onClose={() => setOpen(false)}>
			<div className="install-dialog-header"><span className="install-dialog-icon" aria-hidden="true">🏡</span><button className="install-dialog-close" aria-label="Close instructions" onClick={() => setOpen(false)}><X size={20} aria-hidden="true" /></button></div>
			<p className="eyebrow">YOUR SPACE TO GROW</p><h2 id="install-title">A home for Pip.</h2><p className="install-intro">Keep practice within reach. Add Pip to your Home Screen and come back whenever you’re ready.</p>
			<div className="install-browser-row"><label className="install-browser-label" htmlFor="install-browser">Using</label><select id="install-browser" value={browser} onChange={(event) => setBrowser(event.target.value)}>{browsers.map((name) => <option key={name}>{name}</option>)}</select></div>
			{browser === "Safari" && <ol className="install-steps"><li>Tap the <strong>three-line menu</strong> next to the address bar.</li><li>Tap <strong>Share</strong>.</li><li>Scroll down and tap <strong>Add to Home Screen</strong>.</li></ol>}
			{browser === "Chrome" && <ol className="install-steps"><li>Tap <strong>Share</strong> on the right of the address bar.</li><li>Find and tap <strong>Add to Home Screen</strong>.</li></ol>}
			{browser === "Google app" && <ol className="install-steps"><li>Tap <strong>Share</strong> in the Google app.</li><li>Tap <strong>Open in Safari</strong>.</li><li>Tap the <strong>three-line menu</strong> next to the address bar.</li><li>Tap <strong>Share</strong>.</li><li>Scroll down and tap <strong>Add to Home Screen</strong>.</li></ol>}
			{browser === "Other" && <ol className="install-steps"><li>Open this page in <strong>Safari</strong> or <strong>Chrome</strong> using your browser’s menu or Share button.</li><li>Choose that browser above for its instructions.</li></ol>}
			<button className="button button-primary install-done" onClick={() => setOpen(false)}>Got it</button>
		</dialog>
	</>;
}
