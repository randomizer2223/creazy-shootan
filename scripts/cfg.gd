extends Node
## Глобальні налаштування гри (autoload "Cfg").

const RELOAD_MODES := [
	{"name": "Normal", "mult": 0.3},
	{"name": "Fast", "mult": 0.15},
	{"name": "Almost instant", "mult": 0.05},
]

const DIFFICULTIES := [
	{"name": "Easy", "aim_error": 0.22, "reaction": 0.9},
	{"name": "Normal", "aim_error": 0.10, "reaction": 0.5},
	{"name": "Hard", "aim_error": 0.035, "reaction": 0.2},
]

var reload_mode := 1  # Fast by default
var bot_count := 3
var bot_difficulty := 1
var map_index := 0
var kill_limit := 10
var ui_theme: Theme
var custom_map: Image = null  # картинка, яку завантажив гравець


const INK := Color(0.23, 0.14, 0.13)
const CREAM := Color(1.0, 0.96, 0.86)
const PINK := Color(1.0, 0.45, 0.6)


static func round_box(bg: Color, border := INK, bw := 4, radius := 16, shadow := 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_offset = Vector2(0, shadow)
	sb.shadow_size = 1 if shadow > 0 else 0
	sb.anti_aliasing = true
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _ready() -> void:
	randomize()
	map_index = randi() % MapGen.PRESETS.size()  # a random map on every launch
	var theme := Theme.new()
	theme.default_font_size = 20
	# chunky cartoon buttons
	theme.set_stylebox("normal", "Button", round_box(Color(1.0, 0.85, 0.45)))
	theme.set_stylebox("hover", "Button", round_box(Color(1.0, 0.9, 0.6)))
	theme.set_stylebox("pressed", "Button", round_box(Color(0.95, 0.72, 0.3), INK, 4, 16, 1))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(c, "Button", INK)
	theme.set_stylebox("panel", "PanelContainer", round_box(CREAM, INK, 5, 22, 8))
	theme.set_color("font_color", "Label", INK)
	get_tree().root.theme = theme
	ui_theme = theme


func reload_mult() -> float:
	return RELOAD_MODES[clampi(reload_mode, 0, RELOAD_MODES.size() - 1)]["mult"]
