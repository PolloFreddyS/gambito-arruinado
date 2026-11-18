class_name Board
extends RefCounted
## Tablero y reglas de movimiento.
## Celda: 0 vacía, -1 hoyo (lava), si no: tipo + lado * 8.
## Lado 0 = jugador (abajo), lado 1 = enemigo (arriba).
## Variante arcade: no hay jaque obligatorio; capturar al rey gana.

const P := 1
const N := 2
const B := 3
const R := 4
const Q := 5
const K := 6
const HOLE := -1

const VALUE: Array[int] = [0, 10, 30, 30, 50, 90, 150]
const NAMES: Array[String] = ["", "peón", "caballo", "alfil", "torre", "dama", "rey"]

const KNIGHT: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]
const CAMEL: Array[Vector2i] = [Vector2i(1, 3), Vector2i(3, 1), Vector2i(-1, 3), Vector2i(-3, 1), Vector2i(1, -3), Vector2i(3, -1), Vector2i(-1, -3), Vector2i(-3, -1)]
const DIAG: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const ORTH: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ALL8: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var w := 6
var h := 6
var cells := PackedInt32Array()
var ids := PackedInt32Array()
## Modificadores de reglas del jugador (vienen de reliquias).
var mods := {}
## id de pieza -> turnos congelada.
var frozen := {}


func setup(width: int, height: int) -> void:
	w = width
	h = height
	cells.resize(w * h)
	cells.fill(0)
	ids.resize(w * h)
	ids.fill(0)


func clone() -> Board:
	var b := Board.new()
	b.w = w
	b.h = h
	b.cells = cells.duplicate()
	b.ids = ids.duplicate()
	b.mods = mods.duplicate()
	b.frozen = frozen.duplicate()
	return b


func put(x: int, y: int, t: int, side: int, id: int) -> void:
	var i := y * w + x
	cells[i] = t + side * 8
	ids[i] = id


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


static func type_of(v: int) -> int:
	return v & 7 if v > 0 else 0


static func side_of(v: int) -> int:
	return v >> 3 if v > 0 else -1


func find_king(side: int) -> int:
	var want := K + side * 8
	for i in cells.size():
		if cells[i] == want:
			return i
	return -1


func find_id(id: int) -> int:
	for i in ids.size():
		if ids[i] == id and cells[i] > 0:
			return i
	return -1


func count(side: int, t: int = 0) -> int:
	var n := 0
	for v in cells:
		if v > 0 and (v >> 3) == side and (t == 0 or (v & 7) == t):
			n += 1
	return n


func count_non_king(side: int) -> int:
	var n := 0
	for v in cells:
		if v > 0 and (v >> 3) == side and (v & 7) != K:
			n += 1
	return n


func gen_moves(side: int, captures_only := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in cells.size():
		var v := cells[i]
		if v <= 0 or (v >> 3) != side:
			continue
		if not frozen.is_empty() and frozen.has(ids[i]):
			continue
		_gen_from(i, v, side, out, captures_only)
	return out


func moves_from(i: int, captures_only := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var v := cells[i]
	if v <= 0:
		return out
	if frozen.has(ids[i]):
		return out
	_gen_from(i, v, v >> 3, out, captures_only)
	return out


func _gen_from(i: int, v: int, side: int, out: Array[Vector2i], co: bool) -> void:
	var x := i % w
	var y := i / w
	var t := v & 7
	var pm := side == 0
	match t:
		P:
			var d := -1 if side == 0 else 1
			var ny := y + d
			if ny >= 0 and ny < h:
				if not co and cells[ny * w + x] == 0:
					out.append(Vector2i(i, ny * w + x))
				for dx in [-1, 1]:
					var nx: int = x + dx
					if nx >= 0 and nx < w:
						var tv := cells[ny * w + nx]
						if tv > 0 and (tv >> 3) != side:
							out.append(Vector2i(i, ny * w + nx))
		N:
			_jumps(x, y, i, side, KNIGHT, out, co)
			if pm and mods.get("knight_camel", false):
				_jumps(x, y, i, side, CAMEL, out, co)
		B:
			_rays(x, y, i, side, DIAG, out, co)
			if pm and mods.get("bishop_ortho", false):
				_jumps(x, y, i, side, ORTH, out, co)
		R:
			_rays(x, y, i, side, ORTH, out, co)
		Q:
			_rays(x, y, i, side, ALL8, out, co)
		K:
			if pm and mods.get("king_queen", false):
				_rays(x, y, i, side, ALL8, out, co)
			else:
				_jumps(x, y, i, side, ALL8, out, co)


func _jumps(x: int, y: int, i: int, side: int, offs: Array[Vector2i], out: Array[Vector2i], co: bool) -> void:
	for o in offs:
		var nx := x + o.x
		var ny := y + o.y
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		var j := ny * w + nx
		var tv := cells[j]
		if tv == HOLE:
			continue
		if tv == 0:
			if not co:
				out.append(Vector2i(i, j))
		elif (tv >> 3) != side:
			out.append(Vector2i(i, j))


func _rays(x: int, y: int, i: int, side: int, dirs: Array[Vector2i], out: Array[Vector2i], co: bool) -> void:
	for d in dirs:
		var nx := x + d.x
		var ny := y + d.y
		while nx >= 0 and ny >= 0 and nx < w and ny < h:
			var j := ny * w + nx
			var tv := cells[j]
			if tv == HOLE:
				break
			if tv == 0:
				if not co:
					out.append(Vector2i(i, j))
			else:
				if (tv >> 3) != side:
					out.append(Vector2i(i, j))
				break
			nx += d.x
			ny += d.y


## Casillas atacadas por un lado (1 = atacada). Los peones atacan en diagonal.
func attack_mask(side: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(w * h)
	mask.fill(0)
	var tmp: Array[Vector2i] = []
	for i in cells.size():
		var v := cells[i]
		if v <= 0 or (v >> 3) != side:
			continue
		if (v & 7) == P:
			var d := -1 if side == 0 else 1
			var x := i % w
			var ny := i / w + d
			if ny >= 0 and ny < h:
				for dx in [-1, 1]:
					var nx: int = x + dx
					if nx >= 0 and nx < w:
						mask[ny * w + nx] = 1
		else:
			tmp.clear()
			# Sin filtrar casillas propias: una pieza también "defiende".
			var saved := cells[i]
			_gen_from(i, saved, side, tmp, false)
			for m in tmp:
				mask[m.y] = 1
	return mask


## Ejecuta un movimiento y devuelve los datos para deshacerlo.
func make(m: Vector2i) -> Array:
	var f := m.x
	var t := m.y
	var mv := cells[f]
	var cap := cells[t]
	var mid := ids[f]
	var cid := ids[t]
	cells[t] = mv
	ids[t] = mid
	cells[f] = 0
	ids[f] = 0
	var promo := false
	if (mv & 7) == P:
		var side := mv >> 3
		var ty := t / w
		var line: int = int(mods.get("promo_offset", 0)) if side == 0 else 0
		if (side == 0 and ty <= line) or (side == 1 and ty >= h - 1):
			cells[t] = Q + side * 8
			promo = true
	return [f, t, mv, cap, mid, cid, promo]


func unmake(u: Array) -> void:
	cells[u[0]] = u[2]
	ids[u[0]] = u[4]
	cells[u[1]] = u[3]
	ids[u[1]] = u[5]
