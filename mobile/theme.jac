"""Design tokens and the one StyleSheet for the native app."""
import from "@jac/mobui" { StyleSheet }

obj Colors {
    has bg: str = "#f7f7f5", surface: str = "#ffffff", text: str = "#1c1f24",
        muted: str = "#5d6470", border: str = "#d9dce1", accent: str = "#2f5bd3",
        onAccent: str = "#ffffff", danger: str = "#b3261e", partner: str = "#7a4cc2",
        learner: str = "#1f7a52";
}
obj Spacing { has xs: int = 4, sm: int = 8, md: int = 12, lg: int = 16, xl: int = 24; }
obj Radii { has sm: int = 8, md: int = 12, pill: int = 999; }
obj Fonts { has sm: int = 14, md: int = 16, lg: int = 20, xl: int = 26; }

glob:pub C = Colors(), S = Spacing(), R = Radii(), F = Fonts();

glob:pub styles = StyleSheet.create({
    "screen": {"flex": 1, "backgroundColor": C.bg},
    "body": {"padding": S.lg, "paddingTop": S.xl * 2, "gap": S.lg},
    "title": {"color": C.text, "fontSize": F.xl, "fontWeight": "bold"},
    "subtitle": {"color": C.muted, "fontSize": F.md},
    "heading": {"color": C.text, "fontSize": F.lg, "fontWeight": "bold"},
    "text": {"color": C.text, "fontSize": F.md, "lineHeight": 22},
    "muted": {"color": C.muted, "fontSize": F.sm, "lineHeight": 20},
    "error": {"color": C.danger, "fontSize": F.md},
    "card": {"backgroundColor": C.surface, "borderRadius": R.md, "borderWidth": 1,
        "borderColor": C.border, "padding": S.lg, "gap": S.md},
    "label": {"color": C.muted, "fontSize": F.sm, "fontWeight": "bold"},
    "input": {"borderWidth": 1, "borderColor": C.border, "borderRadius": R.sm,
        "paddingHorizontal": S.md, "paddingVertical": S.sm, "minHeight": 44,
        "color": C.text, "fontSize": F.md, "backgroundColor": C.surface},
    "row": {"flexDirection": "row", "flexWrap": "wrap", "gap": S.sm, "alignItems": "center"},
    "button": {"minHeight": 48, "borderRadius": R.sm, "paddingHorizontal": S.lg,
        "alignItems": "center", "justifyContent": "center", "backgroundColor": C.accent},
    "buttonSecondary": {"backgroundColor": C.surface, "borderWidth": 1, "borderColor": C.border},
    "buttonDanger": {"backgroundColor": C.danger},
    "buttonDisabled": {"opacity": 0.45},
    "buttonLabel": {"color": C.onAccent, "fontSize": F.md, "fontWeight": "bold"},
    "buttonLabelSecondary": {"color": C.text},
    "chip": {"minHeight": 40, "paddingHorizontal": S.md, "borderRadius": R.pill, "borderWidth": 1,
        "borderColor": C.border, "alignItems": "center", "justifyContent": "center",
        "backgroundColor": C.surface},
    "chipSelected": {"backgroundColor": C.accent, "borderColor": C.accent},
    "chipLabel": {"color": C.text, "fontSize": F.sm, "fontWeight": "bold"},
    "chipLabelSelected": {"color": C.onAccent},
    "turn": {"gap": S.xs, "paddingVertical": S.sm, "borderBottomWidth": 1, "borderBottomColor": C.border},
    "speakerPartner": {"color": C.partner, "fontSize": F.sm, "fontWeight": "bold"},
    "speakerLearner": {"color": C.learner, "fontSize": F.sm, "fontWeight": "bold"},
    "interim": {"color": C.muted, "fontSize": F.md, "fontStyle": "italic"},
    "switchRow": {"flexDirection": "row", "gap": S.md, "alignItems": "center"}
});
