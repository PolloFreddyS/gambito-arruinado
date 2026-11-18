extends Node
## Estado de la partida actual (autoload "Run") y progreso guardado.

const SAVE_PATH := "user://meta.cfg"
const TARGETS: Array[int] = [180, 270, 630, 1170, 1620, 2430, 3330, 4680]
const STAGE_MULT: Array[float] = [1.0, 1.35, 1.7]
const MAX_RELICS := 5
const MAX_SCROLLS := 2
## Orden de preferencia para la fila de atrás (más cerca del rey primero).
const PREF := {5: 0, 3: 1, 2: 2, 4: 3}

var gold := 4
var act := 1
var stage := 0
var corona := 0
## Cada pieza: {"t": tipo, "ench": ""}
var army: Array = []
var relics: Array[String] = []
var scrolls: Array[String] = []
var bosses: Array[String] = []
## Maldición al azar de cada combate del acto actual ("" = ninguna).
var curses: Array[String] = ["", "", ""]
const CURSE_POOL: Array[String] = ["niebla", "torre_eterna", "plaga", "tablero_vivo", "duplicador", "cobrador", "hereje", "tormenta", "terremoto", "rey_cobarde"]
var stats := {"captures": 0, "best_hit": 0, "combats": 0, "score": 0}
var demo := false
## Velocidad del juego (el piloto automático de pruebas la sube).
var speed := 1.0
## Solo pruebas: metas mínimas para recorrer todos los actos.
var test_easy := false
var meta := {"best_act": 0, "corona_max": 0, "wins": 0, "runs": 0}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	load_meta()


func new_run(c: int) -> void:
	corona = c
	gold = 4
	act = 1
	stage = 0
	relics.clear()
	scrolls.clear()
	stats = {"captures": 0, "best_hit": 0, "combats": 0, "score": 0}
	_starting_army()
	var pool: Array[String] = CURSE_POOL.duplicate()
	pool.shuffle()
	bosses.clear()
	for i in 7:
		bosses.append(pool[i])
	bosses.append("gran_maestro")
	roll_curses()
	meta["runs"] = int(meta["runs"]) + 1
	save_meta()


func _starting_army() -> void:
	army.clear()
	for t in [Board.K, Board.R, Board.B, Board.N, Board.N, Board.P, Board.P, Board.P, Board.P]:
		army.append({"t": t, "ench": ""})


func new_army_for_test() -> void:
	_starting_army()
	if act >= 2:
		army.append({"t": Board.Q, "ench": ""})
	if act >= 3:
		army.append({"t": Board.R, "ench": ""})
		army.append({"t": Board.P, "ench": ""})
	if act >= 6:
		army.append({"t": Board.B, "ench": ""})
		army.append({"t": Board.P, "ench": ""})


func has_relic(id: String) -> bool:
	return relics.has(id)


func board_size() -> int:
	if act <= 2:
		return 6
	if act <= 5:
		return 7
	return 8


## Las piezas enemigas valen más en cada acto.
func chip_scale() -> float:
	return 1.0 + 0.75 * (act - 1)


func chips(t: int) -> int:
	return int(round(Board.VALUE[t] * chip_scale()))


func army_cap() -> int:
	return board_size() * 2


func target() -> int:
	if test_easy:
		return 10
	var t := TARGETS[act - 1] * STAGE_MULT[stage] * (1.0 + 0.25 * corona)
	return int(round(t / 10.0)) * 10


func moves_allowed() -> int:
	if test_easy:
		return 60
	# Menos jugadas: cada movimiento cuenta.
	var m := 9 + (board_size() - 6) * 2 - (1 if act >= 6 else 0)
	if has_relic("reloj_arena"):
		m += 2
	if has_relic("contrato_maldito"):
		m -= 3
	if corona >= 2:
		m -= 1
	return maxi(5, m)


func current_boss() -> String:
	return bosses[act - 1] if stage == 2 else ""


func is_final() -> bool:
	return act == 8 and stage == 2


