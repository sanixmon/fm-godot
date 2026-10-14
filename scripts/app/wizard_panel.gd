# New-career wizard: manager details + club choice (from the bundled mod data).
class_name WizardPanel
extends VBoxContainer

var on_navigate: Callable = Callable()
var _name_edit: LineEdit = null
var _nat_edit: LineEdit = null
var _clubs_box: VBoxContainer = null
var _club_buttons: Array = []
var _club_ids: Array = []


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var data: Game = ModLoader.load_from_file("res://data/laliga.json")
	var league: League = null
	for comp in data.competitions.values():
		if comp is League:
			league = comp
			break
	add_child(FMUI.title("CREATE NEW CAREER"))
	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", 16)
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(form)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(left)
	left.add_child(FMUI.header("1. MANAGER PROFILE"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Manager name"
	_name_edit.text = "Coach Alex"
	left.add_child(_name_edit)
	_nat_edit = LineEdit.new()
	_nat_edit.placeholder_text = "Nationality code (e.g. ID)"
	_nat_edit.text = "ID"
	left.add_child(_nat_edit)
	left.add_child(FMUI.spacer(12))
	var start := FMUI.button("START CAREER")
	start.pressed.connect(_on_start)
	left.add_child(start)
	var back := FMUI.button("Back")
	back.pressed.connect(func() -> void: on_navigate.call("menu"))
	left.add_child(back)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(right)
	right.add_child(FMUI.header("2. CHOOSE YOUR CLUB"))
	_clubs_box = VBoxContainer.new()
	_clubs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(FMUI.scroll_wrap(_clubs_box))
	AppState.wizard_club_id = int(league.club_ids[0])
	_club_buttons.clear()
	_club_ids.clear()
	for cid in league.club_ids:
		var club: Club = data.clubs[int(cid)]
		_club_ids.append(int(cid))
		var b := FMUI.button("%s   (budget %d)" % [club.name, club.finance.transfer_budget])
		b.toggle_mode = true
		b.button_pressed = int(cid) == AppState.wizard_club_id
		b.toggled.connect(_on_club.bind(int(cid)))
		_club_buttons.append(b)
		_clubs_box.add_child(b)


func _on_club(pressed: bool, club_id: int) -> void:
	if not pressed:
		return
	AppState.wizard_club_id = club_id
	for i in _club_buttons.size():
		(_club_buttons[i] as Button).set_pressed_no_signal(int(_club_ids[i]) == club_id)


func _on_start() -> void:
	var nm: String = _name_edit.text.strip_edges()
	if nm.is_empty():
		nm = "Coach Alex"
	AppState.start_new_career(nm, _nat_edit.text.strip_edges().to_upper(), AppState.wizard_club_id)
	on_navigate.call("dashboard")
