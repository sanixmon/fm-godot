# Tactics: formation + 4 axes + pitch + bench swap + auto XI.
class_name TacticsPanel
extends VBoxContainer

var on_navigate: Callable = Callable()
var _pitch: PitchView = null


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var team: Team = AppState.human_team()
	var t: Tactics = team.tactics
	if not AppState.validation_error.is_empty():
		add_child(FMUI.row(AppState.validation_error, Color("#EF4444")))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(150, 0)
	cols.add_child(left)
	left.add_child(FMUI.header("SHAPE"))
	for f in Formation.Kind.values():
		var b := FMUI.button(Formation.LABELS[f])
		b.toggle_mode = true
		b.button_pressed = t.formation == f
		b.toggled.connect(_on_formation.bind(int(f)))
		left.add_child(b)
	var auto := FMUI.button("AUTO XI")
	auto.pressed.connect(func() -> void: AppState.auto_xi())
	left.add_child(auto)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	_pitch = PitchView.new()
	_pitch.custom_minimum_size = Vector2(420, 320)
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pitch.picked.connect(_on_starter)
	mid.add_child(_pitch)
	mid.add_child(FMUI.row("Tap a starter, then a bench player, to swap." if AppState.selected_starter_id < 0 else "Starter selected — tap a bench player."))
	_add_bench(mid, team)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(220, 0)
	cols.add_child(right)
	right.add_child(FMUI.header("TACTICS"))
	_add_axis(right, "MENTALITY", Mentality.LABELS, t.mentality, func(k: int) -> void: AppState.set_mentality(k))
	_add_axis(right, "TEMPO", Tempo.LABELS, t.tempo, func(k: int) -> void: AppState.set_tempo(k))
	_add_axis(right, "PRESSING", Pressing.LABELS, t.pressing, func(k: int) -> void: AppState.set_pressing(k))
	_add_axis(right, "PASSING", Passing.LABELS, t.passing, func(k: int) -> void: AppState.set_passing(k))
	right.add_child(FMUI.row("ATK %d   DEF %d" % [team.effective_attack(), team.effective_defense()], Color.WHITE))
	_pitch.refresh(team.starters, Formation.SLOTS[t.formation].duplicate(), AppState.selected_starter_id)


func _add_axis(parent: VBoxContainer, title: String, labels: Dictionary, current: int, apply: Callable) -> void:
	parent.add_child(FMUI.row(title))
	var line := HBoxContainer.new()
	parent.add_child(line)
	for k in labels:
		var b := FMUI.button(str(labels[k]))
		b.toggle_mode = true
		b.button_pressed = int(k) == current
		b.toggled.connect(_on_axis.bind(apply, int(k)))
		line.add_child(b)


func _on_axis(pressed: bool, apply: Callable, kind: int) -> void:
	if pressed:
		apply.call(kind)


func _on_formation(pressed: bool, kind: int) -> void:
	if pressed:
		AppState.set_formation(kind)


func _on_starter(player_id: int) -> void:
	AppState.selected_starter_id = player_id
	AppState.validation_error = ""
	refresh()


func _add_bench(mid: VBoxContainer, team: Team) -> void:
	var line := HBoxContainer.new()
	mid.add_child(line)
	line.add_child(FMUI.row("BENCH: "))
	for p in team.substitutes:
		var b := FMUI.button("%s %s" % [Position.to_string_value(p.best_position()), p.name.left(10)])
		b.pressed.connect(_on_bench.bind(int(p.id)))
		line.add_child(b)


func _on_bench(bench_id: int) -> void:
	if AppState.selected_starter_id >= 0:
		if not AppState.swap_starter_bench(AppState.selected_starter_id, bench_id):
			refresh()
