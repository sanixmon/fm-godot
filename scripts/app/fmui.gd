# Tiny UI builders shared by all panels. Keeps one visual language without a
# .tscn graph or theme resource.
class_name FMUI
extends RefCounted


static func header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("#0EA5E9"))
	return l


static func title(text: String, size: int = 15) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	return l


static func row(text: String, color: Color = Color("#94A3B8")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	return b


static func chip(text: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", _chip_style(bg))
	b.add_theme_stylebox_override("hover", _chip_style(bg))
	b.add_theme_stylebox_override("pressed", _chip_style(bg))
	b.add_theme_color_override("font_color", Color.BLACK if bg.v > 0.6 else Color.WHITE)
	b.add_theme_font_size_override("font_size", 11)
	return b


static func _chip_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(10)
	s.content_margin_left = 8
	s.content_margin_right = 8
	return s


static func form_badge(won: bool, drawn: bool) -> Button:
	if won:
		return chip("W", Color("#10B981"))
	if drawn:
		return chip("D", Color("#F59E0B"))
	return chip("L", Color("#EF4444"))


static func status_dot(ok: bool) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color("#10B981") if ok else Color("#EF4444")
	c.custom_minimum_size = Vector2(8, 8)
	return c


static func spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func scroll_wrap(child: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sc
