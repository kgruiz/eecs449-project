import brFlag from "flag-icons/flags/4x3/br.svg";
import caFlag from "flag-icons/flags/4x3/ca.svg";
import cnFlag from "flag-icons/flags/4x3/cn.svg";
import deFlag from "flag-icons/flags/4x3/de.svg";
import esFlag from "flag-icons/flags/4x3/es.svg";
import frFlag from "flag-icons/flags/4x3/fr.svg";
import gbFlag from "flag-icons/flags/4x3/gb.svg";
import inFlag from "flag-icons/flags/4x3/in.svg";
import itFlag from "flag-icons/flags/4x3/it.svg";
import jpFlag from "flag-icons/flags/4x3/jp.svg";
import krFlag from "flag-icons/flags/4x3/kr.svg";
import mxFlag from "flag-icons/flags/4x3/mx.svg";
import nlFlag from "flag-icons/flags/4x3/nl.svg";
import ptFlag from "flag-icons/flags/4x3/pt.svg";
import ruFlag from "flag-icons/flags/4x3/ru.svg";
import saFlag from "flag-icons/flags/4x3/sa.svg";
import usFlag from "flag-icons/flags/4x3/us.svg";
import { resolveLanguage } from "./language-picker.jsx";

const flags = {
	SA: saFlag,
	CN: cnFlag,
	NL: nlFlag,
	US: usFlag,
	GB: gbFlag,
	FR: frFlag,
	CA: caFlag,
	DE: deFlag,
	IN: inFlag,
	IT: itFlag,
	JP: jpFlag,
	KR: krFlag,
	BR: brFlag,
	PT: ptFlag,
	RU: ruFlag,
	ES: esFlag,
	MX: mxFlag,
};

export function LanguageFlag({ language }) {
	const region = resolveLanguage(language)[0].split("-")[1]?.toUpperCase();
	const source = flags[region];

	return source ? (
		<img className="language-flag" src={source} alt="" width={20} height={15} />
	) : null;
}
