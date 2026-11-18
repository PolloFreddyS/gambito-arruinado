extends Control
## Pantalla de título: letras que caen y rebotan, piezas bailando y explosiones.

var main: Node
var fx: FX
var letters: Array[Label] = []
var bases: Array[Vector2] = []
var dancers: Array[PieceView] = []
var t := 0.0
var corona := 0
var corona_lbl: Label
var boom_timer := 1.5
var root: Control
var help: Control


func _ready() -> void:
	root = Control.new()
	root.size = Vector2(1280, 720)
	root.pivot_offset = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_title_line("GAMBITO", 112, 70, [UI.GOLD, UI.ORANGE], 0.0)
	_title_line("ARRUINADO", 112, 185, [UI.PINK, UI.RED], 0.45)
	var sub := UI.label("un roguelike de ajedrez con demasiadas explosiones", 20, UI.LILAC, 6)
	sub.position = Vector2(0, 318)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	var col := UI.vbox(14)
	col.position = Vector2(490, 368)
	col.custom_minimum_size = Vector2(300, 0)
	root.add_child(col)
	var play := UI.button("NUEVA PARTIDA", UI.GOLD, 30)
	play.pressed.connect(func(): main.new_run(corona))
	col.add_child(play)
	var howto := UI.button("CÓMO JUGAR", UI.LILAC, 24)
	howto.pressed.connect(_show_help)
	col.add_child(howto)
	var cmax := int(Run.meta["corona_max"])
	if cmax > 0:
		var row := UI.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var lb := UI.button("<", UI.PURPLE2, 22, UI.CREAM)
		corona_lbl = UI.label("", 22, UI.GOLD, 8)
		corona_lbl.custom_minimum_size = Vector2(170, 0)
		corona_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rb := UI.button(">", UI.PURPLE2, 22, UI.CREAM)
		lb.pressed.connect(func():
			corona = maxi(0, corona - 1)
			_corona_text())
		rb.pressed.connect(func():
			corona = mini(cmax, corona + 1)
			_corona_text())
		row.add_child(lb)
		row.add_child(corona_lbl)
		row.add_child(rb)
		col.add_child(row)
		_corona_text()
	if not OS.has_feature("web"):
		var quit := UI.button("SALIR", UI.PINK, 22)
		quit.pressed.connect(func(): get_tree().quit())
		col.add_child(quit)

	var info := UI.label("Mejor acto: %d   ·   Victorias: %d   ·   Partidas: %d" % [int(Run.meta["best_act"]), int(Run.meta["wins"]), int(Run.meta["runs"])], 15, UI.LILAC, 5)
	info.position = Vector2(0, 690)
	info.size = Vector2(1280, 24)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info)

	var types := [Board.P, Board.N, Board.B, Board.K, Board.Q, Board.R, Board.P]
	for i in types.size():
		var pv := PieceView.new()
		pv.t = types[i]
		pv.side = 0 if i < 4 else 1
		pv.size = 74.0
		pv.position = Vector2(150 + i * 0 + (i if i < 4 else i + 7) * 72.0, 660)
		if i >= 4:
			pv.position.x = 1280 - 150 - (types.size() - 1 - i) * 72.0
		root.add_child(pv)
		pv.drop(600.0, 0.9 + i * 0.1)
		dancers.append(pv)
	fx = FX.new()
	fx.shake_root = root
	root.add_child(fx)


func _corona_text() -> void:
	corona_lbl.text = "CORONA %d" % corona if corona > 0 else "NORMAL"


func _title_line(word: String, fs: int, y: float, cols: Array, delay: float) -> void:
	var f := UI.font()
	var total := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (word.length() - 1) * 4.0
	var x := 640.0 - total / 2.0
	for i in word.length():
		var ch := word[i]
		var l := UI.label(ch, fs, cols[i % 2], 22)
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		l.position = Vector2(x, y - 500)
		l.size = Vector2(w, fs * 1.3)
		l.pivot_offset = Vector2(w / 2.0, fs * 0.9)
		root.add_child(l)
		letters.append(l)
		var base := Vector2(x, y)
		bases.append(base)
		var tw := l.create_tween()
		tw.tween_interval(delay + i * 0.06)
		tw.tween_property(l, "position", base, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			Sfx.play("land", randf_range(1.0, 1.4), -10.0)
			if fx:
				fx.dust(base + Vector2(w / 2.0, fs * 1.1), 0.8))
		x += w + 4.0


func _process(delta: float) -> void:
	t += delta
	for i in letters.size():
		var l := letters[i]
		if t > 1.6:
			l.position.y = bases[i].y + sin(t * 3.0 + i * 0.5) * 7.0
			l.rotation = sin(t * 2.0 + i * 0.8) * 0.07
	for i in dancers.size():
		var pv := dancers[i]
		if t > 2.0 and fmod(t + i * 0.25, 2.2) < delta:
			pv.jump()
	boom_timer -= delta
	if boom_timer <= 0.0 and help == null:
		boom_timer = randf_range(1.2, 2.4)
		var p := Vector2(randf_range(120, 1160), randf_range(380, 600))
		if absf(p.x - 640.0) < 230.0:
			p.x += 460.0 * signf(p.x - 640.0 + 0.1)
		fx.explode(p, 0.7)
		fx.burst(p + Vector2(0, -40), ["¡BOOM!", "¡PAM!", "¡KAPOW!", "¡ZAS!", "¡JAQUE!"].pick_random(), UI.GOLD, 34, true, UI.RED, 0.4)
		fx.shake(0.18)
		Sfx.play("boom", randf_range(1.1, 1.4), -14.0)


func _show_help() -> void:
	if help:
		return
	help = ColorRect.new()
	(help as ColorRect).color = Color(0, 0, 0, 0.6)
	help.size = Vector2(1280, 720)
	help.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(help)
	var p := UI.panel(UI.PURPLE, 22)
	p.position = Vector2(240, 60)
	p.custom_minimum_size = Vector2(800, 0)
	help.add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label("CÓMO JUGAR", 34, UI.GOLD, 10))
	var lines := [
		"Cada combate es una partida corta. Tienes pocas jugadas para llegar a la META de puntos.",
		"Capturar da PUNTOS según la pieza. Capturar en turnos seguidos sube la RACHA, y la racha sube el MULT.",
		"Puntaje del golpe = PUNTOS × MULT. Jaques y horquillas también suman.",
		"Si capturas al rey enemigo ganas al instante. Si te capturan el rey o se acaban las jugadas: ¡ARRUINADO!",
		"Las piezas que pierdes vuelven después del combate (menos el vidrio roto y los traidores).",
		"Entre combates compras RELIQUIAS (efectos para siempre), PIEZAS, PERGAMINOS (un uso) y ENCANTAMIENTOS.",
		"8 actos de 3 combates: Escaramuza, Batalla y un JEFE que rompe una regla. Llega al Gran Maestro y gánale.",
		"Aquí no hay jaque obligatorio ni enroque: es ajedrez arcade.",
	]
	for l in lines:
		v.add_child(UI.wrap_label("• " + l, 18, UI.CREAM, 760))
	var ok := UI.button("¡ENTENDIDO!", UI.GOLD, 26)
	ok.pressed.connect(func():
		help.queue_free()
		help = null)
	v.add_child(ok)
