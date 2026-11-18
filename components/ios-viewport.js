// Limit automatic input-focus zoom on iOS without changing control sizing.
const isIOS = /iPhone|iPad|iPod/.test(navigator.userAgent)
	|| (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

if (isIOS) {
	const viewport = document.querySelector('meta[name="viewport"]');
	if (viewport) {
		const settings = viewport.content.split(",").map((setting) => setting.trim())
			.filter((setting) => !/^maximum-scale\s*=/i.test(setting));
		viewport.content = [...settings, "maximum-scale=1"].filter(Boolean).join(", ");
	}
}
