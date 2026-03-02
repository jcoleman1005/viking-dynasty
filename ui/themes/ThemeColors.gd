# res://ui/themes/ThemeColors.gd
# Central token registry for the Dark Saga visual theme.
# All new UI scenes read colours from here — never hardcode hex values in scenes.
class_name ThemeColors
extends RefCounted

# --- Backgrounds ---
const BG_DARK    := Color("#1a1610")   # Full-screen backgrounds
const BG_PANEL   := Color("#211e17")   # Panel containers
const BG_CARD    := Color("#16140f")   # Card and row backgrounds

# --- Borders ---
const BORDER      := Color("#3d3828")   # Default borders
const BORDER_GOLD := Color("#7a6430")   # Hover / active borders

# --- Gold accents ---
const RENOWN   := Color("#d4a843")   # Primary gold accent, renown
const GOLD_DIM := Color("#7a6430")   # Dimmed gold, costs

# --- Text ---
const TEXT_PRIMARY   := Color("#e8dfc0")   # Body text
const TEXT_SECONDARY := Color("#9a9080")   # Labels, captions
const TEXT_DIM       := Color("#5a5548")   # Section headers, disabled

# --- Pillars ---
const MIGHT      := Color("#c47a50")   # Might pillar, combat
const PROSPERITY := Color("#7ab648")   # Prosperity pillar, food
const AUTHORITY  := Color("#88aadf")   # Authority pillar, winter

# --- Status ---
const DANGER  := Color("#c84040")   # Crises, deficits, broken oaths
const WARNING := Color("#e8a840")   # Partial states, cautions
