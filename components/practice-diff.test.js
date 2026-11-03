import { expect, test } from "bun:test";
import { changedWords } from "./practice-diff.js";

test("highlights replacement while retaining surrounding words", () => {
	expect(
		changedWords("Yo ir al parque.", "Yo voy al parque.")
			.filter((part) => part.changed)
			.map((part) => part.text),
	).toEqual(["voy "]);
});
test("preserves Unicode accents and detects repeated added words", () => {
	expect(changedWords("Como te llamas", "¿Cómo te llamas?")[0].changed).toBe(
		true,
	);
	expect(changedWords("voy", "voy voy").map((part) => part.changed)).toEqual([
		false,
		true,
	]);
	expect(changedWords("你好", "你好")[0].changed).toBe(false);
});
test("keeps original spacing and punctuation in displayed suggestion", () => {
	const text = "Hola,  ¿cómo estás?";
	expect(
		changedWords("hola", text)
			.map((part) => part.text)
			.join(""),
	).toBe(text);
});
