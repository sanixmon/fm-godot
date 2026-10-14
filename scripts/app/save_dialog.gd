# Modal save/load dialog over named slots (manual, slot1..3).
class_name SaveDialog
extends PopupPanel

var mode: String = "save"
var on_done: Callable = Callable()


static func show_dialog(parent: Node, p_mode: String, p_on_done: Callable = Callable()) -> SaveDialog:
	var d := SaveDialog.new()
	d.mode = p_mode
	d.on_done = p_on_done
	parent.add_child(d)
	d._rebuild()
	d.popup_centered(Vector2(560, 420))
	return d


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.add_child(FMUI.title("LOAD CAREER" if mode == "load" else "SAVE CAREER"))
	var slots: Array = SaveGame.get_all_slots_metadata()
	if slots.is_empty():
		root.add_child(FMUI.row("No save slots found."))
	for meta in slots:
		var line := HBoxContainer.new()
		root.add_child(line)
		var name_l := Label.new()
		name_l.custom_minimum_size = Vector2(90, 0)
		name_l.text = str(meta.slot).capitalize()
		line.add_child(name_l)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if meta.exists:
			info.text = "%s — %s (%s)" % [meta.club_name, meta.manager_name, meta.in_game_date]
		else:
			info.text = "[empty]"
		info.add_theme_font_size_override("font_size", 12)
		line.add_child(info)
		var go := FMUI.button("LOAD" if mode == "load" else "SAVE")
		go.disabled = mode == "load" and not meta.exists
		go.pressed.connect(_on_slot.bind(str(meta.slot)))
		line.add_child(go)
	var close_b := FMUI.button("Close")
	close_b.pressed.connect(hide)
	root.add_child(close_b)


func _on_slot(slot: String) -> void:
	if mode == "load":
		AppState.load_career(slot)
	else:
		AppState.save_career(slot)
	hide()
	if on_done.is_valid():
		on_done.call()
