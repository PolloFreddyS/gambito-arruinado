extends Control
## Pantalla de combate: tablero, puntuación (puntos × mult), reglas de jefes,
## pergaminos, IA enemiga y todos los efectos.

const LIGHT := Color("#ffe8b8")
const DARKSQ := Color("#e07a5f")
const BOOM_WORDS: Array[String] = ["¡BOOM!", "¡PAM!", "¡ÑAM!", "¡ZAS!", "¡KAPOW!", "¡CRACK!", "¡PUM!", "¡BAM!", "¡TOMA!"]
const OUCH_WORDS: Array[String] = ["¡AY!", "¡OUCH!", "¡NOOO!", "¡AUCH!", "¡MI PIEZA!"]

var main: Node
var board: Board
var ai: ChessAI
var root: Control
var bview: Node2D
var fx: FX
var cs := 100.0
var bw := 600.0
var pieces := {}
var next_enemy_id := 1000
var sel := -1
var legal: Array[Vector2i] = []
var last_move := Vector2i(-1, -1)
var busy := true
var ended := false
var score := 0
var target := 100
var moves_left := 10
var streak := 0
var turn_no := 0
var enemy_turns := 0
var captures := 0
var first_capture_done := false
var sacrifice_pending := false
var check_mult := 0
var targeting := ""
var targeting_idx := -1
var double_turn := false
var boss := ""
var lava_warn: Array[int] = []
var lava := {}
var rook_timers: Array[int] = []
var flee_cd := 0
var fog := PackedByteArray()
var promoted := {}
var lost_forever := {}
var hover := -1
var demo_running := false
var bot: ChessAI

var sb_frame: StyleBoxFlat
var sb_shadow: StyleBoxFlat
var lbl_score: Label
var score_panel: PanelContainer
var bar_fill: ColorRect
var bar_w := 236.0
var lbl_target: Label
var lbl_chips: Label
var lbl_mult: Label
var chips_panel: PanelContainer
var mult_panel: PanelContainer
var lbl_streak: Label
var lbl_moves: Label
var moves_panel: PanelContainer
var lbl_gold: Label
var lbl_msg: Label
var scroll_box: VBoxContainer
var fire: CPUParticles2D
var thinking: Label


class BoardView extends Node2D:
	var c

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		c.draw_board(self)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	root = Control.new()
	root.size = Vector2(1280, 720)
	root.pivot_offset = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	sb_frame = UI.box(UI.PURPLE2, 22, 6, 0)
	sb_shadow = UI.box(UI.DARK, 22, 0, 0)
	_setup_board()
	_build_ui()
	fx = FX.new()
	fx.shake_root = root
	root.add_child(fx)
	_update_ui()
	_update_fog()
	_update_moods()
	_intro()


# ================================================================== montaje

func _setup_board() -> void:
	var w := Run.board_size()
	board = Board.new()
	board.setup(w, w)
	board.mods = Run.board_mods()
	cs = floorf(600.0 / w)
	bw = cs * w
	bview = BoardView.new()
	bview.c = self
	bview.position = Vector2(640.0 - bw / 2.0, 66.0)
	root.add_child(bview)
	boss = Run.current_boss()
	for e in Run.player_layout(w):
		board.put(e["x"], e["y"], e["t"], 0, e["id"])
	for e in Run.enemy_layout(w, boss):
		board.put(e["x"], e["y"], e["t"], 1, next_enemy_id)
		next_enemy_id += 1
	for i in board.cells.size():
		if board.cells[i] > 0:
			_spawn_view(i)
	target = Run.target()
	moves_left = Run.moves_allowed()
	ai = ChessAI.new()
	var p := Run.ai_params()
	ai.depth = p["depth"]
	ai.blunder = p["blunder"]
	ai.me = 1
	bot = ChessAI.new()
	bot.depth = 2
	bot.blunder = 0.1
	bot.me = 0
	bot.own_weight = 0.5


func _spawn_view(i: int) -> PieceView:
	var v := board.cells[i]
	var id := board.ids[i]
	var pv := PieceView.new()
	pv.t = v & 7
	pv.side = v >> 3
	pv.size = cs * 0.74
	if pv.side == 0 and id < 1000 and id - 1 < Run.army.size():
		pv.ench = Run.army[id - 1].get("ench", "")
	pv.position = _piece_pos(i)
	bview.add_child(pv)
	pieces[id] = pv
	return pv


func _cell_center(i: int) -> Vector2:
	return Vector2((i % board.w + 0.5) * cs, (i / board.w + 0.5) * cs)


func _piece_pos(i: int) -> Vector2:
	return _cell_center(i) + Vector2(0, cs * 0.34)


func _root_pos(i: int) -> Vector2:
	return bview.position + _cell_center(i)


func _view(i: int) -> PieceView:
	if i < 0 or board.cells[i] <= 0:
		return null
	return pieces.get(board.ids[i])


