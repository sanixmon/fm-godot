# Squad management: sortable/filterable table + persistent inspector with
# attributes, contract, status and training controls.
class_name SquadPanel
extends VBoxContainer

var _sort: String = "ovr"
var _filter: int = -1


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	add_child(FMUI.header("SQUAD"))
	_add_filter_row()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.stretch_ratio = 0.68
	cols.add_child(table)
	_add_table(table)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.stretch_ratio = 0.32
	cols.add_child(side)
	_add_inspector(side)


func _players() -> Array:
	var squad: Array = AppState.human_squad()
	if _filter >= 0:
		squad = squad.filter(func(p) -> bool: return Position.group_of(p.best_position()) == _filter)
	squad.sort_custom(func(a, b) -> bool: return _key(a) > _key(b))
	return squad


func _key(p) -> float:
	match _sort:
		"age":
			return 100.0 - float(p.age)
		"fitness":
			return float(p.fitness)
		"name":
			return 0.0
		_:
			return float(p.best_overall())
	return 0.0


func _add_filter_row() -> void:
	var line := HBoxContainer.new()
	add_child(line)
	for opt in [["ALL", -1], ["GK", 0], ["DEF", 1], ["MID", 2], ["ATT", 3]]:
		var b := FMUI.button(str(opt[0]))
		b.toggle_mode = true
		b.button_pressed = _filter == int(opt[1])
		b.toggled.connect(_on_filter.bind(int(opt[1])))
		line.add_child(b)
	for opt in [["OVR", "ovr"], ["AGE", "age"], ["FIT", "fitness"]]:
		var b := FMUI.button(str(opt[0]))
		b.toggle_mode = true
		b.button_pressed = _sort == str(opt[1])
		b.toggled.connect(_on_sort.bind(str(opt[1])))
		line.add_child(b)


func _on_filter(pressed: bool, group: int) -> void:
	if pressed:
		_filter = group
		refresh()


func _on_sort(pressed: bool, key: String) -> void:
	if pressed:
		_sort = key
		refresh()


func _add_table(table: VBoxContainer) -> void:
	var lineup = AppState.human_lineup()
	var xi: Array = lineup.starters if lineup != null else []
	var head := Label.new()
	head.text = "POS  PLAYER              OVR  FIT  STATUS"
	head.add_theme_font_size_override("font_size", 11)
	table.add_child(head)
	var list := VBoxContainer.new()
	table.add_child(FMUI.scroll_wrap(list))
	for p in _players():
		var tag := ""
		if int(p.id) in xi:
			tag = " [XI]"
		elif not p.is_available():
			tag = " [OUT]"
		var b := FMUI.button("%-4s %-18s %3d  %3d%% %s" % [
			Position.to_string_value(p.best_position()), p.name.left(18),
			p.best_overall(), p.fitness, tag
		])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_pick.bind(int(p.id)))
		list.add_child(b)


func _on_pick(player_id: int) -> void:
	AppState.selected_player_id = player_id
	refresh()


func _add_inspector(side: VBoxContainer) -> void:
	var squad: Array = AppState.human_squad()
	var player = null
	for p in squad:
		if int(p.id) == AppState.selected_player_id:
			player = p
	if player == null:
		side.add_child(FMUI.row("Select a player from the table."))
		return
	side.add_child(FMUI.title("%s  (%d)" % [player.name, player.best_overall()]))
	side.add_child(FMUI.row("%s • %d yrs • %s" % [
		player.nationality, player.age, Position.to_string_value(player.best_position())
	]))
	side.add_child(FMUI.header("ATTRIBUTES"))
	for a in Attribute.Kind.values():
		side.add_child(FMUI.row("%-10s %3d" % [Attribute.to_string_value(a).capitalize(), player.attributes.attr_value(a)]))
	side.add_child(FMUI.header("CONTRACT"))
	side.add_child(FMUI.row("Wage %d/w • until %s" % [player.contract.weekly_wage, player.contract.expires_on]))
	side.add_child(FMUI.header("TRAINING"))
	var focuses := HBoxContainer.new()
	side.add_child(focuses)
	for f in TrainingFocus.Kind.values():
		var b := FMUI.button(TrainingFocus.to_string_value(f).left(3))
		b.toggle_mode = true
		b.button_pressed = player.training_focus == f
		b.toggled.connect(_on_focus.bind(int(player.id), int(f)))
		focuses.add_child(b)
	var intensities := HBoxContainer.new()
	side.add_child(intensities)
	for it in TrainingIntensity.Kind.values():
		var b := FMUI.button(TrainingIntensity.to_string_value(it).capitalize())
		b.toggle_mode = true
		b.button_pressed = player.training_intensity == it
		b.toggled.connect(_on_intensity.bind(int(player.id), player.training_focus, int(it)))
		intensities.add_child(b)


func _on_focus(pressed: bool, player_id: int, focus: int) -> void:
	if pressed:
		AppState.set_player_training(player_id, focus, TrainingIntensity.Kind.NORMAL)
		refresh()


func _on_intensity(pressed: bool, player_id: int, focus: int, intensity: int) -> void:
	if pressed:
		AppState.set_player_training(player_id, focus, intensity)
		refresh()
