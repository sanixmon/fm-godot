# Main menu: identity, career summary, Continue / New / Load.
class_name MenuPanel
extends VBoxContainer

var on_navigate: Callable = Callable()


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var mid := CenterContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(mid)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 10)
	mid.add_child(col)
	col.add_child(FMUI.title("FOOTBALL MANAGER", 26))
	col.add_child(FMUI.header("CLUB COMMAND EDITION"))
	if AppState.has_career():
		var club: Club = AppState.human_club()
		var season: SeasonState = AppState.season()
		col.add_child(FMUI.row("Career: %s  —  managed by %s" % [club.name, season.manager_profile.name if season.manager_profile != null else "—"], Color.WHITE))
		col.add_child(FMUI.row("Date: %s" % season.current_date))
		var cont := FMUI.button("CONTINUE CAREER")
		cont.pressed.connect(func() -> void: on_navigate.call("dashboard"))
		col.add_child(cont)
	else:
		col.add_child(FMUI.row("No active career. Start a new one below.", Color.WHITE))
	var new_b := FMUI.button("START NEW CAREER")
	new_b.pressed.connect(func() -> void: on_navigate.call("wizard"))
	col.add_child(new_b)
	var load_b := FMUI.button("LOAD SAVED CAREER")
	load_b.pressed.connect(func() -> void: SaveDialog.show_dialog(self, "load", on_navigate.bind("dashboard")))
	col.add_child(load_b)
