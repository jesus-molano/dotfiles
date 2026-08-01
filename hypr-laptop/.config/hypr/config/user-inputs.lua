-- Spanish keyboard layout for the Acer's physical keyboard.
-- Kanata only remaps Caps Lock; every other key keeps this layout.
TERMINAL = "ghostty"
FILE_MANAGER = "dolphin"
BROWSER = "brave"
EDITOR = "ghostty -e nvim"

hl.config({
    input = {
        kb_layout = "es",
    },
})
