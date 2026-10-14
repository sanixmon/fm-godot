# Root UI shell: landscape rail + top bar + section content.
# Menu-first boot (no auto career). All panels rebuild on refresh.
extends Control

const SECTIONS: Array = ["dashboard", "squad", "tactics", "match", "league", "transfers"]

var _content: VBoxContainer = null
var _date_label: Label = null
var _club_label: Label = null
var _continue_btn: Button = null
var _status_label: Label = null
var _rail: VBoxContainer = null


func _ready() -> void:
	var shell := HBoxContainer.new()
	shell.add_theme_constant_override("separation", 0)
	add_child(shell)
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_rail(shell)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(right)
	_build_topbar(right)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_content)
	AppState.career_changed.connect(refresh)
	AppState.nav_changed.connect(refresh)
	AppState.status_changed.connect(_on_status)
	if not AppState.has_career():
		AppState.active_section = "menu"
	refresh()


func _build_rail(shell: HBoxContainer) -> void:
	_rail = VBoxContainer.new()
	_rail.custom_minimum_size = Vector2(104, 0)
	shell.add_child(_rail)
	for s in SECTIONS:
		var b := Button.new()
		b.text = s.capitalize()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(104, 44)
		b.pressed.connect(_on_nav.bind(s))
		_rail.add_child(b)


func _build_topbar(right: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 42)
	right.add_child(bar)
	var menu_b := Button.new()
	menu_b.text = "Menu"
	menu_b.pressed.connect(_on_nav.bind("menu"))
	bar.add_child(menu_b)
	_club_label = Label.new()
	bar.add_child(_club_label)
	_date_label = Label.new()
	bar.add_child(_date_label)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status_label)
	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(190, 36)
	_continue_btn.pressed.connect(_on_continue)
	bar.add_child(_continue_btn)


func _on_nav(section: String) -> void:
	AppState.goto_section(section)


func _on_continue() -> void:
	AppState.advance()


func _on_status(message: String) -> void:
	_status_label.text = message


func refresh() -> void:
	var section: String = AppState.active_section
	if not AppState.has_career() and section != "menu" and section != "wizard":
		section = "menu"
		AppState.active_section = section
	for i in _rail.get_child_count():
		(_rail.get_child(i) as Button).set_pressed_no_signal(SECTIONS[i] == section)
	if AppState.has_career():
		var club: Club = AppState.human_club()
		var season: SeasonState = AppState.season()
		_club_label.text = club.name
		_date_label.text = season.current_date
		_continue_btn.visible = section != "menu" and section != "wizard"
		_continue_btn.text = _continue_label(season)
	else:
		_club_label.text = "No career"
		_date_label.text = ""
		_continue_btn.visible = false
	for c in _content.get_children():
		c.queue_free()
	match section:
		"menu":
			var p := MenuPanel.new()
			p.on_navigate = AppState.goto_section
			_content.add_child(p)
			p.refresh()
		"wizard":
			var p := WizardPanel.new()
			p.on_navigate = AppState.goto_section
			_content.add_child(p)
			p.refresh()
		"squad":
			_add_panel(SquadPanel.new())
		"tactics":
			_add_panel(TacticsPanel.new())
		"match":
			_add_match_panel()
		"league":
			_add_panel(LeaguePanel.new())
		"transfers":
			_add_panel(TransfersPanel.new())
		_:
			_add_dashboard()


func _add_panel(p: VBoxContainer) -> void:
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(p)
	p.refresh()


func _add_dashboard() -> void:
	if not AppState.has_career():
		_on_nav("menu")
		return
	var p := DashboardPanel.new()
	p.on_navigate = AppState.goto_section
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(p)
	p.refresh()


func _add_match_panel() -> void:
	if not AppState.has_career():
		_on_nav("menu")
		return
	var p := MatchPanel.new()
	p.on_navigate = AppState.goto_section
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(p)
	p.refresh()


func _continue_label(season: SeasonState) -> String:
	if season.is_finished:
		return "NEW SEASON"
	var fx = season.fixtures[season.next_fixture_index] if season.next_fixture_index < season.fixtures.size() else null
	if fx != null and fx.date <= season.current_date:
		return "PLAY MATCH"
	var days: int = FMDate.days_between(season.current_date, fx.date) if fx != null else 0
	if days > 0:
		return "CONTINUE (%dd)" % days
	return "CONTINUE"
