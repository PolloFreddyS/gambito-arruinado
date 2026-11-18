class_name FX
extends Node2D
## Efectos: temblor de pantalla, congelado de impacto, explosiones,
## textos de cómic (¡BOOM!), polvo y confeti.

var shake_root: Control
var trauma := 0.0
var base_pos := Vector2.ZERO


func _ready() -> void:
	z_index = 100
	if shake_root:
		base_pos = shake_root.position


func _process(delta: float) -> void:
	if shake_root == null:
		return
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 1.7)
		var s := trauma * trauma
		shake_root.position = base_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 44.0 * s
		shake_root.rotation = randf_range(-1, 1) * 0.04 * s
	else:
		shake_root.position = base_pos
		shake_root.rotation = 0.0


func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func hitstop(dur: float) -> void:
	Engine.time_scale = 0.03
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = Run.speed


## Texto de cómic con estrella de picos detrás.
func burst(pos: Vector2, text: String, fill: Color = UI.GOLD, size: int = 48, star: bool = true, text_color: Color = UI.RED, life: float = 0.55) -> void:
	var b := Burst.new()
	b.text = text
	b.fill = fill
	b.fs = size
	b.star = star
	b.text_color = text_color if star else fill
	b.position = pos
	b.rotation = randf_range(-0.22, 0.22)
	b.scale = Vector2.ZERO
	add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.55, 1.55), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(life)
	tw.tween_property(b, "position", pos + Vector2(0, -60), 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(b, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(b, "scale", Vector2(0.6, 0.6), 0.35)
	tw.tween_callback(b.queue_free)


func explode(pos: Vector2, power: float = 1.0, colors: Array = [UI.GOLD, UI.ORANGE, UI.RED]) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(26 + 34 * power)
	p.lifetime = 0.9
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 240.0 * power
	p.initial_velocity_max = 620.0 * power
	p.gravity = Vector2(0, 1100)
	p.damping_min = 30.0
	p.damping_max = 90.0
	p.scale_amount_min = 7.0
	p.scale_amount_max = 15.0 + 6.0 * power
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([colors[0], colors[1], Color(colors[2], 0.0)])
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)
	var b := Blast.new()
	b.position = pos
	b.power = power
	b.core = colors[0]
	b.outer = colors[1]
	add_child(b)
	# humo
	for i in int(3 + power * 3):
		var s := Puff.new()
		s.position = pos + Vector2(randf_range(-30, 30), randf_range(-20, 20)) * power
		s.vel = Vector2(randf_range(-80, 80), randf_range(-160, -40))
		s.r0 = randf_range(14, 26) * power
		add_child(s)


func dust(pos: Vector2, power: float = 1.0) -> void:
	for i in 6:
		var s := Puff.new()
		var dir := -1.0 if i < 3 else 1.0
		s.position = pos + Vector2(dir * 20.0, 0)
		s.vel = Vector2(dir * randf_range(80, 170) * power, randf_range(-50, -10))
		s.r0 = randf_range(7, 13) * power
		s.col = Color(1, 0.95, 0.85, 0.85)
		s.life = 0.45
		add_child(s)


func ring(pos: Vector2, color: Color, radius: float) -> void:
	var r := Ring.new()
	r.position = pos
	r.col = color
	r.max_r = radius
	add_child(r)


func confetti(area: Rect2, amount: int = 140) -> void:
	var p := CPUParticles2D.new()
	p.position = area.position + Vector2(area.size.x * 0.5, 0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.size.x * 0.5, 10)
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = 2.6
	p.direction = Vector2(0, 1)
	p.spread = 30.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 260)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 12.0
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([UI.GOLD, UI.PINK, UI.GREEN, UI.BLUE, UI.ORANGE])
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(3.5).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ nodos

class Burst extends Node2D:
	var text := ""
	var fill := Color.YELLOW
	var text_color := Color.RED
	var fs := 48
	var star := true
	var pts := PackedVector2Array()
	var t := 0.0

	func _ready() -> void:
		var f := UI.font()
		var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var rx := sz.x * 0.5 + fs * 0.75
		var ry := fs * 1.25
		var n := 14
		for i in n * 2:
			var a := TAU * i / (n * 2)
			var r := 1.0 if i % 2 == 0 else 0.7
			r *= randf_range(0.88, 1.12)
			pts.append(Vector2(cos(a) * rx * r, sin(a) * ry * r))

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var f := UI.font()
		if star:
			var sh := PackedVector2Array()
			for p in pts:
				sh.append(p + Vector2(7, 9))
			draw_colored_polygon(sh, UI.DARK)
			draw_colored_polygon(pts, fill)
			var c := pts.duplicate()
			c.append(pts[0])
			draw_polyline(c, UI.DARK, 5.0, true)
		var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var o := Vector2(-sz.x / 2.0, fs * 0.36) + Vector2(0, sin(t * 28.0) * 2.0)
		var dark_text := text_color.get_luminance() < 0.25
		var outline := UI.CREAM if dark_text else UI.DARK
		if not dark_text:
			draw_string_outline(f, o + Vector2(4, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(8, fs / 4), UI.DARK)
		draw_string_outline(f, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(8, fs / 4), outline)
		draw_string(f, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)


class Blast extends Node2D:
	var power := 1.0
	var core := Color.YELLOW
	var outer := Color.ORANGE
	var t := 0.0
	const DUR := 0.42

	func _process(d: float) -> void:
		t += d
		if t > DUR:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t / DUR
		var r := (40.0 + 120.0 * power) * ease(k, 0.25)
		var a := 1.0 - k
		draw_circle(Vector2.ZERO, r, Color(outer, a * 0.9))
		draw_circle(Vector2.ZERO, r * 0.62, Color(Color("#fff6e0"), a))
		draw_arc(Vector2.ZERO, r * 1.08, 0.0, TAU, 48, Color(UI.DARK, a), 6.0, true)
		for i in 12:
			var ang := TAU * i / 12.0 + 0.26
			var dv := Vector2(cos(ang), sin(ang))
			draw_line(dv * r * 1.25, dv * r * (1.65 + 0.45 * power), Color(core, a), 7.0, true)


class Puff extends Node2D:
	var vel := Vector2.ZERO
	var r0 := 18.0
	var col := Color(0.35, 0.3, 0.42, 0.85)
	var life := 0.8
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		position += vel * d
		vel *= 0.92
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t / life
		var r := r0 * (1.0 + k * 1.2)
		draw_circle(Vector2.ZERO, r + 3.0, Color(UI.DARK, col.a * (1.0 - k)))
		draw_circle(Vector2.ZERO, r, Color(col, col.a * (1.0 - k)))


class Ring extends Node2D:
	var col := Color.WHITE
	var max_r := 80.0
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		if t > 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.5
		draw_arc(Vector2.ZERO, max_r * ease(k, 0.3), 0.0, TAU, 48, Color(col, 1.0 - k), 8.0 * (1.0 - k) + 1.0, true)
