class_name ChessAI
extends RefCounted
## Negamax con poda alfa-beta. La dificultad sale de la profundidad
## y de la probabilidad de "metida de pata".

const VAL: Array[float] = [0.0, 100.0, 300.0, 320.0, 500.0, 900.0, 20000.0]
const WIN := 100000.0

var depth := 2
var blunder := 0.2
## Lado dueño de esta IA y cuánto le importan sus propias piezas
## (menos de 1 = más agresiva, cambia piezas con gusto).
var me := 1
var own_weight := 1.0
var node_cap := 40000
var nodes := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func choose(b: Board, side: int) -> Vector2i:
	var moves := _ordered(b, side)
	if moves.is_empty():
		return Vector2i(-1, -1)
	for m in moves:
		if (b.cells[m.y] & 7) == Board.K and b.cells[m.y] > 0:
			return m
	nodes = 0
	var scored: Array = []
	for m in moves:
		var u := b.make(m)
		var s := -_negamax(b, depth - 1, -INF, INF, 1 - side)
		b.unmake(u)
		scored.append([s + rng.randf() * 12.0, m])
	scored.sort_custom(func(a, c): return a[0] > c[0])
	if scored.size() > 1 and rng.randf() < blunder:
		# Metida de pata: elige una jugada peor, pero nunca regala el rey a propósito.
		var pick: int = rng.randi_range(1, mini(3, scored.size() - 1))
		if scored[pick][0] > -WIN * 0.5:
			return scored[pick][1]
	return scored[0][1]


func _negamax(b: Board, d: int, alpha: float, beta: float, side: int) -> float:
	nodes += 1
	if d <= 0 or nodes > node_cap:
		return evaluate(b, side)
	var moves := _ordered(b, side)
	if moves.is_empty():
		return evaluate(b, side)
	var best := -INF
	for m in moves:
		var cv := b.cells[m.y]
		if cv > 0 and (cv & 7) == Board.K:
			return WIN + d
		var u := b.make(m)
		var s := -_negamax(b, d - 1, -beta, -alpha, 1 - side)
		b.unmake(u)
		if s > best:
			best = s
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best


func _ordered(b: Board, side: int) -> Array[Vector2i]:
	var ms := b.gen_moves(side)
	var caps: Array[Vector2i] = []
	var quiet: Array[Vector2i] = []
	for m in ms:
		if b.cells[m.y] > 0:
			caps.append(m)
		else:
			quiet.append(m)
	if caps.size() > 1:
		caps.sort_custom(func(a: Vector2i, c: Vector2i): return (b.cells[a.y] & 7) > (b.cells[c.y] & 7))
	caps.append_array(quiet)
	return caps


func evaluate(b: Board, side: int) -> float:
	var s := 0.0
	var cx := (b.w - 1) * 0.5
	var cy := (b.h - 1) * 0.5
	for i in b.cells.size():
		var v := b.cells[i]
		if v <= 0:
			continue
		var t := v & 7
		var val := VAL[t]
		var x := i % b.w
		var y := i / b.w
		if t == Board.P:
			val += float(y if (v >> 3) == 1 else (b.h - 1 - y)) * 8.0
		elif t != Board.K:
			val += 8.0 - (absf(x - cx) + absf(y - cy)) * 2.5
		if (v >> 3) == me and t != Board.K:
			val *= own_weight
		if (v >> 3) == side:
			s += val
		else:
			s -= val
	return s
