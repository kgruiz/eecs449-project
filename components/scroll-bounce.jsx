import { useEffect } from "react";

export function ScrollBounce() {
	useEffect(() => {
		const app = document.querySelector(".pip-app");
		const root = document.documentElement;
		const observed = new Set();
		let frame = 0;

		function schedule() {
			if (!frame) frame = requestAnimationFrame(update);
		}

		const resize = new ResizeObserver(schedule);

		function update() {
			frame = 0;
			const elements = new Set([app, ...app.querySelectorAll("*")]);

			for (const element of observed) {
				if (!elements.has(element)) {
					resize.unobserve(element);
					observed.delete(element);
				}
			}

			for (const element of elements) {
				if (!observed.has(element)) {
					resize.observe(element);
					observed.add(element);
				}
				const scrollable = /^(auto|scroll)$/.test(
					getComputedStyle(element).overflowY,
				);
				const overflows =
					element.clientHeight > 0 &&
					element.scrollHeight > element.clientHeight + 1;
				element.toggleAttribute("data-scroll-bounce", scrollable && overflows);
			}

			root.toggleAttribute(
				"data-scroll-bounce",
				root.scrollHeight > root.clientHeight + 1,
			);
		}

		const mutations = new MutationObserver((records) => {
			if (
				records.some((record) => record.attributeName !== "data-scroll-bounce")
			)
				schedule();
		});
		mutations.observe(app, {
			subtree: true,
			childList: true,
			characterData: true,
			attributes: true,
		});
		window.addEventListener("resize", schedule);
		app.addEventListener("input", schedule);
		schedule();

		return () => {
			cancelAnimationFrame(frame);
			resize.disconnect();
			mutations.disconnect();
			window.removeEventListener("resize", schedule);
			app.removeEventListener("input", schedule);
			root.removeAttribute("data-scroll-bounce");
			for (const element of observed)
				element.removeAttribute("data-scroll-bounce");
		};
	}, []);

	return null;
}