func ai_params() -> Dictionary:
	# [profundidad máxima, milisegundos para pensar, prob. de error]
	var table := [[3, 225, 0.11], [4, 315, 0.07], [5, 405, 0.045], [5, 495, 0.025],
		[6, 585, 0.02], [6, 720, 0.01], [7, 810, 0.0], [8, 990, 0.0]]
	var row: Array = table[clampi(act, 1, 8) - 1]
	var d: int = row[0]
	var ms: float = row[1]
	var b: float = row[2]
	var aggr := 1.0
	if stage == 1:
		aggr = 1.2
	if stage == 2:
		# Jefe: piensa más, más hondo, sin regalar nada y al ataque.
		d += 1
		ms *= 1.4
		b = 0.0
		aggr = 1.3 if current_boss() == "gran_maestro" else 1.5
	ms *= 1.0 + 0.3 * corona
	if corona >= 1:
		b *= 0.5
	return {"depth": d, "time": int(ms), "blunder": b, "aggr": aggr}


func board_mods() -> Dictionary:
	return {
		"knight_camel": has_relic("caballo_borracho"),
		"king_queen": has_relic("corona_prestada"),
		"bishop_ortho": has_relic("alfil_ambidiestro"),
		"promo_offset": 2 if has_relic("coronacion_expres") else 0,
	}


static func _centered(w: int) -> Array:
	var xs := []
	for x in w:
		xs.append(x)
	var c := (w - 1) * 0.5
	xs.sort_custom(func(a, b): return absf(a - c) < absf(b - c) or (absf(a - c) == absf(b - c) and a < b))
	return xs


static func _around(w: int, kx: int) -> Array:
	var xs := []
	for x in w:
		if x != kx:
			xs.append(x)
	xs.sort_custom(func(a, b): return absi(a - kx) < absi(b - kx) or (absi(a - kx) == absi(b - kx) and a < b))
	return xs


## Posiciones iniciales del ejército del jugador. id = índice en army + 1.
func player_layout(w: int) -> Array:
	var out := []
	var back := w - 1
	var kx := w / 2
	var nonp := []
	var pawns := []
	for i in army.size():
		var t: int = army[i]["t"]
		if t == Board.K:
			out.append({"x": kx, "y": back, "t": t, "id": i + 1})
		elif t == Board.P:
			pawns.append(i)
		else:
			nonp.append(i)
	nonp.sort_custom(func(a, b): return PREF[army[a]["t"]] < PREF[army[b]["t"]])
	var slots_back := []
	for x in _around(w, kx):
		slots_back.append(Vector2i(x, back))
	var slots_2 := []
	for x in _centered(w):
		slots_2.append(Vector2i(x, back - 1))
	var slots_3 := []
	for x in _centered(w):
		slots_3.append(Vector2i(x, back - 2))
	for i in nonp:
		var s: Vector2i
		if not slots_back.is_empty():
			s = slots_back.pop_front()
		elif not slots_2.is_empty():
			s = slots_2.pop_back()
		elif not slots_3.is_empty():
			s = slots_3.pop_back()
		else:
			continue
		out.append({"x": s.x, "y": s.y, "t": army[i]["t"], "id": i + 1})
	for i in pawns:
		var s: Vector2i
		if not slots_2.is_empty():
			s = slots_2.pop_front()
		elif not slots_3.is_empty():
			s = slots_3.pop_front()
		elif not slots_back.is_empty():
			s = slots_back.pop_front()
		else:
			continue
		out.append({"x": s.x, "y": s.y, "t": Board.P, "id": i + 1})
	return out


