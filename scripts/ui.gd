class_name UI
extends RefCounted
## Paleta, fuente y constructores de controles con estilo caricatura.

const DARK := Color("#1a1028")
const CREAM := Color("#fff6e0")
const GOLD := Color("#ffd23f")
const RED := Color("#eb3b5a")
const BLUE := Color("#2f80ed")
const GREEN := Color("#3ddc97")
const PURPLE := Color("#3f2c5c")
const PURPLE2 := Color("#5b3f8a")
const PINK := Color("#ff5d73")
const ORANGE := Color("#ff9f1c")
const LILAC := Color("#c9b6ef")
const ICE := Color("#9fe3ff")
const BOSS := Color("#7a1f3d")

static var _font: Font


static func font() -> Font:
	if _font == null:
		if OS.has_feature("web"):
			# En el navegador no hay fuentes del sistema: engordamos la fuente incluida.
			var fv := FontVariation.new()
			fv.base_font = ThemeDB.fallback_font
			fv.variation_embolden = 1.1
			_font = fv
		else:
			var f := SystemFont.new()
			f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Impact", "Arial"])
			f.font_weight = 900
			_font = f
	return _font


static func label(text: String, size: int = 20, color: Color = CREAM, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", DARK)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, size: int, color: Color, width: float) -> Label:
	var l := label(text, size, color, 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func box(color: Color, radius: int = 16, border: int = 4, shadow: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = DARK
	if shadow > 0:
		s.shadow_color = DARK
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, shadow)
	s.set_content_margin_all(10)
	s.anti_aliasing = true
	return s


static func panel(color: Color, radius: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func button(text: String, color: Color = GOLD, size: int = 24, text_color: Color = DARK) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, text_color)
	b.add_theme_color_override("font_disabled_color", Color(text_color, 0.45))
	b.add_theme_stylebox_override("normal", box(color, 14))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.18), 14))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.12), 14, 4, 2))
	b.add_theme_stylebox_override("hover_pressed", box(color.darkened(0.12), 14, 4, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", box(color.darkened(0.45), 14))
	b.mouse_entered.connect(func():
		if b.disabled:
			return
		b.pivot_offset = b.size / 2.0
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(b, "rotation", randf_range(-0.05, 0.05), 0.12)
		Sfx.play("click", 1.5, -14.0))
	b.mouse_exited.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.15)
		tw.parallel().tween_property(b, "rotation", 0.0, 0.15))
	b.pressed.connect(func(): Sfx.play("pop", 1.0, -4.0))
	return b


## Rebote exagerado de un control (para "golpear" números y paneles).
static func punch(c: Control, amount: float = 0.35) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), 0.06)
	tw.parallel().tween_property(c, "rotation", randf_range(-0.12, 0.12), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h
