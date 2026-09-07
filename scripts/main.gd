extends Node2D
## 大圣火线 Godot 版 · 主场景：世界/刷怪/经验珠/HUD/冒烟自检

const EnemyScript := preload("res://scripts/enemy.gd")
const WORLD := Rect2(0, 0, 1600, 1200)
const RING_MIN := 240.0
const RING_MAX := 320.0

var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var lbl_hp: Label
var lbl_exp: Label
var lbl_stats: Label
var spawn_cd := 1.0
var wave := 0
var elapsed := 0.0
var orbs: Array = []          # {pos: Vector2}
var ghosts: Array = []        # {node: Sprite2D, life: float}
var smoke := false
var smoke_spawn_mul := 1.0
var smoke_done := false
var deaths := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 20260907
	smoke = "--smoke" in OS.get_cmdline_user_args()
	_build_world()
	_build_player()
	_build_hud()
	if smoke:
		player.auto_pilot = true
		Engine.time_scale = 6.0
		# 冒烟专用：初始包围圈 + 高刷怪频率，保证攻击窗口充足
		for i in 6:
			var a := TAU * i / 6.0
			_spawn_one(Vector2(800, 640) + Vector2(cos(a), sin(a)) * 70.0)
		smoke_spawn_mul = 2.5

func _build_world() -> void:
	var m := SpriteLib.manifest()
	var tile: Dictionary = m["tile"]
	var bg := Sprite2D.new()
	bg.texture = SpriteLib.atlas_tex()
	bg.region_enabled = true
	bg.region_rect = Rect2(tile["x"], tile["y"], tile["w"], tile["h"])
	bg.centered = false
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.scale = Vector2(WORLD.size.x / tile["w"], WORLD.size.y / tile["h"])
	bg.z_index = -10
	add_child(bg)
	# 山地标（像素图集 mountain 区）
	var mo: Dictionary = m["mountain"]
	var mount := Sprite2D.new()
	var mt := AtlasTexture.new()
	mt.atlas = SpriteLib.atlas_tex()
	mt.region = Rect2(mo["x"], mo["y"], mo["w"], mo["h"])
	mount.texture = mt
	mount.position = Vector2(800, 170)
	mount.z_index = -5
	add_child(mount)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector2(800, 640)
	add_child(player)
	player.main = self
	player.died.connect(_on_player_died)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	camera.make_current()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	lbl_hp = _mk_label(Vector2(10, 8))
	lbl_exp = _mk_label(Vector2(10, 24))
	lbl_stats = _mk_label(Vector2(10, 40))
	var hint := _mk_label(Vector2(10, 332))
	hint.text = "WASD 移动 · Space 冲刺 · 自动攻击 · 拾取经验珠成长"
	hint.modulate = Color(1, 1, 1, 0.55)

func _mk_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 10)
	hud.add_child(l)
	return l

func _process(delta: float) -> void:
	elapsed += delta
	_spawn_tick(delta)
	_pickup_tick()
	_ghost_tick(delta)
	lbl_hp.text = "HP %d/%d" % [int(player.hp), int(player.max_hp)]
	lbl_exp.text = "Lv%d  EXP %d/%d" % [player.level, player.exp_pts, player.exp_next]
	lbl_stats.text = "击杀 %d · 存活 %d · 波次 %d · %.0fs" % [player.kills, get_tree().get_nodes_in_group("enemies").size(), wave, elapsed]
	if smoke:
		_smoke_tick()

func _spawn_tick(delta: float) -> void:
	spawn_cd -= delta
	if spawn_cd > 0.0:
		return
	wave += 1
	spawn_cd = maxf(0.55, 1.4 - wave * 0.02) / smoke_spawn_mul
	var n := int((1 + wave / 6) * smoke_spawn_mul)
	for i in n:
		_spawn_one()

func _spawn_one(at: Vector2 = Vector2.INF) -> void:
	var pos := at
	if pos == Vector2.INF:
		var ang := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(RING_MIN, RING_MAX)
		pos = player.global_position + Vector2(cos(ang), sin(ang)) * d
	pos = pos.clamp(Vector2(24, 24), Vector2(1576, 1176))
	var kind := "wolf"
	var r := rng.randf()
	if wave >= 3 and r < 0.35:
		kind = "bone"
	if wave >= 5 and r > 0.8:
		kind = "bat"
	var e := Node2D.new()
	e.set_script(EnemyScript)
	e.position = pos
	add_child(e)
	e.setup(kind, self)

func _pickup_tick() -> void:
	for orb in orbs.duplicate():
		if player.global_position.distance_to(orb["pos"]) < 15.0:
			player.gain_exp(1)
			orbs.erase(orb)
			queue_redraw()
		elif player.global_position.distance_to(orb["pos"]) < 70.0:
			orb["pos"] = orb["pos"].move_toward(player.global_position, 140.0 * get_process_delta_time())

func _ghost_tick(delta: float) -> void:
	for g in ghosts.duplicate():
		g["life"] -= delta
		g["node"].modulate.a = maxf(0.0, g["life"] * 2.0)
		if g["life"] <= 0.0:
			g["node"].queue_free()
			ghosts.erase(g)

func spawn_ghost(pos: Vector2, flip: bool) -> void:
	var g := Sprite2D.new()
	g.texture = SpriteLib.frame_tex(Vector2i(2, 0))
	g.position = pos
	g.flip_h = flip
	g.modulate = Color(0.7, 0.9, 1.0, 0.6)
	g.z_index = -1
	add_child(g)
	ghosts.append({"node": g, "life": 0.25})

func on_enemy_died(pos: Vector2) -> void:
	player.kills += 1
	orbs.append({"pos": pos})
	queue_redraw()

func _on_player_died() -> void:
	if smoke:
		deaths += 1
		player.hp = player.max_hp
		player.global_position = Vector2(800, 640)
		get_tree().call_group("enemies", "queue_free")
		orbs.clear()
		return
	player.hp = player.max_hp
	player.global_position = Vector2(800, 640)
	get_tree().call_group("enemies", "queue_free")

func _draw() -> void:
	for orb in orbs:
		draw_rect(Rect2(orb["pos"] - Vector2(2, 2), Vector2(4, 4)), Color(0.45, 0.9, 1.0))

# ---------------- 冒烟自检 ----------------
func _smoke_tick() -> void:
	if smoke_done or elapsed < 18.0:
		return
	smoke_done = true
	_finish_smoke(player.kills >= 5 and player.atk_count >= 10)

func _finish_smoke(passed: bool) -> void:
	Engine.time_scale = 1.0
	var shot := "saved"
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://evidence/smoke.png")
	else:
		shot = "unavailable(headless)"
	var result := {
		"pass": passed, "kills": player.kills, "atk_count": player.atk_count,
		"level": player.level, "hp": int(player.hp), "deaths": deaths, "wave": wave,
		"elapsed_s": snappedf(elapsed, 0.1), "screenshot": shot,
	}
	var f := FileAccess.open("res://evidence/smoke-result.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  "))
	f.close()
	print("SMOKE_RESULT ", JSON.stringify(result))
	get_tree().quit(0 if passed else 1)
