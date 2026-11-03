// Match words in sequence so only additions/replacements receive emphasis.
export function changedWords(original, suggestion) {
	const words = suggestion.match(/\S+\s*/gu) || [];
	const before = original.match(/\S+/gu) || [];
	const normalize = (word) =>
		word.toLocaleLowerCase().replace(/[^\p{L}\p{N}]/gu, "");
	const left = before.map(normalize);
	const right = words.map(normalize);
	const lengths = Array.from({ length: left.length + 1 }, () =>
		Array(right.length + 1).fill(0),
	);

	for (let i = left.length - 1; i >= 0; i--) {
		for (let j = right.length - 1; j >= 0; j--) {
			lengths[i][j] =
				left[i] === right[j]
					? lengths[i + 1][j + 1] + 1
					: Math.max(lengths[i + 1][j], lengths[i][j + 1]);
		}
	}
	const unchanged = new Set();
	let i = 0;
	let j = 0;

	while (i < left.length && j < right.length) {
		if (left[i] === right[j]) {
			unchanged.add(j++);
			i++;
		} else if (lengths[i + 1][j] >= lengths[i][j + 1]) {
			i++;
		} else {
			j++;
		}
	}

	return words.map((text, index) => ({ text, changed: !unchanged.has(index) }));
}
