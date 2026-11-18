class_name ChessAI
extends RefCounted
## IA del enemigo: negamax alfa-beta con profundización iterativa contra reloj,
## tabla de transposición (memoria de posiciones), jugadas asesinas, historia,
## búsqueda de capturas al final y una evaluación con ataque al rey.
## Entiende todas las reglas raras del juego porque usa el mismo Board.

const VAL: Array[float] = [0.0, 100.0, 310.0, 330.0, 500.0, 920.0, 0.0]
const WIN := 100000.0
const EXACT := 0
const LOWER := 1
const UPPER := 2
## Peso de cada pieza al acercarse al rey contrario (ataque).
const TROPISM: Array[float] = [0.0, 0.0, 3.0, 2.0, 2.5, 5.0, 0.0]

## Profundidad máxima (la búsqueda para antes si se acaba el tiempo).
var depth := 4
## Tiempo para pensar cada jugada, en milisegundos.
var time_ms := 500
var blunder := 0.0
## Más de 1 = juega al ataque contra tu rey.
var aggression := 1.0
var qdepth := 6
## Lado dueño y cuánto le importan sus piezas (<1 = cambia piezas con gusto).
var me := 1
var own_weight := 1.0

var nodes := 0
var reached := 0
var rng := RandomNumberGenerator.new()
var _deadline := 0
var _aborted := false
var _tt := {}
var _killers := []
var _history := {}
var _zs := 0


func _init() -> void:
	rng.randomize()


func choose(b: Board, side: int) -> Vector2i:
	b.compute_hash()
	_zs = Board.zside()
	var moves: Array[Vector2i] = []
	for m in b.gen_moves(side):
		var cv := b.cells[m.y]
		if cv > 0 and (cv & 7) == Board.K:
			return m
		if b.is_legal(m):
			moves.append(m)
	if moves.is_empty():
		return Vector2i(-1, -1)
	if moves.size() == 1:
		return moves[0]
	nodes = 0
	reached = 0
	_aborted = false
	_tt.clear()
	_history.clear()
	_killers.clear()
	for i in 64:
		_killers.append([-1, -1])
	_deadline = Time.get_ticks_msec() + time_ms
	var scored := _root(b, side, moves, 1)
	for d in range(2, depth + 1):
		if Time.get_ticks_msec() > _deadline - time_ms / 3:
			break
		# La mejor jugada anterior va primero.
		scored.sort_custom(func(a, c): return a[0] > c[0])
		var order: Array[Vector2i] = []
		for s in scored:
			order.append(s[1])
		var res := _root(b, side, order, d)
		if _aborted:
			break
		scored = res
		reached = d
		if scored[0][0] > WIN * 0.5:
			break
	scored.sort_custom(func(a, c): return a[0] > c[0])
	if scored.size() > 1 and rng.randf() < blunder:
		var pick: int = rng.randi_range(1, mini(3, scored.size() - 1))
		if scored[pick][0] > -WIN * 0.5 and scored[0][0] - scored[pick][0] < 400.0:
			return scored[pick][1]
	return scored[0][1]


func _root(b: Board, side: int, moves: Array[Vector2i], d: int) -> Array:
	var scored: Array = []
	var best := -INF
	for m in moves:
		var u := b.make(m)
		# Ventana: las jugadas cercanas a la mejor reciben nota exacta;
		# las claramente peores, solo una cota (más rápido).
		var s := -_negamax(b, d - 1, -INF, -(best - 120.0), 1 - side, 1)
		b.unmake(u)
		if _aborted and d > 1:
			return scored
		best = maxf(best, s)
		scored.append([s + rng.randf() * 6.0, m])
	return scored


func _negamax(b: Board, d: int, alpha: float, beta: float, side: int, ply: int) -> float:
	nodes += 1
	if (nodes & 511) == 0 and Time.get_ticks_msec() > _deadline:
		_aborted = true
	if _aborted:
		return 0.0
	if d <= 0:
		return _quiesce(b, alpha, beta, side, qdepth)
	var key := b.hash ^ (_zs if side == 1 else 0)
	var alpha0 := alpha
	var tt_move := -1
	var e = _tt.get(key)
	if e != null:
		tt_move = e[3]
		if e[0] >= d:
			var ts: float = e[1]
			if e[2] == EXACT:
				return ts
			if e[2] == LOWER:
				alpha = maxf(alpha, ts)
			elif e[2] == UPPER:
				beta = minf(beta, ts)
			if alpha >= beta:
				return ts
	var moves := _ordered(b, side, tt_move, ply)
	if moves.is_empty():
		return evaluate(b, side)
	var best := -INF
	var best_m := -1
	for m in moves:
		var cv := b.cells[m.y]
		if cv > 0 and (cv & 7) == Board.K:
			return WIN + d
		var u := b.make(m)
		var s := -_negamax(b, d - 1, -beta, -alpha, 1 - side, ply + 1)
		b.unmake(u)
		if _aborted:
			return 0.0
		if s > best:
			best = s
			best_m = m.x * 256 + m.y
		if best > alpha:
			alpha = best
		if alpha >= beta:
			if cv <= 0:
				var code := m.x * 256 + m.y
				if ply < _killers.size() and _killers[ply][0] != code:
					_killers[ply][1] = _killers[ply][0]
					_killers[ply][0] = code
				_history[code] = int(_history.get(code, 0)) + d * d
			break
	var flag := EXACT
	if best <= alpha0:
		flag = UPPER
	elif best >= beta:
		flag = LOWER
	_tt[key] = [d, best, flag, best_m]
	return best


