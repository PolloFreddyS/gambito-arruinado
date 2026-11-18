extends Node
## Raíz del juego: fondo animado, destello de pantalla y cambio de pantallas.

const TitleScreen := preload("res://scripts/screens/title.gd")
const MapScreen := preload("res://scripts/screens/map.gd")
const ShopScreen := preload("res://scripts/screens/shop.gd")
const EndScreen := preload("res://scripts/screens/end.gd")
const Combat := preload("res://scripts/combat.gd")

const BG_SHADER := """
shader_type canvas_item;
uniform vec4 c1 : source_color = vec4(0.17, 0.11, 0.25, 1.0);
uniform vec4 c2 : source_color = vec4(0.22, 0.14, 0.33, 1.0);
uniform float speed = 1.0;
void fragment() {
	vec2 uv = UV * vec2(16.0, 9.0);
	float t = TIME * speed;
	uv += vec2(sin(uv.y * 0.55 + t * 0.8) * 0.5, cos(uv.x * 0.35 + t * 0.6) * 0.4);
	float s = step(0.5, fract((uv.x + uv.y) * 0.22 + t * 0.12));
	vec4 col = mix(c1, c2, s);
	float v = distance(UV, vec2(0.5));
	col.rgb *= 1.0 - v * 0.55;
	COLOR = col;
}
"""

var screen: Control
var ui_layer: CanvasLayer
var bg: ColorRect
var bg_mat: ShaderMaterial
var flash_rect: ColorRect
var shot := ""
var shot_frames := 0


func _ready() -> void:
	randomize()
	var bgl := CanvasLayer.new()
	bgl.layer = -10
	add_child(bgl)
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BG_SHADER
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = sh
	bg.material = bg_mat
	bgl.add_child(bg)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var fl := CanvasLayer.new()
	fl.layer = 50
	add_child(fl)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	fl.add_child(flash_rect)
	_route_args()


## Argumentos para pruebas automáticas: --demo, --shot=<pantalla>
func _route_args() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot="):
			shot = a.substr(7)
	if "--autoplay" in args:
		# Piloto automático: juega partidas completas sin ventana.
		Run.demo = true
		Run.speed = float(_arg("--speed=", "6"))
		Engine.time_scale = Run.speed
		Run.new_run(int(_arg("--corona=", "0")))
		show_map()
		return
	if "--demo" in args:
		Run.new_run(0)
		Run.demo = true
		for a in args:
			if a.begins_with("--act="):
				Run.act = int(a.substr(6))
			if a.begins_with("--stage="):
				Run.stage = int(a.substr(8))
			if a.begins_with("--relics="):
				for r in a.substr(9).split(","):
					Run.relics.append(r)
			if a.begins_with("--boss="):
				Run.bosses[Run.act - 1] = a.substr(7)
			if a.begins_with("--scrolls="):
				for s in a.substr(10).split(","):
					Run.scrolls.append(s)
			if a.begins_with("--ench="):
				for k in Run.army.size():
					if Run.army[k]["t"] != Board.K:
						Run.army[k]["ench"] = a.substr(7)
			if a.begins_with("--speed="):
				Run.speed = float(a.substr(8))
				Engine.time_scale = Run.speed
		start_combat()
		return
	match shot:
		"map":
			Run.new_run(0)
			show_map()
		"shop":
			Run.new_run(0)
			Run.gold = 18
			show_shop()
		"end":
			Run.new_run(0)
			show_end(true)
		_:
			show_title()


func set_mood(mood: String) -> void:
	match mood:
		"boss":
			bg_mat.set_shader_parameter("c1", Color("#2a0f1f"))
			bg_mat.set_shader_parameter("c2", Color("#4a1530"))
			bg_mat.set_shader_parameter("speed", 1.8)
		"shop":
			bg_mat.set_shader_parameter("c1", Color("#0f2a26"))
			bg_mat.set_shader_parameter("c2", Color("#16413a"))
			bg_mat.set_shader_parameter("speed", 0.7)
		_:
			bg_mat.set_shader_parameter("c1", Color("#2b1c40"))
			bg_mat.set_shader_parameter("c2", Color("#382454"))
			bg_mat.set_shader_parameter("speed", 1.0)


func flash(c: Color, dur: float = 0.2) -> void:
	flash_rect.color = c
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, dur)


func _set_screen(c: Control) -> void:
	Engine.time_scale = Run.speed
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = c
	c.set("main", self)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(c)
	# Entrada con rebote
	c.pivot_offset = Vector2(640, 360)
	c.scale = Vector2(0.92, 0.92)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate:a", 1.0, 0.2)


func show_title() -> void:
	set_mood("normal")
	_set_screen(TitleScreen.new())


func new_run(corona: int) -> void:
	Run.new_run(corona)
	show_map()


func show_map() -> void:
	set_mood("boss" if Run.stage == 2 else "normal")
	_set_screen(MapScreen.new())


func start_combat() -> void:
	set_mood("boss" if Run.stage == 2 else "normal")
	_set_screen(Combat.new())


func after_win() -> void:
	if Run.is_final():
		Run.record_victory()
		show_end(true)
		return
	Run.advance()
	show_shop()


func show_shop() -> void:
	set_mood("shop")
	_set_screen(ShopScreen.new())


func show_end(victory: bool) -> void:
	set_mood("normal")
	var e := EndScreen.new()
	e.victory = victory
	_set_screen(e)


## Modo de prueba (solo con argumentos):
##   --shots=<carpeta> --every=<cuadros> --quit=<cuadros>  guarda capturas periódicas
##   --clicks=<cuadro>:<x>:<y>;...                          simula clics
func _arg(prefix: String, def: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return def


func _process(_d: float) -> void:
	if OS.get_cmdline_user_args().is_empty():
		return
	shot_frames += 1
	var dir := _arg("--shots=")
	var every := int(_arg("--every=", "30"))
	var quit_at := int(_arg("--quit=", "0"))
	if dir != "" and shot_frames % every == 0:
		get_viewport().get_texture().get_image().save_png("%s/f%05d.png" % [dir, shot_frames])
	for c in _arg("--clicks=").split(";", false):
		var parts := c.split(":")
		if parts.size() == 3 and int(parts[0]) == shot_frames:
			_fake_click(Vector2(float(parts[1]), float(parts[2])))
	if quit_at > 0 and shot_frames >= quit_at:
		get_tree().quit()


func _fake_click(p: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	Input.parse_input_event(mv)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)
