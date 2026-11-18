extends SceneTree
## Pruebas sin ventana: reglas, velocidad de la IA y calibración de metas.
## godot --headless --path . -s res://tests/sim.gd

func _init() -> void:
	var ok := true
	ok = _test_rules() and ok
	_test_ai_speed()
	_calibrate()
	print("RESULT: ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)


func _check(cond: bool, msg: String) -> bool:
	print(("  ok  " if cond else "  FAIL ") + msg)
	return cond


func _test_rules() -> bool:
	print("== reglas ==")
	var ok := true
	var b := Board.new()
	b.setup(6, 6)
	b.put(0, 5, Board.R, 0, 1)
	b.put(3, 5, Board.K, 0, 2)
	b.put(1, 4, Board.P, 0, 3)
	b.put(2, 3, Board.N, 1, 100)
	ok = _check(b.moves_from(25).size() == 2, "peón: avanza 1 y captura caballo en diagonal (%d)" % b.moves_from(25).size()) and ok
	ok = _check(b.moves_from(30).size() == 7, "torre en esquina: 5 arriba + 2 al lado antes del rey (%d)" % b.moves_from(30).size()) and ok
	var u := b.make(Vector2i(25, 20))
	ok = _check(b.cells[20] == Board.P, "captura deja el peón en la casilla") and ok
	b.unmake(u)
	ok = _check(b.cells[20] == Board.N + 8 and b.cells[25] == Board.P, "unmake restaura") and ok
	var kb := Board.new()
	kb.setup(8, 8)
	kb.mods = {"knight_camel": true}
	kb.put(3, 3, Board.N, 0, 1)
	ok = _check(kb.moves_from(27).size() == 16, "caballo borracho: 8 normales + 8 camello (%d)" % kb.moves_from(27).size()) and ok
	kb.mods = {}
	ok = _check(kb.moves_from(27).size() == 8, "caballo normal: 8 (%d)" % kb.moves_from(27).size()) and ok
	var pb := Board.new()
	pb.setup(6, 6)
	pb.mods = {"promo_offset": 2}
	pb.put(0, 3, Board.P, 0, 1)
	var pu := pb.make(Vector2i(18, 12))
	ok = _check(pu[6] == true and pb.cells[12] == Board.Q, "coronación exprés en fila 2") and ok
	var hb := Board.new()
	hb.setup(6, 6)
	hb.put(0, 0, Board.R, 0, 1)
	hb.cells[2] = Board.HOLE
	ok = _check(hb.moves_from(0).size() == 1 + 5, "hoyo bloquea la torre (%d)" % hb.moves_from(0).size()) and ok
	var m := hb.attack_mask(0)
	ok = _check(m[1] == 1 and m[2] == 0, "máscara de ataque respeta hoyos") and ok
	return ok


func _full_board(w: int) -> Board:
	var b := Board.new()
	b.setup(w, w)
	var back := [Board.R, Board.N, Board.B, Board.Q, Board.K, Board.B, Board.N, Board.R]
	for x in w:
		b.put(x, 0, back[x], 1, 100 + x)
		b.put(x, 1, Board.P, 1, 200 + x)
		b.put(x, w - 2, Board.P, 0, 10 + x)
		b.put(x, w - 1, back[x], 0, 1 + x)
	return b


func _test_ai_speed() -> void:
	print("== velocidad IA ==")
	for w in [6, 7, 8]:
		for d in [1, 2, 3]:
			var b := _full_board(w)
			var ai := ChessAI.new()
			ai.depth = d
			ai.blunder = 0.0
			var t0 := Time.get_ticks_msec()
			var m := ai.choose(b, 1)
			print("  %dx%d prof %d: %d ms, %d nodos, jugada %s" % [w, w, d, Time.get_ticks_msec() - t0, ai.nodes, str(m)])


## Juega combates con un bot "codicioso" (prof. 2) contra la IA del acto y
## mide los puntos que consigue con la fórmula base (sin reliquias).
func _calibrate() -> void:
	print("== calibración (bot prof. 2 + reliquias simuladas) ==")
	var run: Node = load("res://scripts/run.gd").new()
	for act in range(1, 9):
		run.act = act
		var line := "  acto %d:" % act
		for stage in 3:
			run.stage = stage
			run.new_army_for_test()
			var scores: Array[int] = []
			var wins := 0
			var kings := 0
			var games := 10
			for g in games:
				var r := _play(run)
				scores.append(r[0])
				if r[1]:
					kings += 1
				if r[0] >= run.target() or r[1]:
					wins += 1
			scores.sort()
			line += " e%d meta %d mediana %d gana %d/%d (rey %d) |" % [stage, run.target(), scores[games / 2], wins, games, kings]
		print(line)
	run.free()


func _play(run: Node) -> Array:
	var w: int = run.board_size()
	var b := Board.new()
	b.setup(w, w)
	var id := 1
	for e in run.player_layout(w):
		b.put(e["x"], e["y"], e["t"], 0, e["id"])
	for e in run.enemy_layout(w, ""):
		b.put(e["x"], e["y"], e["t"], 1, 1000 + id)
		id += 1
	var bot := ChessAI.new()
	bot.depth = 2
	bot.blunder = 0.0
	bot.me = 0
	bot.own_weight = 0.45
	var enemy := ChessAI.new()
	var p: Dictionary = run.ai_params()
	enemy.depth = mini(p["depth"], 2)
	enemy.blunder = p["blunder"]
	var score := 0
	var streak := 0
	# Aproximación de reliquias acumuladas: +0.4 de multiplicador por acto.
	var proxy: float = 1.0 + 0.4 * (run.act - 1)
	for turn in run.moves_allowed():
		var m := bot.choose(b, 0)
		if m.x < 0:
			break
		var cv := b.cells[m.y]
		b.make(m)
		if cv > 0:
			streak += 1
			score += int(run.chips(cv & 7) * streak * proxy)
			if (cv & 7) == Board.K:
				return [score, true]
		else:
			streak = 0
		if b.count_non_king(1) < 2:
			var free: Array[int] = []
			for i in w * 2:
				if b.cells[i] == 0:
					free.append(i)
			free.shuffle()
			for k in mini(2, free.size()):
				b.cells[free[k]] = [Board.P, Board.N, Board.B].pick_random() + 8
				b.ids[free[k]] = 5000 + k + turn * 10
		var em := enemy.choose(b, 1)
		if em.x < 0:
			continue
		var ev := b.cells[em.y]
		b.make(em)
		if ev > 0:
			streak = 0
			if (ev & 7) == Board.K:
				return [score, false]
	return [score, false]