func enemy_layout(w: int, boss_id: String) -> Array:
	# El enemigo siempre tiene más material que tú, y la ventaja crece por acto.
	var budget := 5 + act * 4 + stage * 3 + corona * 2
	var npawns := mini(w, 2 + act / 2 + stage)
	budget -= npawns
	var types := []
	if boss_id == "torre_eterna" or boss_id == "gran_maestro" or current_curse() == "torre_eterna":
		types.append(Board.R)
		types.append(Board.R)
		budget -= 8
	if boss_id == "gran_maestro":
		types.append(Board.Q)
		budget -= 6
	var cost := {Board.N: 3, Board.B: 3, Board.R: 5, Board.Q: 9}
	var guard := 0
	while budget >= 3 and guard < 30:
		guard += 1
		var opts := [Board.N, Board.B]
		if budget >= 5 and act >= 2:
			opts.append(Board.R)
		if budget >= 9 and act >= 3:
			opts.append(Board.Q)
		var pick: int = opts[rng.randi() % opts.size()]
		types.append(pick)
		budget -= cost[pick]
	types.sort_custom(func(a, b): return PREF[a] < PREF[b])
	var out := []
	var kx := w / 2
	out.append({"x": kx, "y": 0, "t": Board.K})
	var slots_back := []
	for x in _around(w, kx):
		slots_back.append(Vector2i(x, 0))
	var slots_2 := []
	for x in _centered(w):
		slots_2.append(Vector2i(x, 1))
	var slots_3 := []
	for x in _centered(w):
		slots_3.append(Vector2i(x, 2))
	for t in types:
		var s: Vector2i
		if not slots_back.is_empty():
			s = slots_back.pop_front()
		elif not slots_2.is_empty():
			s = slots_2.pop_back()
		else:
			break
		out.append({"x": s.x, "y": s.y, "t": t})
	for k in npawns:
		var s: Vector2i
		if not slots_2.is_empty():
			s = slots_2.pop_front()
		elif not slots_3.is_empty():
			s = slots_3.pop_front()
		else:
			break
		out.append({"x": s.x, "y": s.y, "t": Board.P})
	return out


## Líneas de recompensa: [[texto, oro], ...]
func reward(moves_left: int, gold_pieces: int) -> Array:
	var lines := []
	lines.append(["Victoria", 3 + stage * 2])
	if moves_left > 0:
		lines.append(["Jugadas sobrantes", mini(moves_left, 5)])
	var cap := 10 if has_relic("banco") else 5
	var interest := mini(gold / 5, cap)
	if interest > 0:
		lines.append(["Interés (1 por cada 5)", interest])
	if has_relic("chocolate"):
		lines.append(["Moneda de chocolate", 3])
	if gold_pieces > 0:
		lines.append(["Piezas de oro", gold_pieces * 3])
	return lines


## Las piezas capturadas vuelven al ejército después del combate.
## promoted: id (índice + 1) -> nuevo tipo. lost: ids perdidos para siempre
## (vidrio roto, peones traidores).
func finish_combat(promoted: Dictionary, lost: Dictionary) -> void:
	var new_army := []
	for i in army.size():
		if lost.has(i + 1):
			continue
		var e: Dictionary = army[i].duplicate()
		if promoted.has(i + 1):
			e["t"] = promoted[i + 1]
		new_army.append(e)
	army = new_army
	stats["combats"] = int(stats["combats"]) + 1


## Sortea las maldiciones del acto: la Batalla siempre trae una, la
## Escaramuza a veces desde el acto 3 y el jefe una extra desde el acto 4.
func roll_curses() -> void:
	var boss_id: String = bosses[act - 1] if bosses.size() >= act else ""
	var pool: Array[String] = []
	for c in CURSE_POOL:
		if c != boss_id:
			pool.append(c)
	pool.shuffle()
	curses = ["", "", ""]
	if act >= 3 and rng.randf() < 0.5 + 0.05 * act:
		curses[0] = pool[0]
	curses[1] = pool[1]
	if act >= 3 or corona >= 2:
		curses[2] = pool[2]


func current_curse() -> String:
	return curses[stage] if stage < curses.size() else ""


## Reglas activas del combate actual: jefe (si es jefe) + maldición.
func current_rules() -> Array[String]:
	var r: Array[String] = []
	if stage == 2:
		r.append(bosses[act - 1])
	if current_curse() != "":
		r.append(current_curse())
	return r


func advance() -> void:
	stage += 1
	if stage > 2:
		stage = 0
		act += 1
		roll_curses()
	meta["best_act"] = maxi(int(meta["best_act"]), act)
	save_meta()