func _build_ui() -> void:
	# ---- columna izquierda
	var left := UI.vbox(10)
	left.position = Vector2(18, 18)
	left.custom_minimum_size = Vector2(270, 0)
	root.add_child(left)
	var head: PanelContainer
	if boss != "":
		head = UI.panel(UI.BOSS)
		var hv := UI.vbox(2)
		hv.add_child(UI.label("JEFE · ACTO %d" % Run.act, 14, Color("#ffc2d1"), 5))
		hv.add_child(UI.label(GameData.BOSSES[boss]["name"], 21, UI.CREAM, 7))
		hv.add_child(UI.wrap_label(GameData.BOSSES[boss]["desc"], 13, Color("#ffd6dd"), 240))
		head.add_child(hv)
	else:
		head = UI.panel(UI.PURPLE)
		var hv2 := UI.vbox(0)
		hv2.add_child(UI.label("ACTO %d DE 8" % Run.act, 14, UI.LILAC, 5))
		hv2.add_child(UI.label(GameData.STAGE_NAMES[Run.stage].to_upper(), 26, UI.CREAM, 8))
		head.add_child(hv2)
	left.add_child(head)

	score_panel = UI.panel(UI.PURPLE)
	var sv := UI.vbox(2)
	lbl_target = UI.label("META: %d" % target, 16, UI.LILAC, 6)
	sv.add_child(lbl_target)
	lbl_score = UI.label("0", 44, UI.GOLD, 12)
	sv.add_child(lbl_score)
	var bar_bg := ColorRect.new()
	bar_bg.color = UI.DARK
	bar_bg.custom_minimum_size = Vector2(bar_w, 16)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill = ColorRect.new()
	bar_fill.color = UI.GREEN
	bar_fill.size = Vector2(0, 12)
	bar_fill.position = Vector2(2, 2)
	bar_bg.add_child(bar_fill)
	sv.add_child(bar_bg)
	score_panel.add_child(sv)
	left.add_child(score_panel)

	var cm := UI.hbox(6)
	cm.alignment = BoxContainer.ALIGNMENT_CENTER
	chips_panel = UI.panel(UI.BLUE, 12)
	chips_panel.custom_minimum_size = Vector2(112, 0)
	var cv := UI.vbox(0)
	cv.add_child(UI.label("PUNTOS", 12, Color("#d6e6ff"), 4))
	lbl_chips = UI.label("0", 30, UI.CREAM, 8)
	lbl_chips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(lbl_chips)
	chips_panel.add_child(cv)
	cm.add_child(chips_panel)
	cm.add_child(UI.label("×", 30, UI.CREAM, 8))
	mult_panel = UI.panel(UI.RED, 12)
	mult_panel.custom_minimum_size = Vector2(112, 0)
	var mv := UI.vbox(0)
	mv.add_child(UI.label("MULT", 12, Color("#ffd6dd"), 4))
	lbl_mult = UI.label("1", 30, UI.CREAM, 8)
	lbl_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(lbl_mult)
	mult_panel.add_child(mv)
	cm.add_child(mult_panel)
	left.add_child(cm)
	fire = CPUParticles2D.new()
	fire.position = Vector2(56, 4)
	fire.amount = 40
	fire.lifetime = 0.6
	fire.emitting = false
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(50, 4)
	fire.direction = Vector2(0, -1)
	fire.spread = 20.0
	fire.initial_velocity_min = 60.0
	fire.initial_velocity_max = 140.0
	fire.gravity = Vector2(0, -80)
	fire.scale_amount_min = 6.0
	fire.scale_amount_max = 12.0
	var fg := Gradient.new()
	fg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	fg.colors = PackedColorArray([UI.GOLD, UI.ORANGE, Color(UI.RED, 0.0)])
	fire.color_ramp = fg
	fire.show_behind_parent = true
	mult_panel.add_child(fire)

	lbl_streak = UI.label("RACHA x0", 22, UI.LILAC, 8)
	lbl_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_streak.custom_minimum_size = Vector2(270, 0)
	left.add_child(lbl_streak)

	var row := UI.hbox(8)
	moves_panel = UI.panel(UI.PURPLE, 12)
	moves_panel.custom_minimum_size = Vector2(131, 0)
	var mvv := UI.vbox(0)
	mvv.add_child(UI.label("JUGADAS", 12, UI.LILAC, 4))
	lbl_moves = UI.label("10", 30, UI.CREAM, 8)
	mvv.add_child(lbl_moves)
	moves_panel.add_child(mvv)
	row.add_child(moves_panel)
	var gp := UI.panel(UI.PURPLE, 12)
	gp.custom_minimum_size = Vector2(131, 0)
	var gv := UI.vbox(0)
	gv.add_child(UI.label("ORO", 12, UI.LILAC, 4))
	lbl_gold = UI.label("$0", 30, UI.GOLD, 8)
	gv.add_child(lbl_gold)
	gp.add_child(gv)
	row.add_child(gp)
	left.add_child(row)

	# ---- columna derecha
	var right := UI.vbox(10)
	right.position = Vector2(992, 18)
	right.custom_minimum_size = Vector2(270, 0)
	root.add_child(right)
	var rp := UI.panel(UI.PURPLE)
	var rv := UI.vbox(4)
	rv.add_child(UI.label("RELIQUIAS %d/%d" % [Run.relics.size(), Run.MAX_RELICS], 15, UI.LILAC, 5))
	if Run.relics.is_empty():
		rv.add_child(UI.wrap_label("Ninguna todavía. Cómpralas en la tienda.", 13, UI.LILAC, 240))
	for r in Run.relics:
		var d: Dictionary = GameData.RELICS[r]
		var l := UI.label("%s  %s" % [d["icon"], d["name"]], 16, UI.CREAM, 6)
		l.tooltip_text = d["desc"]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		rv.add_child(l)
	rp.add_child(rv)
	right.add_child(rp)
	var sp := UI.panel(UI.PURPLE)
	scroll_box = UI.vbox(6)
	sp.add_child(scroll_box)
	right.add_child(sp)
	_rebuild_scrolls()
	var help := UI.panel(Color("#2b1e3f"))
	help.add_child(UI.wrap_label("Clic en tu pieza y luego en su destino. Clic derecho cancela. Captura seguido para subir la racha. Captura al rey enemigo y ganas al instante.", 13, UI.LILAC, 240))
	right.add_child(help)

	lbl_msg = UI.label("", 18, UI.CREAM, 8)
	lbl_msg.position = Vector2(300, 682)
	lbl_msg.size = Vector2(680, 30)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_msg)
	thinking = UI.label("el enemigo piensa...", 16, UI.LILAC, 6)
	thinking.position = Vector2(540, 26)
	thinking.size = Vector2(200, 24)
	thinking.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thinking.visible = false
	root.add_child(thinking)


func _rebuild_scrolls() -> void:
	for c in scroll_box.get_children():
		c.queue_free()
	scroll_box.add_child(UI.label("PERGAMINOS %d/%d" % [Run.scrolls.size(), Run.MAX_SCROLLS], 15, UI.LILAC, 5))
	if Run.scrolls.is_empty():
		scroll_box.add_child(UI.wrap_label("Sin pergaminos.", 13, UI.LILAC, 240))
	for i in Run.scrolls.size():
		var d: Dictionary = GameData.SCROLLS[Run.scrolls[i]]
		var b := UI.button("%s %s" % [d["icon"], d["name"]], UI.GREEN, 17)
		b.tooltip_text = d["desc"]
		b.pressed.connect(_use_scroll.bind(i))
		scroll_box.add_child(b)


# ================================================================== dibujo

