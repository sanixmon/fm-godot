# Tactical pitch: turf + markers positioned from Formation.SLOTS.
# Markers are real Buttons (tap starter, then bench, to swap).
class_name PitchView
extends Control

signal picked(player_id: int)

const SLOT_Y := {
	0: 0.88, # GK
	1: 0.70, # CB
	2: 0.68, # LB
	3: 0.68, # RB
	4: 0.55, # DM
	5: 0.47, # CM
	6: 0.33, # AM
	7: 0.26, # LW
	8: 0.26, # RW
	9: 0.12, # ST
}

var starters: Array = []
var slots: Array = []
var selected_id: int = -1


func refresh(p_starters: Array, p_slots: Array, p_selected: int) -> void:
	starters = p_starters
	slots = p_slots
	selected_id = p_selected
	for c in get_children():
		c.queue_free()
	var rows := {}
	for i in mini(starters.size(), slots.size()):
		var y: float = SLOT_Y.get(int(slots[i]), 0.5)
		if not rows.has(y):
			rows[y] = []
		rows[y].append(i)
	for y in rows:
		var idxs: Array = rows[y]
		for n in idxs.size():
			_place_marker(idxs[n], float(n + 1) / float(idxs.size() + 1), y)
	queue_redraw()


func _place_marker(i: int, x_frac: float, y_frac: float) -> void:
	var p = starters[i]
	var b := Button.new()
	b.text = "%s\n%d" % [Position.to_string_value(int(slots[i])), p.effective_overall(int(slots[i]))]
	b.custom_minimum_size = Vector2(64, 40)
	b.add_theme_font_size_override("font_size", 11)
	if int(p.id) == selected_id:
		b.modulate = Color("#10B981")
	var w: float = maxf(size.x, 64.0)
	var h: float = maxf(size.y, 40.0)
	b.position = Vector2(x_frac * w - 32.0, y_frac * h - 20.0)
	b.pressed.connect(func() -> void: picked.emit(int(p.id)))
	add_child(b)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	for i in 6:
		draw_rect(Rect2(0, h * i / 6.0, w, h / 6.0 + 1.0), Color("#0F3E22") if i % 2 == 0 else Color("#134E2B"))
	var line := Color(1, 1, 1, 0.35)
	draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), line, 2.0)
	draw_arc(Vector2(w * 0.5, h * 0.5), 34.0, 0.0, TAU, 32, line, 2.0)
	draw_rect(Rect2(w * 0.25, 0, w * 0.5, h * 0.18), line, false, 2.0)
	draw_rect(Rect2(w * 0.25, h * 0.82, w * 0.5, h * 0.18), line, false, 2.0)