## Sigue mirando capturas hasta que la posición esté tranquila.
func _quiesce(b: Board, alpha: float, beta: float, side: int, qd: int) -> float:
	nodes += 1
	var stand := evaluate(b, side)
	if qd <= 0:
		return stand
	if stand >= beta:
		return stand
	if stand > alpha:
		alpha = stand
	var caps := b.gen_moves(side, true)
	if caps.is_empty():
		return alpha
	var keyed: Array[Vector3i] = []
	for m in caps:
		var victim := b.cells[m.y] & 7
		if victim == Board.K:
			return WIN
		keyed.append(Vector3i(-(victim * 16 - (b.cells[m.x] & 7)), m.x, m.y))
	keyed.sort()
	for k in keyed:
		var m := Vector2i(k.y, k.z)
		# Poda delta: ni ganando la pieza llegaría a alpha.
		if stand + VAL[b.cells[m.y] & 7] + 200.0 < alpha:
			continue
		var u := b.make(m)
		var s := -_quiesce(b, -beta, -alpha, 1 - side, qd - 1)
		b.unmake(u)
		if s >= beta:
			return s
		if s > alpha:
			alpha = s
	return alpha


## Orden: memoria > capturas (víctima valiosa, atacante barato) > asesinas > historia.
func _ordered(b: Board, side: int, tt_move: int, ply: int) -> Array[Vector2i]:
	var ms := b.gen_moves(side)
	var k1 := -1
	var k2 := -1
	if ply < _killers.size():
		k1 = _killers[ply][0]
		k2 = _killers[ply][1]
	var keyed: Array[Vector3i] = []
	for m in ms:
		var code := m.x * 256 + m.y
		var sc := 0
		var cv := b.cells[m.y]
		if code == tt_move:
			sc = 10000000
		elif cv > 0:
			sc = 1000000 + (cv & 7) * 1000 - (b.cells[m.x] & 7)
		elif code == k1:
			sc = 900000
		elif code == k2:
			sc = 800000
		else:
			sc = mini(int(_history.get(code, 0)), 700000)
		keyed.append(Vector3i(-sc, m.x, m.y))
	keyed.sort()
	var out: Array[Vector2i] = []
	for k in keyed:
		out.append(Vector2i(k.y, k.z))
	return out


func evaluate(b: Board, side: int) -> float:
	var w := b.w
	var h := b.h
	var cx := (w - 1) * 0.5
	var cy := (h - 1) * 0.5
	var kings := [-1, -1]
	for i in b.cells.size():
		var v := b.cells[i]
		if v > 0 and (v & 7) == Board.K:
			kings[v >> 3] = i
	var score := [0.0, 0.0]
	var bishops := [0, 0]
	for i in b.cells.size():
		var v := b.cells[i]
		if v <= 0:
			continue
		var t := v & 7
		var s := v >> 3
		var x := i % w
		var y := i / w
		var ry := (h - 1 - y) if s == 0 else y
		var val := VAL[t]
		var dc := absf(x - cx) + absf(y - cy)
		match t:
			Board.P:
				val += ry * ry * 2.5 + ry * 4.0
				if x > 0 and x < w - 1:
					val += 4.0
			Board.N:
				val += 14.0 - dc * 5.0
			Board.B:
				val += 8.0 - dc * 2.5
				bishops[s] += 1
			Board.R:
				if ry == h - 2:
					val += 18.0
			Board.Q:
				val += 4.0 - dc * 1.0
			Board.K:
				# Refugio: peones propios delante del rey.
				var fy := y - 1 if s == 0 else y + 1
				if fy >= 0 and fy < h:
					for dx in [-1, 0, 1]:
						var nx: int = x + dx
						if nx >= 0 and nx < w and b.cells[fy * w + nx] == Board.P + s * 8:
							val += 10.0
		# Ataque: piezas cerca del rey contrario.
		var ek: int = kings[1 - s]
		if ek != -1 and TROPISM[t] > 0.0:
			var dist := maxi(absi(ek % w - x), absi(ek / w - y))
			var bonus := TROPISM[t] * float(maxi(0, 6 - dist))
			if s == me:
				bonus *= aggression
			val += bonus
		if s == me and t != Board.K:
			val *= own_weight
		score[s] += val
	for s in 2:
		if bishops[s] >= 2:
			score[s] += 30.0
	return score[side] - score[1 - side]
