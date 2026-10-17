extends Control
## Playful "Klanggarten" lettering for key art: each letter in a garden colour,
## slightly tilted and bouncing, with a thick ink outline and a soft drop shadow.

const COLORS := [Color("ff7a6b"), Color("ffc93c"), Color("7cc86a"), Color("4cc3b5"), Color("6fa8e8"), Color("9b6bd6"), Color("ff8fb8")]
const INK := Color("2f2a4a")

var text := "Klanggarten"
var size_px := 120
var font: Font


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Arial Rounded MT Bold", "Chalkboard SE", "Comic Sans MS", "Arial"])
	sf.font_weight = 800
	font = sf
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var widths := []
	var total := 0.0
	for ch in text:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.96
		widths.append(w)
		total += w
	var x := (size.x - total) / 2.0
	var base := size_px * 0.95
	for i in text.length():
		var ch := text[i]
		var tilt := sin(i * 1.7) * 0.07
		var y := base + sin(i * 0.9) * size_px * 0.05
		var pos := Vector2(x, y)
		draw_set_transform(pos + Vector2(widths[i] / 2.0, -size_px * 0.35), tilt, Vector2.ONE)
		var o := Vector2(-widths[i] / 2.0, size_px * 0.35)
		draw_string_outline(font, o + Vector2(0, size_px * 0.06), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(size_px * 0.28), Color(0, 0, 0, 0.25))
		draw_string_outline(font, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(size_px * 0.24), Color.WHITE)
		draw_string_outline(font, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(size_px * 0.12), INK)
		draw_string(font, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, COLORS[i % COLORS.size()])
		draw_string(font, o + Vector2(-size_px * 0.03, -size_px * 0.04), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1, 1, 1, 0.25))
		x += widths[i]
	draw_set_transform(Vector2.ZERO)
