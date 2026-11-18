extends Control
## Pantalla final de victoria (el derrotado ve un popup dentro del combate).

var main: Node
var victory := true
var fx: FX
var t := 0.0
var boom := 0.5


func _ready() -> void:
	fx = FX.new()
	add_child(fx)
	var title := UI.label("¡GANASTE!" if victory else "FIN", 110, UI.GOLD, 26)
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 140)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.pivot_offset = Vector2(640, 70)
	add_child(title)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "scale", Vector2(1.08, 1.08), 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
	var sub := UI.label("Le ganaste al Gran Maestro. El tablero es tuyo.", 26, UI.CREAM, 8)
	sub.position = Vector2(0, 240)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var st := Run.stats
	var lines := [
		"Capturas: %d" % int(st["captures"]),
		"Mejor golpe: %d" % int(st["best_hit"]),
		"Puntos totales: %d" % int(st["score"]),
		"Corona: %d" % Run.corona,
	]
	if Run.corona < 3:
		lines.append("¡Desbloqueaste CORONA %d! (más difícil)" % (Run.corona + 1))
	var y := 310.0
	for l in lines:
		var lb := UI.label(l, 24, UI.LILAC, 6)
		lb.position = Vector2(0, y)
		lb.size = Vector2(1280, 34)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lb)
		y += 40.0
	var b := UI.button("MENÚ", UI.GOLD, 30)
	b.position = Vector2(560, 560)
	b.custom_minimum_size = Vector2(160, 0)
	b.pressed.connect(func(): main.show_title())
	add_child(b)
	Sfx.play("fanfare")
	if Run.demo:
		print("AUTO: FIN victoria=%s" % str(victory))
		get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit())
	var x := 200.0
	for k in [Board.P, Board.N, Board.B, Board.R, Board.Q, Board.K]:
		var pv := PieceView.new()
		pv.t = k
		pv.size = 70.0
		pv.position = Vector2(x, 690)
		pv.set_happy(9999.0)
		add_child(pv)
		x += 176.0


func _process(delta: float) -> void:
	t += delta
	boom -= delta
	if boom <= 0.0:
		boom = randf_range(0.4, 0.9)
		var p := Vector2(randf_range(100, 1180), randf_range(60, 400))
		fx.explode(p, 0.9, [UI.GOLD, UI.PINK, UI.GREEN])
		Sfx.play("boom", randf_range(1.2, 1.6), -12.0)
		if randf() < 0.3:
			fx.confetti(Rect2(0, -20, 1280, 30), 60)
	for c in get_children():
		if c is PieceView and fmod(t + c.position.x * 0.001, 1.0) < delta:
			c.jump()
