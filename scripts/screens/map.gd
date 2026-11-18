extends Control
## Mapa del acto: los 3 combates, la meta de cada uno y el jefe que viene.

var main: Node
var cards: Array[Control] = []
var t := 0.0


func _ready() -> void:
	var title := UI.label("ACTO %d DE 8" % Run.act, 56, UI.GOLD, 16)
	title.position = Vector2(0, 26)
	title.size = Vector2(1280, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := UI.label("Tablero %d×%d   ·   Oro: $%d" % [Run.board_size(), Run.board_size(), Run.gold], 20, UI.LILAC, 6)
	sub.position = Vector2(0, 100)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var saved_stage := Run.stage
	for s in 3:
		Run.stage = s
		var tgt := Run.target()
		Run.stage = saved_stage
		var is_boss := s == 2
		var color := UI.BOSS if is_boss else UI.PURPLE
		if s < saved_stage:
			color = Color("#2b1e3f")
		var p := UI.panel(color, 20)
		p.custom_minimum_size = Vector2(330, 290)
		p.position = Vector2(70 + s * 390, 150)
		var v := UI.vbox(8)
		p.add_child(v)
		v.add_child(UI.label(GameData.STAGE_NAMES[s].to_upper(), 30, UI.CREAM if s >= saved_stage else UI.LILAC, 10))
		v.add_child(UI.label("Meta: %d puntos" % tgt, 22, UI.GOLD, 8))
		v.add_child(UI.label("Recompensa: $%d+" % (3 + s * 2), 18, UI.LILAC, 6))
		if is_boss:
			var bid: String = Run.bosses[Run.act - 1]
			v.add_child(UI.label(GameData.BOSSES[bid]["name"], 22, Color("#ffc2d1"), 8))
			v.add_child(UI.wrap_label(GameData.BOSSES[bid]["desc"], 14, Color("#ffd6dd"), 300))
		var cid: String = Run.curses[s]
		if cid != "":
			v.add_child(UI.label("+ MALDICIÓN: " + GameData.BOSSES[cid]["name"], 16, UI.GREEN, 6))
			v.add_child(UI.wrap_label(GameData.BOSSES[cid]["desc"], 13, Color("#d8f5e4"), 300))
		if s < saved_stage:
			v.add_child(UI.label("✔ GANADO", 26, UI.GREEN, 8))
		elif s == saved_stage:
			v.add_child(UI.label("¡TE TOCA!", 26, UI.GREEN, 8))
		add_child(p)
		cards.append(p)
		p.pivot_offset = Vector2(165, 145)
		p.scale = Vector2(0.0, 0.0)
		var tw := p.create_tween()
		tw.tween_interval(0.1 + s * 0.12)
		tw.tween_property(p, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): Sfx.play("pop", 0.8 + s * 0.2))

	# ejército y reliquias
	var army_row := UI.hbox(0)
	army_row.position = Vector2(70, 470)
	add_child(army_row)
	army_row.add_child(UI.label("Tu ejército: ", 18, UI.LILAC, 6))
	var x := 230.0
	for e in Run.army:
		var pv := PieceView.new()
		pv.t = e["t"]
		pv.ench = e.get("ench", "")
		pv.size = 44.0
		pv.position = Vector2(x, 512)
		add_child(pv)
		x += 40.0
	var rel := "Reliquias: " + (", ".join(PackedStringArray(Run.relics.map(func(r): return GameData.RELICS[r]["name"]))) if not Run.relics.is_empty() else "ninguna")
	var rl := UI.wrap_label(rel, 16, UI.LILAC, 1140)
	rl.position = Vector2(70, 540)
	add_child(rl)
	var sc := "Pergaminos: " + (", ".join(PackedStringArray(Run.scrolls.map(func(r): return GameData.SCROLLS[r]["name"]))) if not Run.scrolls.is_empty() else "ninguno")
	var sl := UI.label(sc, 16, UI.LILAC, 5)
	sl.position = Vector2(70, 570)
	add_child(sl)

	var go := UI.button("¡A PELEAR!", UI.GOLD, 36)
	go.position = Vector2(520, 615)
	go.custom_minimum_size = Vector2(240, 0)
	go.pressed.connect(func(): main.start_combat())
	add_child(go)
	if Run.demo:
		get_tree().create_timer(1.5).timeout.connect(func(): go.pressed.emit())


func _process(delta: float) -> void:
	t += delta
	var idx := Run.stage
	if idx < cards.size() and t > 0.8:
		cards[idx].rotation = sin(t * 3.0) * 0.025
		cards[idx].position.y = 150 + sin(t * 4.0) * 6.0
