class_name PieceView
extends Node2D
## Pieza dibujada en código: cuerpo caricatura, ojos que siguen al ratón,
## caras (normal, asustada, feliz, muerta) y animaciones exageradas.

const OUT := Color("#1a1028")
const FACE_Y := {1: -62.0, 2: -70.0, 3: -50.0, 4: -48.0, 5: -48.0, 6: -50.0}

var t := 1
var side := 0
var ench := ""
var size := 80.0
var sx := 1.0
var sy := 1.0
var tilt := 0.0
var lift := 0.0
var spin := 0.0
var mood := "idle"
var happy_time := 0.0
var frozen := false
var idle_on := true
var phase := 0.0
var time := 0.0
var blink_in := 2.0
var look := Vector2.ZERO
var flash := 0.0


func _ready() -> void:
	phase = randf() * TAU
	blink_in = randf_range(0.5, 4.0)


func _process(delta: float) -> void:
	time += delta
	blink_in -= delta
	if blink_in < -0.13:
		blink_in = randf_range(2.0, 5.0)
	if happy_time > 0.0:
		happy_time -= delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
	var m := get_global_mouse_position() - (global_position + Vector2(0, -size * 0.6))
	look = m.normalized() * minf(1.0, m.length() / 120.0)
	queue_redraw()


func set_happy(d: float = 1.4) -> void:
	happy_time = d


func face() -> String:
	if mood == "dead":
		return "dead"
	if happy_time > 0.0:
		return "happy"
	return mood


func colors() -> Array:
	var fill: Color
	var shade: Color
	match ench:
		"oro":
			fill = Color("#ffd23f")
			shade = Color("#d89a00")
		"vidrio":
			fill = Color(0.75, 0.93, 1.0, 0.62)
			shade = Color(0.45, 0.72, 0.95, 0.7)
		"explosiva":
			fill = Color("#ff7a5c")
			shade = Color("#c43d2f")
		_:
			if side == 0:
				fill = Color("#fff3d6")
				shade = Color("#e8c48a")
			else:
				fill = Color("#7b4fc9")
				shade = Color("#4b2a7b")
	if frozen:
		fill = fill.lerp(Color("#bfe9ff"), 0.65)
		shade = shade.lerp(Color("#7cc8f0"), 0.65)
	if flash > 0.0:
		fill = fill.lerp(Color.WHITE, flash)
		shade = shade.lerp(Color.WHITE, flash)
	return [fill, shade]


func _draw() -> void:
	var u := size / 100.0
	var bob := sin(time * 3.4 + phase) if idle_on else 0.0
	var f := face()
	var jit := sin(time * 45.0) * 0.04 if f == "scared" else 0.0
	var shs := clampf(1.0 - lift / 500.0, 0.35, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(u * shs, u * shs))
	draw_colored_polygon(_ell(Vector2.ZERO, 36.0, 9.0), Color(0, 0, 0, 0.3))
	var fl := -1.0 if side == 1 else 1.0
	draw_set_transform(Vector2(0, -lift), tilt + jit + spin, Vector2(u * sx * (1.0 + bob * 0.03) * fl, u * sy * (1.0 - bob * 0.045)))
	var c := colors()
	_body(c[0], c[1])
	_face(f, fl)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ell(c: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _shape(pts: PackedVector2Array, c: Color) -> void:
	draw_colored_polygon(pts, c)
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, OUT, 5.0, true)