func record_victory() -> void:
	clear_run()
	meta["wins"] = int(meta["wins"]) + 1
	meta["corona_max"] = maxi(int(meta["corona_max"]), mini(3, corona + 1))
	meta["best_act"] = 8
	save_meta()


func record_loss() -> void:
	clear_run()
	meta["best_act"] = maxi(int(meta["best_act"]), act)
	save_meta()


func price(base: int) -> int:
	return base + (1 if corona >= 3 else 0)


func shop_offers() -> Array:
	var offers := []
	var pool := []
	for k in GameData.RELICS.keys():
		if not relics.has(k):
			pool.append(k)
	pool.shuffle()
	for i in mini(2, pool.size()):
		offers.append({"kind": "relic", "id": pool[i], "price": price(GameData.RELICS[pool[i]]["price"])})
	var piece_pool := [Board.P, Board.P, Board.N, Board.B, Board.N, Board.B, Board.R, Board.R, Board.Q]
	for i in 2:
		var t: int = piece_pool[rng.randi() % piece_pool.size()]
		offers.append({"kind": "piece", "id": t, "price": price(GameData.PIECE_PRICE[t])})
	var sk: Array = GameData.SCROLLS.keys()
	var s: String = sk[rng.randi() % sk.size()]
	offers.append({"kind": "scroll", "id": s, "price": price(GameData.SCROLLS[s]["price"])})
	var ek: Array = GameData.ENCHANTS.keys()
	var e: String = ek[rng.randi() % ek.size()]
	offers.append({"kind": "enchant", "id": e, "price": price(GameData.ENCHANTS[e]["price"])})
	return offers


# ------------------------------------------------------------ partida guardada
# Se guarda al llegar al mapa (antes de cada combate). Si la página se recarga
# o el juego se cierra, el título ofrece CONTINUAR desde ese combate.

const RUN_PATH := "user://run.cfg"


func save_run() -> void:
	if demo or not OS.get_cmdline_user_args().is_empty():
		return
	var cf := ConfigFile.new()
	cf.set_value("run", "gold", gold)
	cf.set_value("run", "act", act)
	cf.set_value("run", "stage", stage)
	cf.set_value("run", "corona", corona)
	cf.set_value("run", "army", army)
	cf.set_value("run", "relics", Array(relics))
	cf.set_value("run", "scrolls", Array(scrolls))
	cf.set_value("run", "bosses", Array(bosses))
	cf.set_value("run", "curses", Array(curses))
	cf.set_value("run", "stats", stats)
	cf.save(RUN_PATH)


func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)


func saved_run_label() -> String:
	var cf := ConfigFile.new()
	if cf.load(RUN_PATH) != OK:
		return ""
	return "Acto %d · %s" % [int(cf.get_value("run", "act", 1)), GameData.STAGE_NAMES[int(cf.get_value("run", "stage", 0))]]


func load_run() -> bool:
	var cf := ConfigFile.new()
	if cf.load(RUN_PATH) != OK:
		return false
	gold = int(cf.get_value("run", "gold", 4))
	act = clampi(int(cf.get_value("run", "act", 1)), 1, 8)
	stage = clampi(int(cf.get_value("run", "stage", 0)), 0, 2)
	corona = int(cf.get_value("run", "corona", 0))
	army = cf.get_value("run", "army", [])
	relics.assign(cf.get_value("run", "relics", []))
	scrolls.assign(cf.get_value("run", "scrolls", []))
	bosses.assign(cf.get_value("run", "bosses", []))
	curses.assign(cf.get_value("run", "curses", ["", "", ""]))
	if curses.size() != 3:
		curses.assign(["", "", ""])
	stats = cf.get_value("run", "stats", stats)
	if army.is_empty() or bosses.size() < 8:
		clear_run()
		return false
	return true


func clear_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(RUN_PATH)


func load_meta() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in meta.keys():
		meta[k] = cf.get_value("meta", k, meta[k])


func save_meta() -> void:
	if demo or not OS.get_cmdline_user_args().is_empty():
		return
	var cf := ConfigFile.new()
	for k in meta.keys():
		cf.set_value("meta", k, meta[k])
	cf.save(SAVE_PATH)
