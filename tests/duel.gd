extends SceneTree
## Duelo: IA nueva (ChessAI) contra la anterior (ChessAIOld).
## godot --headless --path . -s res://tests/duel.gd

const GAMES := 6
const MAX_PLIES := 70


func _init() -> void:
	for w in [6, 8]:
		var res := {"nueva": 0, "vieja": 0, "tablas": 0}
		var depths := 0
		var moves_new := 0
		var ms_total := 0
		for g in GAMES:
			var new_side := g % 2
			var r := _game(w, new_side)
			res[r[0]] += 1
			depths += r[1]
			moves_new += r[2]
			ms_total += r[3]
		print("%dx%d  nueva %d · vieja %d · tablas %d   (prof. media %.1f, %d ms por jugada)" % [w, w, res["nueva"], res["vieja"], res["tablas"], float(depths) / maxi(1, moves_new), ms_total / maxi(1, moves_new)])
	quit()


func _board(w: int) -> Board:
	var b := Board.new()
	b.setup(w, w)
	var back := [Board.R, Board.N, Board.B, Board.Q, Board.K, Board.B, Board.N, Board.R]
	if w == 6:
		back = [Board.R, Board.N, Board.Q, Board.K, Board.N, Board.R]
	for x in w:
		b.put(x, 0, back[x], 1, 100 + x)
		b.put(x, 1, Board.P, 1, 200 + x)
		b.put(x, w - 2, Board.P, 0, 10 + x)
		b.put(x, w - 1, back[x], 0, 1 + x)
	return b


## Devuelve [ganador, suma de profundidades, jugadas de la nueva, ms].
func _game(w: int, new_side: int) -> Array:
	var b := _board(w)
	var nw := ChessAI.new()
	nw.depth = 7
	nw.time_ms = 500
	nw.blunder = 0.0
	nw.me = new_side
	var old := ChessAIOld.new()
	old.depth = 4
	old.blunder = 0.0
	old.me = 1 - new_side
	var side := 0
	var dsum := 0
	var nmoves := 0
	var ms := 0
	for ply in MAX_PLIES:
		var m: Vector2i
		if side == new_side:
			var t0 := Time.get_ticks_msec()
			m = nw.choose(b.clone(), side)
			ms += Time.get_ticks_msec() - t0
			dsum += nw.reached
			nmoves += 1
		else:
			m = old.choose(b.clone(), side)
		if m.x < 0:
			if b.in_check(side):
				return ["nueva" if side != new_side else "vieja", dsum, nmoves, ms]
			return ["tablas", dsum, nmoves, ms]
		b.make(m)
		side = 1 - side
	# Sin mate: decide el material.
	var ev := ChessAI.new()
	ev.me = new_side
	var s := ev.evaluate(b, new_side)
	if s > 150.0:
		return ["nueva", dsum, nmoves, ms]
	if s < -150.0:
		return ["vieja", dsum, nmoves, ms]
	return ["tablas", dsum, nmoves, ms]