func draw_board(n: Node2D) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	n.draw_style_box(sb_shadow, Rect2(-16, -6, bw + 32, bw + 32))
	n.draw_style_box(sb_frame, Rect2(-16, -16, bw + 32, bw + 32))
	var niebla := _boss_has("niebla")
	for i in board.cells.size():
		var x := i % board.w
		var y := i / board.w
		var r := Rect2(x * cs, y * cs, cs, cs)
		var col := LIGHT if (x + y) % 2 == 0 else DARKSQ
		if boss == "hereje" and (x + y) % 2 == 1:
			col = col.lerp(Color("#5b2a4a"), 0.35)
		n.draw_rect(r, col)
		if board.cells[i] == Board.HOLE:
			var pulse := 0.5 + 0.5 * sin(t * 6.0 + i)
			n.draw_rect(r.grow(-3), Color("#ff4d1a").lerp(Color("#ffb21a"), pulse))
			for k in 3:
				var bx := fmod(t * 0.7 + k * 0.37 + i * 0.13, 1.0)
				n.draw_circle(r.position + Vector2(cs * (0.2 + 0.3 * k), cs * (1.0 - bx)), cs * 0.07 * (1.0 - bx), Color("#fff3b0"))
		if i == last_move.x or i == last_move.y:
			n.draw_rect(r, Color(1, 0.86, 0.25, 0.32))
		if lava_warn.has(i):
			var a := 0.3 + 0.3 * absf(sin(t * 9.0))
			n.draw_rect(r, Color(1, 0.3, 0.0, a))
			n.draw_string(UI.font(), r.position + Vector2(cs * 0.36, cs * 0.66), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs * 0.5), Color(UI.DARK, 0.8))
		if i == sel:
			n.draw_rect(r, Color(1, 0.82, 0.25, 0.85))
		if niebla and fog.size() == board.cells.size() and fog[i] == 0:
			n.draw_rect(r, Color("#4a4060"))
			for k in 3:
				var cx := r.position + Vector2(cs * (0.25 + 0.25 * k) + sin(t * 1.3 + i + k) * 4.0, cs * (0.5 + 0.12 * sin(t + k)))
				n.draw_circle(cx, cs * 0.2, Color("#6b6185"))
	for m in legal:
		var c := _cell_center(m.y)
		var pulse := 1.0 + 0.15 * sin(t * 9.0)
		if board.cells[m.y] > 0:
			n.draw_arc(c, cs * 0.44 * pulse, 0.0, TAU, 32, UI.RED, 7.0, true)
			n.draw_arc(c, cs * 0.44 * pulse + 4.0, 0.0, TAU, 32, UI.DARK, 3.0, true)
		else:
			n.draw_circle(c, cs * 0.13 * pulse + 3.0, UI.DARK)
			n.draw_circle(c, cs * 0.13 * pulse, UI.GREEN)
	if targeting != "" and hover >= 0:
		var hc := _cell_center(hover)
		if targeting == "bomba":
			n.draw_rect(Rect2(hc - Vector2(cs * 1.5, cs * 1.5), Vector2(cs * 3, cs * 3)), Color(1, 0.3, 0.1, 0.3 + 0.15 * sin(t * 12.0)))
		n.draw_arc(hc, cs * 0.46, 0.0, TAU, 32, UI.GOLD, 6.0, true)


# ================================================================== entrada

func _unhandled_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm:
		hover = _cell_at_mouse()
		return
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if targeting != "":
			targeting = ""
			_msg("Pergamino cancelado.")
		sel = -1
		legal.clear()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var i := _cell_at_mouse()
	if i >= 0:
		_on_cell(i)


func _cell_at_mouse() -> int:
	var lp := bview.get_local_mouse_position()
	var x := int(floor(lp.x / cs))
	var y := int(floor(lp.y / cs))
	if x >= 0 and y >= 0 and x < board.w and y < board.h:
		return y * board.w + x
	return -1


func _on_cell(i: int) -> void:
	if busy or ended:
		return
	if targeting != "":
		await _apply_target(i)
		return
	if sel != -1:
		for m in legal:
			if m.y == i:
				await _player_move(m)
				return
	var v := board.cells[i]
	if v > 0 and (v >> 3) == 0:
		if board.frozen.has(board.ids[i]):
			_msg("Esa pieza está congelada.")
			return
		sel = i
		legal = board.moves_from(i)
		var pv := _view(i)
		if pv:
			pv.jump()
		Sfx.play("pop", 1.25, -3.0)
		if legal.is_empty():
			_msg("Esa pieza no tiene a dónde ir.")
	else:
		sel = -1
		legal.clear()


func _process(_d: float) -> void:
	if Run.demo and not busy and not ended and not demo_running:
		_demo_step()


func _autoplay() -> bool:
	return "--autoplay" in OS.get_cmdline_user_args()


func _demo_step() -> void:
	demo_running = true
	await _wait(0.35)
	if busy or ended:
		demo_running = false
		return
	# El piloto también prueba pergaminos.
	if not Run.scrolls.is_empty() and randf() < 0.35:
		var s := Run.scrolls[0]
		_use_scroll(0)
		if targeting != "":
			var pick := -1
			for i in board.cells.size():
				var v := board.cells[i]
				if s == "coronar" and v == Board.P:
					pick = i
				elif (s == "bomba" or s == "congelar") and v > 0 and (v >> 3) == 1 and (v & 7) != Board.K:
					pick = i
			if pick == -1:
				targeting = ""
			else:
				print("AUTO: usa pergamino %s en %d" % [s, pick])
				await _on_cell(pick)
		else:
			print("AUTO: usa pergamino %s" % s)
		demo_running = false
		return
	var m := bot.choose(board.clone(), 0)
	if m.x >= 0:
		_on_cell(m.x)
		await _wait(0.35)
		await _on_cell(m.y)
	demo_running = false


# ================================================================== turno del jugador

func _player_move(m: Vector2i) -> void:
	busy = true
	sel = -1
	legal.clear()
	turn_no += 1
	moves_left -= 1
	var mover_v := board.cells[m.x]
	var mover_id := board.ids[m.x]
	var cap_v := board.cells[m.y]
	var cap_id := board.ids[m.y]
	var u := board.make(m)
	last_move = m
	_update_ui()
	UI.punch(moves_panel, 0.2)
	await _move_view(mover_id, m.y)
	if cap_v > 0:
		await _player_capture(mover_v, mover_id, cap_v, cap_id, m.y)
	else:
		if streak > 0 and not Run.has_relic("racha_infinita"):
			fx.burst(_root_pos(m.y) + Vector2(0, -cs * 0.7), "racha perdida", UI.LILAC, 22, false)
			streak = 0
		if _boss_has("cobrador") and Run.gold > 0:
			Run.gold -= 1
			fx.burst(_root_pos(m.y) + Vector2(0, -cs * 1.1), "-$1 ¡COBRO!", UI.PINK, 28, false)
			Sfx.play("coin", 0.6)
	if ended:
		return
	if u[6]:
		await _promote(m.y)
	await _after_player_checks(m.y)
	_update_ui()
	if await _check_end():
		return
	await _boss_after_player()
	if ended:
		return
	if board.count_non_king(1) < 2:
		await _reinforce()
	if double_turn:
		double_turn = false
		_update_fog()
		_update_moods()
		_msg("¡Doble turno! Mueve otra vez.")
		busy = false
		return
	await _enemy_turn()
	if ended:
		return
	await _boss_after_enemy()
	if ended:
		return
	if board.find_king(0) == -1:
		await _lose("Tu rey se perdió.")
		return
	_update_fog()
	_update_moods()
	_update_ui()
	if board.gen_moves(0).is_empty():
		await _lose("Te quedaste sin jugadas posibles.")
		return
	busy = false
	if moves_left == 1:
		_msg("¡Última jugada!")
	elif moves_left <= 3:
		_msg("¡Quedan %d jugadas!" % moves_left)
	else:
		_msg("Tu turno.")