func _body(fill: Color, shade: Color) -> void:
	var gold := Color("#ffd23f")
	_shape(PackedVector2Array([Vector2(-34, -4), Vector2(-28, 0), Vector2(28, 0), Vector2(34, -4), Vector2(30, -16), Vector2(-30, -16)]), shade)
	var top := -80.0
	match t:
		Board.P:
			_shape(PackedVector2Array([Vector2(-20, -15), Vector2(20, -15), Vector2(9, -44), Vector2(-9, -44)]), fill)
			_shape(_ell(Vector2(0, -44), 17, 5), shade)
			_shape(_ell(Vector2(0, -62), 20, 20), fill)
			top = -82.0
		Board.R:
			_shape(PackedVector2Array([Vector2(-24, -15), Vector2(24, -15), Vector2(22, -66), Vector2(-22, -66)]), fill)
			_shape(PackedVector2Array([Vector2(-28, -66), Vector2(28, -66), Vector2(28, -88), Vector2(17, -88), Vector2(17, -79), Vector2(6, -79), Vector2(6, -88), Vector2(-6, -88), Vector2(-6, -79), Vector2(-17, -79), Vector2(-17, -88), Vector2(-28, -88)]), shade)
			top = -88.0
		Board.B:
			_shape(_ell(Vector2(0, -48), 22, 33), fill)
			_shape(_ell(Vector2(0, -86), 8, 8), shade)
			draw_line(Vector2(8, -76), Vector2(16, -60), OUT, 4.5, true)
			top = -94.0
		Board.N:
			_shape(PackedVector2Array([Vector2(-24, -15), Vector2(26, -15), Vector2(22, -34), Vector2(30, -56), Vector2(24, -80), Vector2(8, -94), Vector2(-6, -92), Vector2(-22, -84), Vector2(-36, -66), Vector2(-36, -54), Vector2(-24, -50), Vector2(-10, -54), Vector2(-6, -46), Vector2(-20, -30)]), fill)
			_shape(PackedVector2Array([Vector2(4, -92), Vector2(10, -108), Vector2(17, -88)]), fill)
			draw_polyline(PackedVector2Array([Vector2(10, -93), Vector2(24, -80), Vector2(30, -58), Vector2(24, -36)]), Color("#eb3b5a"), 9.0, true)
			draw_circle(Vector2(-30, -60), 2.5, OUT)
			top = -108.0
		Board.Q:
			_shape(PackedVector2Array([Vector2(-20, -15), Vector2(20, -15), Vector2(27, -68), Vector2(-27, -68)]), fill)
			_shape(PackedVector2Array([Vector2(-30, -68), Vector2(30, -68), Vector2(38, -96), Vector2(20, -80), Vector2(10, -102), Vector2(0, -82), Vector2(-10, -102), Vector2(-20, -80), Vector2(-38, -96)]), gold)
			for p in [Vector2(-38, -96), Vector2(-10, -102), Vector2(10, -102), Vector2(38, -96)]:
				draw_circle(p, 5.0, OUT)
				draw_circle(p, 3.2, Color("#ff5d73"))
			top = -106.0
		Board.K:
			_shape(PackedVector2Array([Vector2(-22, -15), Vector2(22, -15), Vector2(26, -72), Vector2(-26, -72)]), fill)
			_shape(PackedVector2Array([Vector2(-30, -72), Vector2(30, -72), Vector2(28, -90), Vector2(-28, -90)]), gold)
			_shape(PackedVector2Array([Vector2(-5, -90), Vector2(5, -90), Vector2(5, -100), Vector2(14, -100), Vector2(14, -109), Vector2(5, -109), Vector2(5, -118), Vector2(-5, -118), Vector2(-5, -109), Vector2(-14, -109), Vector2(-14, -100), Vector2(-5, -100)]), gold)
			top = -118.0
	# brillo
	draw_circle(Vector2(-12, FACE_Y[t] + 22.0), 4.0, Color(1, 1, 1, 0.35))
	if ench == "vidrio":
		draw_line(Vector2(-14, -30), Vector2(-4, -44), Color(1, 1, 1, 0.9), 3.0, true)
		draw_line(Vector2(-8, -22), Vector2(0, -32), Color(1, 1, 1, 0.9), 3.0, true)
	if ench == "explosiva":
		draw_polyline(PackedVector2Array([Vector2(0, top), Vector2(7, top - 9), Vector2(2, top - 18)]), OUT, 4.0, true)
		var fl := 4.0 + sin(time * 30.0) * 2.0
		draw_circle(Vector2(2, top - 20), fl + 2.0, Color("#ff9f1c"))
		draw_circle(Vector2(2, top - 20), fl * 0.5, Color("#fff6e0"))
	if ench == "oro":
		var sp := fmod(time * 0.8 + phase, 1.0)
		var sc := sin(sp * PI) * 6.0
		var p0 := Vector2(18, top + 20)
		draw_line(p0 + Vector2(-sc, 0), p0 + Vector2(sc, 0), Color.WHITE, 2.5)
		draw_line(p0 + Vector2(0, -sc), p0 + Vector2(0, sc), Color.WHITE, 2.5)


func _face(f: String, fl: float) -> void:
	var ey: float = FACE_Y[t]
	var cx := -8.0 if t == Board.N else 0.0
	var lk := Vector2(look.x * fl, look.y) * 3.5
	for s in [-1.0, 1.0]:
		var c := Vector2(cx + s * 11.0, ey)
		match f:
			"dead":
				draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), OUT, 3.5, true)
				draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), OUT, 3.5, true)
			"happy":
				draw_arc(c + Vector2(0, 3), 6.0, PI * 1.1, PI * 1.9, 10, OUT, 3.5, true)
			_:
				if blink_in < 0.0:
					draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), OUT, 3.5, true)
				else:
					var r := 9.5 if f == "scared" else 7.5
					draw_circle(c, r + 2.2, OUT)
					draw_circle(c, r, Color.WHITE)
					var pr := 2.3 if f == "scared" else 3.8
					draw_circle(c + lk.limit_length(r - pr - 1.0), pr, OUT)
		if side == 1 and f != "dead" and f != "happy":
			draw_line(c + Vector2(9.0 * s, -15), c + Vector2(-4.0 * s, -10), OUT, 4.0, true)
	var mc := Vector2(cx, ey + 13.0)
	match f:
		"dead":
			draw_polyline(PackedVector2Array([mc + Vector2(-7, 0), mc + Vector2(-3, -3), mc + Vector2(1, 0), mc + Vector2(5, -3), mc + Vector2(8, 0)]), OUT, 3.0, true)
		"scared":
			draw_circle(mc + Vector2(0, 1), 4.5, OUT)
			var d := Vector2(cx + 22.0, ey - 12.0 + fmod(time * 30.0, 8.0))
			draw_colored_polygon(PackedVector2Array([d + Vector2(0, -7), d + Vector2(4, 0), d + Vector2(-4, 0)]), Color("#7cc8f0"))
			draw_circle(d, 4.0, Color("#7cc8f0"))
		"happy":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				pts.append(mc + Vector2(cos(a) * 10.0, sin(a) * 9.0 - 3.0))
			draw_colored_polygon(pts, OUT)
			draw_circle(mc + Vector2(0, 3), 4.0, Color("#ff5d73"))
		_:
			if side == 1:
				draw_arc(mc + Vector2(0, 6), 6.0, PI * 1.15, PI * 1.85, 10, OUT, 3.5, true)
			else:
				draw_arc(mc + Vector2(0, -4), 6.0, PI * 0.15, PI * 0.85, 10, OUT, 3.5, true)
	if t == Board.K:
		draw_arc(Vector2(cx - 7, ey + 9), 7.0, PI * 1.0, PI * 1.85, 10, OUT, 4.5, true)
		draw_arc(Vector2(cx + 7, ey + 9), 7.0, PI * 1.15, PI * 2.0, 10, OUT, 4.5, true)


