"""Small native controls shared by the mobile screens."""
import from "@jac/mobui" { Pressable, Text }
import from .theme { styles }

def:pub ActionButton(label: str, onPress: Callable[[], None], disabled: bool = False,
                     variant: str = "primary") -> JsxElement {
    secondary = variant == "secondary";
    <Pressable accessibilityRole="button" accessibilityState={{"disabled": disabled}}
        disabled={disabled} onPress={lambda { onPress(); }}
        style={[styles.button, styles.buttonSecondary if secondary else {},
            styles.buttonDanger if variant == "danger" else {},
            styles.buttonDisabled if disabled else {}]}>
        <Text style={[styles.buttonLabel, styles.buttonLabelSecondary if secondary else {}]}>{label}</Text>
    </Pressable>
}

"""One option of a single-choice group."""
def:pub Chip(label: str, selected: bool, onPress: Callable[[], None],
             disabled: bool = False) -> JsxElement {
    <Pressable accessibilityRole="radio"
        accessibilityState={{"checked": selected, "disabled": disabled}}
        disabled={disabled} onPress={lambda { onPress(); }}
        style={[styles.chip, styles.chipSelected if selected else {},
            styles.buttonDisabled if disabled else {}]}>
        <Text style={[styles.chipLabel, styles.chipLabelSelected if selected else {}]}>{label}</Text>
    </Pressable>
}