func _move_view(id: int, to: int) -> void:
	var pv: PieceView = pieces.get(id)
	if pv == null:
		return
	await pv.hop(_piece_pos(to), cs * 0.55)
	Sfx.play("land", randf_range(0.9, 1.15), -2.0)
	fx.dust(_root_pos(to) + Vector2(0, cs * 0.34), cs / 90.0)


func _player_capture(mover_v: int, mover_id: int, cap_v: int, cap_id: int, sq: int) -> void:
	var ct := cap_v & 7
	var mt := mover_v & 7
	captures += 1
	Run.stats["captures"] = int(Run.stats["captures"]) + 1
	var cpv: PieceView = pieces.get(cap_id)
	pieces.erase(cap_id)
	if cpv:
		cpv.yeet()
	if ct == Board.R and _boss_has("torre_eterna"):
		rook_timers.append(2)
	var chips := Run.chips(ct)
	var mult := 1.0 + streak
	var xm := 1.0
	var ench := _ench(mover_id)
	if Run.has_relic("lupa"):
		chips = int(chips * 1.5)
	if mt == Board.N and Run.has_relic("caballo_borracho"):
		chips += 20
	if mt == Board.Q and Run.has_relic("dama_furiosa"):
		chips += 60
	if Run.has_relic("sindicato"):
		mult += board.count(0, Board.P) / 2
	if mt == Board.R and Run.has_relic("torre_vengativa"):
		mult += 3
	if Run.has_relic("jaque_picante"):
		mult += check_mult
	if Run.has_relic("huracan"):
		mult += captures / 3
	if mt == Board.P and Run.has_relic("hambre_peon"):
		xm *= 3.0
	if mt == Board.K and Run.has_relic("rey_guerrero"):
		xm *= 4.0
	if sacrifice_pending:
		xm *= 3.0
		sacrifice_pending = false
	if Run.has_relic("contrato_maldito"):
		xm *= 2.0
	if ench == "vidrio":
		xm *= 2.0
	if not first_capture_done and Run.has_relic("gemelos"):
		xm *= 2.0
	first_capture_done = true
	if _boss_has("hereje") and _is_dark(sq):
		chips = chips / 2
	streak += 1
	var mpv: PieceView = pieces.get(mover_id)
	if mpv:
		mpv.set_happy()
	var total := chips * mult * xm
	await _score_hit(sq, chips, mult, xm, _boom_word(ct, total))
	if ct == Board.K:
		await _win(true)
		return
	if ench == "explosiva":
		await _blast_area(sq, 1, "¡REACCIÓN EN CADENA!", 0.5)
	if ench == "vidrio" and randf() < 0.25:
		await _shatter(mover_id, sq)
	_update_ui()


func _boom_word(ct: int, total: float) -> String:
	if ct == Board.K:
		return "¡JAQUE MATE!"
	if streak >= 5:
		return "¡IMPARABLE x%d!" % streak
	if total >= 600:
		return "¡MEGA BOOM!"
	if total >= 250:
		return "¡KABOOM!"
	if streak >= 3:
		return "¡COMBO x%d!" % streak
	return BOOM_WORDS[randi() % BOOM_WORDS.size()]


## El golpe completo: explosión, congelado, temblor, texto, puntos × mult y marcador.
func _score_hit(sq: int, chips: int, mult: float, xm: float, text: String) -> void:
	var total := int(round(chips * mult * xm))
	var p := _root_pos(sq)
	var big := total >= 300
	var power := clampf(0.7 + total / 350.0, 0.7, 2.4)
	Sfx.play("bigboom" if big else "boom", randf_range(0.9, 1.1))
	fx.explode(p, power)
	fx.ring(p, UI.CREAM, cs * (1.2 + power * 0.5))
	fx.shake(clampf(0.35 + total / 450.0, 0.35, 1.0))
	main.flash(Color(1, 1, 1, 0.6 if big else 0.32), 0.2)
	_zoom_punch(0.025 + minf(0.06, total / 3500.0))
	await fx.hitstop(0.06 + minf(0.14, total / 2200.0))
	fx.burst(p + Vector2(0, -cs * 0.75), text, UI.GOLD, int(clampf(36.0 + total / 12.0, 36.0, 76.0)), true, UI.RED, 0.7)
	lbl_chips.text = str(chips)
	UI.punch(chips_panel, 0.4)
	Sfx.play("tick", 1.0)
	await _wait(0.15)
	lbl_mult.text = _fmt_mult(mult, xm)
	UI.punch(mult_panel, 0.4 + minf(0.4, (mult * xm) / 20.0))
	Sfx.play("tick", 1.4)
	if mult * xm >= 4.0:
		fx.burst(mult_panel.global_position - root.global_position + Vector2(56, -10), "×%s" % _fmt_num(mult * xm), UI.ORANGE, 30, false)
	await _wait(0.15)
	fx.burst(p + Vector2(0, -cs * 0.15), "+%d" % total, UI.GREEN, 44, false)
	Run.stats["best_hit"] = maxi(int(Run.stats["best_hit"]), total)
	_add_score(total)
	await _wait(0.3)


## Puntos chicos (jaque, horquilla): sin congelado.
func _score_small(sq: int, chips: int, text: String, color: Color) -> void:
	var mult := 1.0 + streak
	var total := int(round(chips * mult))
	var p := _root_pos(sq)
	fx.burst(p + Vector2(0, -cs * 0.6), text, color, 40, true, UI.DARK, 0.6)
	fx.ring(p, color, cs)
	fx.shake(0.25)
	Sfx.play("alarm", 1.3, -6.0)
	lbl_chips.text = str(chips)
	lbl_mult.text = _fmt_mult(mult, 1.0)
	UI.punch(chips_panel, 0.25)
	UI.punch(mult_panel, 0.25)
	await _wait(0.25)
	_add_score(total)
	fx.burst(p + Vector2(0, -cs * 0.1), "+%d" % total, UI.GREEN, 32, false)
	await _wait(0.35)


func _fmt_num(v: float) -> String:
	if absf(v - round(v)) < 0.05:
		return str(int(round(v)))
	return "%.1f" % v


func _fmt_mult(mult: float, xm: float) -> String:
	if xm != 1.0:
		return "%s×%s" % [_fmt_num(mult), _fmt_num(xm)]
	return _fmt_num(mult)


func _add_score(total: int) -> void:
	var from := score
	score += total
	Run.stats["score"] = int(Run.stats["score"]) + total
	var tw := create_tween()
	tw.tween_method(func(v: float): lbl_score.text = str(int(v)), float(from), float(score), 0.55).set_ease(Tween.EASE_OUT)
	var frac := clampf(float(score) / target, 0.0, 1.0)
	tw.parallel().tween_property(bar_fill, "size:x", (bar_w - 4.0) * frac, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in 7:
		get_tree().create_timer(k * 0.07).timeout.connect(func(): Sfx.play("tick", 1.0 + k * 0.13, -8.0))
	UI.punch(score_panel, 0.15 + minf(0.25, total / 800.0))
	if score >= target:
		bar_fill.color = UI.GOLD


func _zoom_punch(a: float) -> void:
	root.scale = Vector2.ONE * (1.0 + a)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _after_player_checks(sq: int) -> void:
	if ended or board.cells[sq] <= 0 or (board.cells[sq] >> 3) != 0:
		return
	var targets := board.moves_from(sq, true)
	var ek := board.find_king(1)
	var gives_check := false
	var forks := 0
	for m in targets:
		if m.y == ek:
			gives_check = true
		forks += 1
	if gives_check:
		var kv := _view(ek)
		if kv:
			kv.mood = "scared"
		if Run.has_relic("jaque_picante"):
			check_mult += 2
		await _score_small(ek, Run.chips(Board.P) + 5, "¡JAQUE!", UI.PINK)
		if _boss_has("rey_cobarde"):
			await _king_flee()
	if forks >= 2:
		await _score_small(sq, Run.chips(Board.P) * forks, "¡HORQUILLA x%d!" % forks, UI.GREEN)


func _check_end() -> bool:
	if ended:
		return true
	if board.find_king(0) == -1:
		await _lose("Te capturaron al rey.")
		return true
	if score >= target:
		await _win(false)
		return true
	if moves_left <= 0:
		await _lose("Se acabaron las jugadas.")
		return true
	return false


func _promote(sq: int) -> void:
	var pv := _view(sq)
	var id := board.ids[sq]
	if (board.cells[sq] >> 3) == 0 and id < 1000:
		promoted[id] = Board.Q
	Sfx.play("fanfare", 1.3, -4.0)
	fx.burst(_root_pos(sq) + Vector2(0, -cs * 0.8), "¡CORONACIÓN!", UI.GOLD, 34, true, UI.PURPLE2)
	main.flash(Color(1, 0.9, 0.4, 0.4), 0.3)
	if pv:
		await pv.promote_anim()


# ================================================================== turno enemigo

func _enemy_turn() -> void:
	enemy_turns += 1
	var times := 1
	if _boss_has("duplicador") and enemy_turns % 3 == 0:
		times = 2
		Sfx.play("alarm")
		fx.burst(Vector2(640, 360), "¡DOBLE TURNO ENEMIGO!", UI.PINK, 40, true, UI.DARK, 0.6)
		if Run.demo:
			print("AUTO: regla doble turno")
		await _wait(0.7)
	for k in times:
		if ended:
			return
		await _enemy_move_once()
	for id in board.frozen.keys():
		board.frozen[id] = int(board.frozen[id]) - 1
		if board.frozen[id] <= 0:
			board.frozen.erase(id)
			var pv: PieceView = pieces.get(id)
			if pv:
				pv.frozen = false


func _enemy_move_once() -> void:
	thinking.visible = true
	await _wait(0.18)
	var m: Vector2i
	var clone := board.clone()
	if OS.has_feature("web"):
		m = ai.choose(clone, 1)
	else:
		var th := Thread.new()
		th.start(ai.choose.bind(clone, 1))
		while th.is_alive():
			await get_tree().process_frame
		m = th.wait_to_finish()
	thinking.visible = false
	if m.x < 0:
		_msg("El enemigo no tiene jugadas.")
		return
	var mover_id := board.ids[m.x]
	var cap_v := board.cells[m.y]
	var cap_id := board.ids[m.y]
	var u := board.make(m)
	last_move = m
	var mpv: PieceView = pieces.get(mover_id)
	if mpv and _boss_has("niebla"):
		mpv.visible = true
	await _move_view(mover_id, m.y)
	if cap_v > 0:
		await _enemy_capture(cap_v, cap_id, m.y)
		if mpv:
			mpv.set_happy()
	if ended:
		return
	if u[6]:
		await _promote(m.y)


func _enemy_capture(cap_v: int, cap_id: int, sq: int) -> void:
	var ct := cap_v & 7
	var pv: PieceView = pieces.get(cap_id)
	pieces.erase(cap_id)
	var p := _root_pos(sq)
	Sfx.play("boom", 0.7)
	fx.explode(p, 0.8, [UI.PINK, UI.RED, UI.PURPLE2])
	fx.shake(0.45)
	main.flash(Color(1, 0.15, 0.3, 0.35), 0.25)
	if pv:
		pv.yeet()
	var word := OUCH_WORDS[randi() % OUCH_WORDS.size()]
	fx.burst(p + Vector2(0, -cs * 0.7), word, UI.PINK, 40, true, UI.DARK)
	if streak > 0:
		fx.burst(p + Vector2(0, -cs * 0.1), "racha rota", UI.LILAC, 22, false)
	streak = 0
	if Run.has_relic("sacrificio"):
		sacrifice_pending = true
		fx.burst(p + Vector2(0, cs * 0.3), "¡próxima ×3!", UI.GOLD, 24, false)
	_update_ui()
	if ct == Board.K:
		await _lose("Te capturaron al rey.")
		return
	if ct == Board.P and Run.has_relic("kamikaze"):
		await _blast_area(sq, 1, "¡KAMIKAZE!", 1.0)
	await _wait(0.25)


# ================================================================== explosiones de área

## Destruye enemigos (menos el rey) alrededor de sq y suma sus puntos.
func _blast_area(sq: int, radius: int, text: String, chip_factor: float) -> void:
	var cx := sq % board.w
	var cy := sq / board.w
	var chips := 0
	var hit := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := cx + dx
			var y := cy + dy
			if not board.inside(x, y):
				continue
			var i := y * board.w + x
			var v := board.cells[i]
			if v > 0 and (v >> 3) == 1 and (v & 7) != Board.K:
				chips += int(Run.chips(v & 7) * chip_factor)
				hit += 1
				_destroy(i)
				fx.explode(_root_pos(i), 0.9)
	fx.explode(_root_pos(sq), 1.6, [UI.CREAM, UI.ORANGE, UI.RED])
	fx.shake(0.8)
	main.flash(Color(1, 0.7, 0.3, 0.5), 0.3)
	Sfx.play("bigboom", 0.85)
	await fx.hitstop(0.12)
	fx.burst(_root_pos(sq) + Vector2(0, -cs * 0.9), text, UI.ORANGE, 44, true, UI.DARK, 0.7)
	await _wait(0.3)
	if hit > 0:
		streak += 1
		await _score_hit(sq, chips, 1.0 + streak, 1.0, "¡x%d DESTRUIDOS!" % hit)


## Quita una pieza del tablero con su vista (sin puntos).
func _destroy(i: int) -> void:
	var v := board.cells[i]
	if v <= 0:
		return
	var id := board.ids[i]
	if (v >> 3) == 1 and (v & 7) == Board.R and _boss_has("torre_eterna"):
		rook_timers.append(2)
	board.cells[i] = 0
	board.ids[i] = 0
	var pv: PieceView = pieces.get(id)
	pieces.erase(id)
	if pv:
		pv.yeet()


func _shatter(id: int, sq: int) -> void:
	var i := board.find_id(id)
	if i == -1:
		return
	lost_forever[id] = true
	Sfx.play("glass")
	fx.explode(_root_pos(i), 0.8, [UI.CREAM, UI.ICE, UI.BLUE])
	fx.burst(_root_pos(i) + Vector2(0, -cs * 0.7), "¡CRASH! se rompió", UI.ICE, 30, true, UI.DARK)
	_destroy(i)
	await _wait(0.4)


# ================================================================== refuerzos

func _reinforce() -> void:
	var free: Array[int] = []
	for i in board.w * 2:
		if board.cells[i] == 0:
			free.append(i)
	free.shuffle()
	var n := mini(free.size(), 2 + Run.act / 3)
	if n <= 0:
		return
	Sfx.play("alarm", 0.8, -4.0)
	fx.burst(Vector2(640, 300), "¡REFUERZOS!", UI.PINK, 46, true, UI.DARK, 0.5)
	await _wait(0.4)
	var opts := [Board.P, Board.P, Board.N, Board.B]
	if Run.act >= 3:
		opts.append(Board.R)
	if Run.act >= 6:
		opts.append(Board.Q)
	for k in n:
		var i := free[k]
		await _drop_enemy(i, opts[randi() % opts.size()])


func _drop_enemy(i: int, t: int) -> void:
	board.cells[i] = t + 8
	board.ids[i] = next_enemy_id
	next_enemy_id += 1
	var pv := _spawn_view(i)
	Sfx.play("spawn", randf_range(0.9, 1.2), -4.0)
	await pv.drop(700.0)
	Sfx.play("land", 0.8)
	fx.dust(_root_pos(i) + Vector2(0, cs * 0.34), 1.3)
	fx.shake(0.25)
	_update_fog()


# ================================================================== jefes

func _boss_has(rule: String) -> bool:
	if boss == rule:
		return true
	return boss == "gran_maestro" and (rule == "duplicador" or rule == "torre_eterna")


func _boss_after_player() -> void:
	if _boss_has("plaga") and turn_no % 4 == 0:
		var pawns: Array[int] = []
		for i in board.cells.size():
			if board.cells[i] == Board.P:
				pawns.append(i)
		if not pawns.is_empty():
			var i: int = pawns[randi() % pawns.size()]
			var old := board.ids[i]
			lost_forever[old] = true
			var pv: PieceView = pieces.get(old)
			pieces.erase(old)
			board.cells[i] = Board.P + 8
			board.ids[i] = next_enemy_id
			if pv:
				pv.side = 1
				pv.ench = ""
				pv.flash = 1.0
				pieces[next_enemy_id] = pv
			next_enemy_id += 1
			Sfx.play("alarm", 0.7)
			fx.explode(_root_pos(i), 0.6, [UI.GREEN, Color("#7bd36a"), Color("#2e6b2a")])
			fx.burst(_root_pos(i) + Vector2(0, -cs * 0.7), "¡TRAIDOR!", UI.GREEN, 38, true, UI.DARK)
			if Run.demo:
				print("AUTO: regla traidor en %d" % i)
			await _wait(0.6)
	_update_fog()


func _king_flee() -> void:
	if flee_cd > 0:
		return
	var ek := board.find_king(1)
	if ek == -1:
		return
	var att := board.attack_mask(0)
	var opts: Array[int] = []
	for i in board.cells.size():
		if board.cells[i] == 0 and att[i] == 0:
			opts.append(i)
	if opts.is_empty():
		return
	var to: int = opts[randi() % opts.size()]
	var id := board.ids[ek]
	board.cells[to] = board.cells[ek]
	board.ids[to] = id
	board.cells[ek] = 0
	board.ids[ek] = 0
	flee_cd = 3
	Sfx.play("whoosh", 0.6)
	fx.burst(_root_pos(ek) + Vector2(0, -cs * 0.6), "¡HUYÓ!", UI.LILAC, 38, true, UI.DARK)
	if Run.demo:
		print("AUTO: regla rey huye %d -> %d" % [ek, to])
	var pv: PieceView = pieces.get(id)
	if pv:
		await pv.teleport(_piece_pos(to))
	fx.explode(_root_pos(to), 0.5, [UI.LILAC, UI.PURPLE2, UI.PURPLE])


func _boss_after_enemy() -> void:
	if flee_cd > 0:
		flee_cd -= 1
	if _boss_has("tablero_vivo"):
		for k in lava.keys():
			lava[k] = int(lava[k]) - 1
			if lava[k] <= 0:
				lava.erase(k)
				if board.cells[k] == Board.HOLE:
					board.cells[k] = 0
		if not lava_warn.is_empty():
			await _erupt()
		elif enemy_turns % 3 == 0:
			_pick_lava()
	if _boss_has("torre_eterna"):
		var keep: Array[int] = []
		for t in rook_timers:
			if t - 1 <= 0:
				await _respawn_rook()
			else:
				keep.append(t - 1)
		rook_timers = keep


func _pick_lava() -> void:
	var opts: Array[int] = []
	for i in board.cells.size():
		var v := board.cells[i]
		if v == Board.HOLE or (v > 0 and (v & 7) == Board.K):
			continue
		opts.append(i)
	opts.shuffle()
	lava_warn.clear()
	for k in mini(3, opts.size()):
		lava_warn.append(opts[k])
	Sfx.play("alarm", 0.6)
	fx.shake(0.3)
	_msg("¡El suelo tiembla! Las casillas marcadas explotan el próximo turno.")


func _erupt() -> void:
	Sfx.play("bigboom", 0.7)
	fx.shake(0.9)
	main.flash(Color(1, 0.4, 0.1, 0.45), 0.3)
	for i in lava_warn:
		var v := board.cells[i]
		if v > 0 and (v & 7) == Board.K:
			continue
		if v > 0:
			_destroy(i)
		board.cells[i] = Board.HOLE
		lava[i] = 2
		fx.explode(_root_pos(i), 1.0, [Color("#fff3b0"), Color("#ff9f1c"), Color("#ff4d1a")])
	fx.burst(Vector2(640, 330), "¡LAVA!", UI.ORANGE, 56, true, UI.DARK, 0.5)
	if Run.demo:
		print("AUTO: regla lava en %s" % str(lava_warn))
	lava_warn.clear()
	await fx.hitstop(0.1)
	await _wait(0.4)


func _respawn_rook() -> void:
	var free: Array[int] = []
	for i in board.w * 2:
		if board.cells[i] == 0:
			free.append(i)
	if free.is_empty():
		return
	fx.burst(Vector2(640, 260), "¡VOLVÍ!", UI.PINK, 42, true, UI.DARK, 0.4)
	if Run.demo:
		print("AUTO: regla torre revive")
	await _drop_enemy(free[randi() % free.size()], Board.R)


func _update_fog() -> void:
	if not _boss_has("niebla"):
		return
	fog = board.attack_mask(0)
	for i in board.cells.size():
		var v := board.cells[i]
		if v > 0 and (v >> 3) == 0:
			fog[i] = 1
			var x := i % board.w
			var y := i / board.w
			for d in Board.ALL8:
				if board.inside(x + d.x, y + d.y):
					fog[(y + d.y) * board.w + x + d.x] = 1
	for i in board.cells.size():
		var v := board.cells[i]
		if v > 0 and (v >> 3) == 1:
			var pv: PieceView = pieces.get(board.ids[i])
			if pv:
				pv.visible = fog[i] == 1


func _update_moods() -> void:
	var enemy_att := board.attack_mask(1)
	var my_att := board.attack_mask(0)
	for i in board.cells.size():
		var v := board.cells[i]
		if v <= 0:
			continue
		var pv: PieceView = pieces.get(board.ids[i])
		if pv == null:
			continue
		var threatened := (enemy_att[i] == 1) if (v >> 3) == 0 else (my_att[i] == 1)
		pv.mood = "scared" if threatened else "idle"


# ================================================================== pergaminos

func _use_scroll(idx: int) -> void:
	if busy or ended or idx >= Run.scrolls.size():
		return
	var s := Run.scrolls[idx]
	match s:
		"reloj":
			moves_left += 3
			_consume(idx)
			Sfx.play("coin", 1.3)
			fx.burst(moves_panel.global_position - root.global_position + Vector2(65, 0), "+3 JUGADAS", UI.GREEN, 34)
			UI.punch(moves_panel, 0.5)
			_update_ui()
		"doble":
			double_turn = true
			_consume(idx)
			fx.burst(Vector2(640, 360), "¡DOBLE TURNO!", UI.GREEN, 44, true, UI.DARK)
			Sfx.play("fanfare", 1.5, -6.0)
		_:
			targeting = s
			targeting_idx = idx
			sel = -1
			legal.clear()
			var hint := {"bomba": "Elige dónde cae la bomba.", "congelar": "Elige una pieza enemiga para congelar.", "coronar": "Elige uno de tus peones."}
			_msg(hint.get(s, "") + " (clic derecho cancela)")


func _consume(idx: int) -> void:
	Run.scrolls.remove_at(idx)
	_rebuild_scrolls()


func _apply_target(i: int) -> void:
	var v := board.cells[i]
	match targeting:
		"bomba":
			busy = true
			targeting = ""
			_consume(targeting_idx)
			await _blast_area(i, 1, "¡BOMBAZO!", 1.0)
			_update_ui()
			if not await _check_end():
				_update_fog()
				_update_moods()
				busy = false
		"congelar":
			if v <= 0 or (v >> 3) != 1:
				_msg("Elige una pieza enemiga.")
				Sfx.play("deny")
				return
			board.frozen[board.ids[i]] = 3
			var pv := _view(i)
			if pv:
				pv.frozen = true
				pv.flash = 1.0
			targeting = ""
			_consume(targeting_idx)
			Sfx.play("freeze")
			fx.explode(_root_pos(i), 0.6, [Color.WHITE, UI.ICE, UI.BLUE])
			fx.burst(_root_pos(i) + Vector2(0, -cs * 0.7), "¡CONGELADO!", UI.ICE, 34, true, UI.DARK)
		"coronar":
			if v != Board.P:
				_msg("Elige uno de tus peones.")
				Sfx.play("deny")
				return
			targeting = ""
			_consume(targeting_idx)
			board.cells[i] = Board.Q
			busy = true
			await _promote(i)
			_update_moods()
			busy = false


# ================================================================== fin del combate

func _win(by_king: bool) -> void:
	if ended:
		return
	ended = true
	busy = true
	Sfx.play("fanfare")
	fx.confetti(Rect2(0, -20, 1280, 40))
	fx.burst(Vector2(640, 330), "¡JAQUE MATE!" if by_king else "¡META!", UI.GREEN, 92, true, UI.DARK, 1.0)
	fx.shake(0.6)
	for id in pieces.keys():
		var pv: PieceView = pieces[id]
		if pv.side == 0:
			pv.set_happy(10.0)
	await _wait(0.8)
	# Los enemigos que quedan salen volando uno por uno.
	var k := 0
	for i in board.cells.size():
		var v := board.cells[i]
		if v > 0 and (v >> 3) == 1:
			var pv := _view(i)
			if pv:
				pv.visible = true
				get_tree().create_timer(k * 0.12).timeout.connect(func():
					if is_instance_valid(pv):
						fx.explode(pv.position + bview.position + Vector2(0, -cs * 0.3), 0.5)
						Sfx.play("pop", randf_range(0.6, 0.9))
						pv.yeet())
				k += 1
	await _wait(0.6 + k * 0.12)
	_win_popup()


func _gold_pieces() -> int:
	var n := 0
	for i in board.cells.size():
		var v := board.cells[i]
		if v > 0 and (v >> 3) == 0 and board.ids[i] < 1000 and _ench(board.ids[i]) == "oro":
			n += 1
	return n


func _win_popup() -> void:
	var lines := Run.reward(moves_left, _gold_pieces())
	var total := 0
	var pop := _popup(UI.PURPLE)
	var v: VBoxContainer = pop.get_child(0)
	v.add_child(UI.label("¡COMBATE GANADO!", 40, UI.GOLD, 12))
	v.add_child(UI.label("Puntos: %d / %d" % [score, target], 20, UI.LILAC, 6))
	for l in lines:
		var row := UI.hbox(10)
		var a := UI.label(str(l[0]), 22, UI.CREAM, 6)
		a.custom_minimum_size = Vector2(300, 0)
		row.add_child(a)
		row.add_child(UI.label("+$%d" % int(l[1]), 22, UI.GOLD, 6))
		v.add_child(row)
		total += int(l[1])
	var b := UI.button("COBRAR $%d" % total, UI.GOLD, 28)
	b.pressed.connect(func():
		if b.disabled:
			return
		b.disabled = true
		Run.gold += total
		Sfx.play("buy")
		Run.finish_combat(promoted, lost_forever)
		main.after_win())
	v.add_child(b)
	if Run.demo:
		print("AUTO: GANÓ acto %d etapa %d jefe=%s puntos %d/%d jugadas_sobrantes %d oro+%d reliquias=%s" % [Run.act, Run.stage, boss, score, target, moves_left, total, str(Run.relics)])
		if _autoplay():
			get_tree().create_timer(1.0).timeout.connect(func(): b.pressed.emit())
		else:
			get_tree().create_timer(3.0).timeout.connect(func(): get_tree().quit())


func _lose(reason: String) -> void:
	if ended:
		return
	ended = true
	busy = true
	Sfx.play("sad")
	main.flash(Color(1, 0.1, 0.2, 0.5), 0.5)
	fx.shake(1.0)
	fx.burst(Vector2(640, 330), "¡ARRUINADO!", UI.PINK, 96, true, UI.DARK, 1.4)
	var k := 0
	for id in pieces.keys():
		var pv: PieceView = pieces[id]
		if pv.side == 0:
			pv.tumble(0.4 + k * 0.08)
			k += 1
		else:
			pv.visible = true
			pv.set_happy(20.0)
	await _wait(1.8)
	Run.record_loss()
	var pop := _popup(UI.BOSS)
	var v: VBoxContainer = pop.get_child(0)
	v.add_child(UI.label("¡GAMBITO ARRUINADO!", 38, UI.PINK, 12))
	v.add_child(UI.label(reason, 22, UI.CREAM, 6))
	v.add_child(UI.label("Llegaste al acto %d · %s" % [Run.act, GameData.STAGE_NAMES[Run.stage]], 20, UI.LILAC, 6))
	v.add_child(UI.label("Puntos: %d / %d   ·   Mejor golpe: %d" % [score, target, int(Run.stats["best_hit"])], 18, UI.LILAC, 6))
	var row := UI.hbox(14)
	var again := UI.button("OTRA VEZ", UI.GOLD, 26)
	again.pressed.connect(func(): main.new_run(Run.corona))
	row.add_child(again)
	var menu := UI.button("MENÚ", UI.LILAC, 26)
	menu.pressed.connect(func(): main.show_title())
	row.add_child(menu)
	v.add_child(row)
	if Run.demo:
		print("AUTO: PERDIÓ acto %d etapa %d jefe=%s puntos %d/%d motivo=%s capturas=%d mejor=%d" % [Run.act, Run.stage, boss, score, target, reason, int(Run.stats["captures"]), int(Run.stats["best_hit"])])
		get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit())


func _popup(color: Color) -> PanelContainer:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	create_tween().tween_property(shade, "color:a", 0.55, 0.3)
	var p := UI.panel(color, 22)
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	add_child(p)
	p.custom_minimum_size = Vector2(520, 0)
	p.position = Vector2(380, 160)
	p.pivot_offset = Vector2(260, 180)
	p.scale = Vector2(0.2, 0.2)
	p.rotation = -0.3
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return p


# ================================================================== intro

func _intro() -> void:
	busy = true
	var i := 0
	for id in pieces.keys():
		var pv: PieceView = pieces[id]
		pv.drop(500.0 + randf() * 300.0, i * 0.035)
		i += 1
	for k in 5:
		get_tree().create_timer(0.3 + k * 0.12).timeout.connect(func(): Sfx.play("land", randf_range(0.8, 1.2), -6.0))
	await _wait(0.45 + i * 0.035)
	fx.shake(0.35)
	if boss != "":
		Sfx.play("alarm")
		fx.burst(Vector2(640, 300), GameData.BOSSES[boss]["name"].to_upper(), UI.PINK, 44, true, UI.DARK, 1.2)
		await _wait(1.0)
	else:
		fx.burst(Vector2(640, 300), "¡A PELEAR!", UI.GOLD, 54, true, UI.RED, 0.5)
		await _wait(0.6)
	_update_fog()
	_update_moods()
	busy = false
	_msg("Meta: %d puntos en %d jugadas. ¡Tu turno!" % [target, moves_left])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boomtest"):
			_boom_test(Board.R if a == "--boomtest=R" else Board.Q)