# ---------------------------------------------------------------- animaciones

## Salta en arco hasta "to". Regresa al aterrizar (el rebote sigue después).
func hop(to: Vector2, height: float) -> void:
	var from := position
	var dist := from.distance_to(to)
	var dur := clampf(0.22 + dist / 1500.0, 0.22, 0.5)
	var dir := signf(to.x - from.x)
	z_index = 20
	Sfx.play("whoosh", randf_range(1.1, 1.4), -10.0)
	var tw := create_tween()
	tw.tween_property(self, "sy", 1.35, 0.07)
	tw.parallel().tween_property(self, "sx", 0.72, 0.07)
	tw.tween_method(_hop_step.bind(from, to, height + dist * 0.22, dir), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	lift = 0.0
	tilt = 0.0
	z_index = 0
	land()


func _hop_step(k: float, from: Vector2, to: Vector2, height: float, dir: float) -> void:
	position = from.lerp(to, k)
	lift = sin(k * PI) * height
	tilt = sin(k * PI) * 0.45 * dir
	sy = lerpf(1.35, 1.0, minf(1.0, k * 3.0))
	sx = lerpf(0.72, 1.0, minf(1.0, k * 3.0))


func land(power: float = 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(self, "sx", 1.0 + 0.5 * power, 0.05)
	tw.parallel().tween_property(self, "sy", 1.0 - 0.42 * power, 0.05)
	tw.tween_property(self, "sx", 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "sy", 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func jump() -> void:
	var tw := create_tween()
	tw.tween_property(self, "sy", 1.3, 0.06)
	tw.parallel().tween_property(self, "sx", 0.8, 0.06)
	tw.parallel().tween_property(self, "lift", 26.0, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "lift", 0.0, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(land.bind(0.7))


## Cae del cielo (para refuerzos y para el inicio del combate).
func drop(height: float, delay: float = 0.0) -> void:
	lift = height
	sx = 0.8
	sy = 1.3
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(self, "lift", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	land(1.0)


## Sale volando dando vueltas (cuando lo capturan).
func yeet() -> void:
	mood = "dead"
	idle_on = false
	z_index = 60
	var vx := randf_range(260.0, 520.0) * (1.0 if randf() < 0.5 else -1.0)
	var rs := randf_range(12.0, 22.0) * signf(vx)
	var start := position
	var tw := create_tween()
	tw.tween_method(_yeet_step.bind(start, vx, rs), 0.0, 1.0, 1.15)
	tw.tween_callback(queue_free)


func _yeet_step(k: float, start: Vector2, vx: float, rs: float) -> void:
	position = start + Vector2(vx * k * 1.5, -820.0 * k + 1700.0 * k * k)
	spin = rs * k
	sx = 1.0 + 0.5 * k
	sy = sx
	modulate.a = 1.0 - clampf((k - 0.72) / 0.28, 0.0, 1.0)


## Se cae del tablero (cuando pierdes).
func tumble(delay: float) -> void:
	mood = "dead"
	idle_on = false
	var start := position
	var vx := randf_range(-160.0, 160.0)
	var rs := randf_range(-8.0, 8.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_tumble_step.bind(start, vx, rs), 0.0, 1.0, 1.2)


func _tumble_step(k: float, start: Vector2, vx: float, rs: float) -> void:
	position = start + Vector2(vx * k, -200.0 * k + 1400.0 * k * k)
	spin = rs * k


func promote_anim() -> void:
	var tw := create_tween()
	tw.tween_property(self, "lift", 60.0, 0.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "spin", TAU * 2.0, 0.5)
	tw.tween_callback(func():
		t = Board.Q
		flash = 1.0)
	tw.tween_property(self, "lift", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		spin = 0.0
		land(1.2))
	await tw.finished


func teleport(to: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(self, "sx", 0.0, 0.15)
	tw.parallel().tween_property(self, "sy", 2.0, 0.15)
	tw.tween_callback(func(): position = to)
	tw.tween_property(self, "sx", 1.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "sy", 1.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished
