extends Control
## Tienda entre combates: reliquias, piezas, pergaminos y encantamientos.

var main: Node
var fx: FX
var offers: Array = []
var cards_box: HBoxContainer
var gold_lbl: Label
var msg: Label
var army_box: Control
var relic_lbl: Label
var reroll_cost := 2
var reroll_btn: Button
var pending_enchant := ""
var keeper: PieceView
var t := 0.0


func _ready() -> void:
	var title := UI.label("TIENDA DEL TÍO PEÓN", 48, UI.GOLD, 14)
	title.position = Vector2(0, 18)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	keeper = PieceView.new()
	keeper.t = Board.P
	keeper.size = 110.0
	keeper.ench = "oro"
	keeper.position = Vector2(150, 140)
	add_child(keeper)
	keeper.drop(400.0, 0.2)
	gold_lbl = UI.label("", 36, UI.GOLD, 12)
	gold_lbl.position = Vector2(1000, 80)
	add_child(gold_lbl)
	msg = UI.label("¡Compra algo, que esto no es museo!", 18, UI.LILAC, 6)
	msg.position = Vector2(0, 86)
	msg.size = Vector2(1280, 30)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(msg)

	cards_box = UI.hbox(14)
	cards_box.position = Vector2(30, 140)
	add_child(cards_box)

	var army_title := UI.label("TU EJÉRCITO (clic en una pieza para encantarla)", 16, UI.LILAC, 5)
	army_title.position = Vector2(40, 470)
	add_child(army_title)
	army_box = Control.new()
	army_box.position = Vector2(40, 495)
	army_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(army_box)
	relic_lbl = UI.wrap_label("", 16, UI.LILAC, 1200)
	relic_lbl.position = Vector2(40, 580)
	add_child(relic_lbl)

	reroll_btn = UI.button("", UI.LILAC, 22)
	reroll_btn.position = Vector2(760, 640)
	reroll_btn.pressed.connect(_reroll)
	add_child(reroll_btn)
	var next := UI.button("SIGUIENTE COMBATE →", UI.GOLD, 26)
	next.position = Vector2(960, 636)
	next.pressed.connect(func(): main.show_map())
	add_child(next)

	fx = FX.new()
	add_child(fx)
	offers = Run.shop_offers()
	_build_cards()
	_refresh()
	if Run.demo:
		_autobuy(next)


## Piloto automático: compra lo que alcance y sigue.
func _autobuy(next: Button) -> void:
	await get_tree().create_timer(1.0).timeout
	var order := range(offers.size())
	order.shuffle()
	for i in order:
		var o: Dictionary = offers[i]
		if o.get("sold", false) or Run.gold < int(o["price"]):
			continue
		var card: Control = cards_box.get_child(i) if i < cards_box.get_child_count() else null
		_buy(i, card)
		if o.get("sold", false):
			print("AUTO: compra %s %s por $%d" % [o["kind"], str(o["id"]), int(o["price"])])
		await get_tree().create_timer(0.5).timeout
		if pending_enchant != "":
			for k in Run.army.size():
				if Run.army[k]["t"] != Board.K and Run.army[k].get("ench", "") == "":
					_pick_piece(k)
					break
	next.pressed.emit()


func _process(delta: float) -> void:
	t += delta
	if fmod(t, 3.0) < delta:
		keeper.jump()


func _refresh() -> void:
	gold_lbl.text = "$%d" % Run.gold
	reroll_btn.text = "CAMBIAR ($%d)" % reroll_cost
	for c in army_box.get_children():
		c.queue_free()
	var x := 0.0
	for i in Run.army.size():
		var e: Dictionary = Run.army[i]
		var slot := Button.new()
		slot.flat = true
		slot.focus_mode = Control.FOCUS_NONE
		slot.position = Vector2(x, 0)
		slot.size = Vector2(56, 70)
		var tip: String = Board.NAMES[e["t"]]
		if e.get("ench", "") != "":
			tip += " · " + GameData.ENCHANTS[e["ench"]]["name"]
		slot.tooltip_text = tip
		slot.pressed.connect(_pick_piece.bind(i))
		army_box.add_child(slot)
		var pv := PieceView.new()
		pv.t = e["t"]
		pv.ench = e.get("ench", "")
		pv.size = 50.0
		pv.position = Vector2(28, 66)
		slot.add_child(pv)
		if pending_enchant != "" and e["t"] != Board.K and e.get("ench", "") == "":
			pv.mood = "scared"
		x += 58.0
	var names := []
	for r in Run.relics:
		names.append("%s %s" % [GameData.RELICS[r]["icon"], GameData.RELICS[r]["name"]])
	relic_lbl.text = "Reliquias (%d/%d): %s     Pergaminos (%d/%d): %s" % [
		Run.relics.size(), Run.MAX_RELICS, ", ".join(PackedStringArray(names)) if not names.is_empty() else "ninguna",
		Run.scrolls.size(), Run.MAX_SCROLLS, ", ".join(PackedStringArray(Run.scrolls.map(func(s): return GameData.SCROLLS[s]["name"]))) if not Run.scrolls.is_empty() else "ninguno"]


func _build_cards() -> void:
	for c in cards_box.get_children():
		c.queue_free()
	for i in offers.size():
		cards_box.add_child(_card(i))


func _card(i: int) -> Control:
	var o: Dictionary = offers[i]
	var kind: String = o["kind"]
	var color := UI.PURPLE
	var title_txt := ""
	var desc := ""
	var icon := ""
	var tag := ""
	match kind:
		"relic":
			var d: Dictionary = GameData.RELICS[o["id"]]
			title_txt = d["name"]
			desc = d["desc"]
			icon = d["icon"]
			color = UI.PURPLE2
			tag = "RELIQUIA"
		"piece":
			title_txt = Board.NAMES[o["id"]].capitalize()
			desc = "Se une a tu ejército para siempre."
			color = Color("#2f5d8a")
			tag = "PIEZA"
		"scroll":
			var d2: Dictionary = GameData.SCROLLS[o["id"]]
			title_txt = d2["name"]
			desc = d2["desc"]
			icon = d2["icon"]
			color = Color("#2e6b4f")
			tag = "PERGAMINO"
		"enchant":
			var d3: Dictionary = GameData.ENCHANTS[o["id"]]
			title_txt = d3["name"]
			desc = d3["desc"]
			icon = d3["icon"]
			color = Color("#8a5a1f")
			tag = "ENCANTAMIENTO"
	var p := UI.panel(color, 18)
	p.custom_minimum_size = Vector2(190, 300)
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label(tag, 13, UI.CREAM, 4))
	var art := Control.new()
	art.custom_minimum_size = Vector2(170, 80)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	if kind == "piece":
		var pv := PieceView.new()
		pv.t = o["id"]
		pv.size = 66.0
		pv.position = Vector2(85, 78)
		art.add_child(pv)
	else:
		var il := UI.label(icon, 56, UI.GOLD, 12)
		il.size = Vector2(170, 80)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		art.add_child(il)
	v.add_child(UI.wrap_label(title_txt, 19, UI.CREAM, 170))
	var dl := UI.wrap_label(desc, 13, Color("#ece3ff"), 170)
	dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(dl)
	if o.get("sold", false):
		v.add_child(UI.label("VENDIDO", 22, UI.LILAC, 6))
		p.modulate = Color(1, 1, 1, 0.45)
	else:
		var b := UI.button("$%d" % int(o["price"]), UI.GOLD, 24)
		b.pressed.connect(_buy.bind(i, p))
		v.add_child(b)
	p.pivot_offset = Vector2(95, 150)
	p.scale = Vector2.ZERO
	var tw := p.create_tween()
	tw.tween_interval(i * 0.07)
	tw.tween_property(p, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return p


func _deny(text: String, c: Control) -> void:
	Sfx.play("deny")
	msg.text = text
	UI.punch(msg, 0.15)
	if c:
		var x := c.position.x
		var tw := c.create_tween()
		for k in 4:
			tw.tween_property(c, "position:x", x + (10.0 if k % 2 == 0 else -10.0), 0.04)
		tw.tween_property(c, "position:x", x, 0.04)


func _buy(i: int, card: Control) -> void:
	var o: Dictionary = offers[i]
	if o.get("sold", false):
		return
	var price: int = o["price"]
	if Run.gold < price:
		_deny("No te alcanza. ¡Sin oro no hay gambito!", card)
		return
	match o["kind"]:
		"relic":
			if Run.relics.size() >= Run.MAX_RELICS:
				_deny("Ya tienes 5 reliquias.", card)
				return
			Run.relics.append(o["id"])
		"piece":
			if Run.army.size() >= Run.army_cap():
				_deny("Tu ejército no cabe en el tablero.", card)
				return
			Run.army.append({"t": o["id"], "ench": ""})
		"scroll":
			if Run.scrolls.size() >= Run.MAX_SCROLLS:
				_deny("Solo puedes cargar 2 pergaminos.", card)
				return
			Run.scrolls.append(o["id"])
		"enchant":
			if not _has_enchantable():
				_deny("No tienes piezas sin encantar.", card)
				return
			pending_enchant = o["id"]
			msg.text = "Ahora haz clic en una de tus piezas (no el rey) para encantarla."
	Run.gold -= price
	o["sold"] = true
	Sfx.play("buy")
	Sfx.play("coin", 1.2)
	var center := card.global_position + Vector2(95, 150)
	fx.explode(center, 0.8, [UI.GOLD, UI.ORANGE, UI.GREEN])
	fx.burst(center + Vector2(0, -60), "¡VENDIDO!", UI.GOLD, 38, true, UI.RED, 0.5)
	UI.punch(gold_lbl, 0.4)
	keeper.set_happy(2.0)
	var idx := card.get_index()
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2(1.2, 1.2), 0.08)
	tw.tween_property(card, "scale", Vector2(0.0, 0.0), 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var nc := _card(i)
		cards_box.add_child(nc)
		cards_box.move_child(nc, idx)
		card.queue_free())
	_refresh()


func _has_enchantable() -> bool:
	for e in Run.army:
		if e["t"] != Board.K and e.get("ench", "") == "":
			return true
	return false


func _pick_piece(i: int) -> void:
	if pending_enchant == "":
		return
	var e: Dictionary = Run.army[i]
	if e["t"] == Board.K or e.get("ench", "") != "":
		_deny("Esa no. Elige otra pieza sin encantar (no el rey).", null)
		return
	e["ench"] = pending_enchant
	Sfx.play("fanfare", 1.4, -6.0)
	fx.explode(army_box.position + Vector2(i * 58.0 + 28.0, 40), 0.6, [UI.CREAM, UI.GOLD, UI.ORANGE])
	msg.text = "¡%s encantado!" % Board.NAMES[e["t"]].capitalize()
	pending_enchant = ""
	_refresh()


func _reroll() -> void:
	if Run.gold < reroll_cost:
		_deny("No te alcanza para cambiar.", reroll_btn)
		return
	if pending_enchant != "":
		_deny("Primero elige la pieza para el encantamiento.", reroll_btn)
		return
	Run.gold -= reroll_cost
	reroll_cost += 1
	Sfx.play("whoosh")
	offers = Run.shop_offers()
	_build_cards()
	_refresh()