## Prueba: pone una pieza enemiga delante de un peón y la captura.
func _boom_test(piece: int) -> void:
	var was_demo := Run.demo
	Run.demo = false
	streak = 3 if piece == Board.Q else 0
	for i in board.cells.size():
		if board.cells[i] == Board.P:
			var t := i - board.w + 1
			if board.cells[t] == 0:
				board.cells[t] = piece + 8
				board.ids[t] = next_enemy_id
				next_enemy_id += 1
				_spawn_view(t)
				await _wait(0.3)
				await _player_move(Vector2i(i, t))
				Run.demo = was_demo
				return


# ================================================================== utilidades

func _ench(id: int) -> String:
	if id <= 0 or id >= 1000 or id - 1 >= Run.army.size():
		return ""
	return Run.army[id - 1].get("ench", "")


func _is_dark(i: int) -> bool:
	return (i % board.w + i / board.w) % 2 == 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _msg(t: String) -> void:
	lbl_msg.text = t
	UI.punch(lbl_msg, 0.08)


func _update_ui() -> void:
	lbl_moves.text = str(moves_left)
	lbl_moves.add_theme_color_override("font_color", UI.PINK if moves_left <= 3 else UI.CREAM)
	lbl_gold.text = "$%d" % Run.gold
	lbl_streak.text = "RACHA x%d" % streak
	var hot := streak >= 3
	lbl_streak.add_theme_color_override("font_color", UI.ORANGE if hot else (UI.GOLD if streak > 0 else UI.LILAC))
	lbl_streak.add_theme_font_size_override("font_size", 22 + mini(streak, 6) * 3)
	fire.emitting = streak >= 2
	fire.amount = 20 + mini(streak, 8) * 8
