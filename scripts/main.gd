extends Node2D
## 大圣火线 Godot 版 · 主场景：世界/刷怪/三选一/经验珠/HUD/冒烟自检

const EnemyScript := preload("res://scripts/enemy.gd")
const BossScript := preload("res://scripts/boss.gd")
const CHAPTERS := ["wuxing", "eagle", "gao", "liusha"]
const WORLD := Rect2(0, 0, 1600, 1200)
const RING_MIN := 240.0
const RING_MAX := 320.0

var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var draft_ui: CanvasLayer
var lbl_hp: Label
var lbl_exp: Label
var lbl_stats: Label
var lbl_form: Label
var lbl_boss: Label
var spawn_cd := 1.0
var wave := 0
var elapsed := 0.0
var orbs: Array = []          # {pos: Vector2}
var phantoms: Array = []      # {node: Sprite2D, life: float, next: float}
var fx_rings: Array = []      # {pos: Vector2, r: float, max: float, life: float, color: Color}
var boss: Node2D = null
var boss_spawned := false
var boss_tamed := false
var chapter := "wuxing"
var unlocked := ["tang"]
var save_check := {}
var drafts_opened := 0
var pending_drafts := 0
var draft_log: Array = []     # 每次三选一的分类记录（审计用）
var structure_result := {}
var smoke := false
var smoke_spawn_mul := 1.0
var smoke_done := false
var deaths := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.seed = 20260907
	smoke = "--smoke" in OS.get_cmdline_user_args()
	_build_world()
	_build_player()
	_build_hud()
	_build_draft()
	_load_game()
	if smoke:
		structure_result = Cards.structure_check(rng)
		save_check = Save.roundtrip_check()
		player.auto_pilot = true
		Engine.time_scale = 6.0
		for i in 6:
			var a := TAU * i / 6.0
			_spawn_one(Vector2(800, 640) + Vector2(cos(a), sin(a)) * 70.0)
		smoke_spawn_mul = 2.0

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
	player.leveled.connect(_on_leveled)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	camera.make_current()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	lbl_hp = _mk_label(Vector2(10, 8))
	lbl_exp = _mk_label(Vector2(10, 24))
	lbl_stats = _mk_label(Vector2(10, 40))
	lbl_form = _mk_label(Vector2(10, 56))
	lbl_boss = _mk_label(Vector2(196, 100))
	lbl_boss.add_theme_font_size_override("font_size", 11)
	lbl_boss.add_theme_color_override("font_color", Color("c46bff"))
	lbl_boss.size = Vector2(250, 16)
	lbl_boss.visible = false
	var hint := _mk_label(Vector2(10, 332))
	hint.text = "WASD 移动 · Space 冲刺 · Q 乾坤一棒 · E 定地重击 · 法相满自动爆发 · R 终结技"
	hint.modulate = Color(1, 1, 1, 0.55)

func _mk_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 10)
	hud.add_child(l)
	return l

func _build_draft() -> void:
	draft_ui = CanvasLayer.new()
	draft_ui.set_script(load("res://scripts/draft_ui.gd"))
	add_child(draft_ui)
	draft_ui.card_picked.connect(_on_card_picked)

# ---------------- 主循环 ----------------
func _process(delta: float) -> void:
	elapsed += delta
	_spawn_tick(delta)
	_pickup_tick()
	_phantom_tick(delta)
	lbl_hp.text = "HP %d/%d" % [int(player.hp), int(player.max_hp)]
	lbl_exp.text = "Lv%d  EXP %d/%d" % [player.level, player.exp_pts, player.exp_next]
	var cards_txt := " · 卡牌 %d" % player.upgrades.size() if player.upgrades.size() > 0 else ""
	lbl_stats.text = "击杀 %d · 存活 %d · 波次 %d · %.0fs%s" % [player.kills, get_tree().get_nodes_in_group("enemies").size(), wave, elapsed, cards_txt]
	if player.in_form():
		lbl_form.text = "法相天象 · %.1fs · 终结 %d%%" % [player.form_left, int(player.ult)]
		lbl_form.add_theme_color_override("font_color", Color("ffd46b"))
	else:
		lbl_form.text = "法相 %d%% · 终结 %d%%" % [int(player.form_charge), int(player.ult)]
		lbl_form.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	_fx_tick(delta)
	_boss_tick(delta)
	_update_boss_hud()
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
	var magnet: float = player.magnet_r()
	for orb in orbs.duplicate():
		var d := player.global_position.distance_to(orb["pos"])
		if d < 15.0:
			player.gain_exp(1)
			if player.lvl("orbHeal") > 0:
				player.hp = minf(player.max_hp, player.hp + 1.2 * player.lvl("orbHeal"))
			orbs.erase(orb)
			queue_redraw()
		elif d < magnet:
			orb["pos"] = orb["pos"].move_toward(player.global_position, 150.0 * get_process_delta_time())

func _phantom_tick(delta: float) -> void:
	for g in phantoms.duplicate():
		g["life"] -= delta
		g["node"].modulate.a = maxf(0.0, minf(0.75, g["life"]))
		if g["life"] <= 0.0:
			g["node"].queue_free()
			phantoms.erase(g)
			continue
		g["next"] -= delta
		if g["next"] <= 0.0 and player.lvl("w_72") > 0:
			g["next"] = 0.7
			var pos: Vector2 = g["node"].position
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(pos) < 85.0:
					e.take_hit(player.base_dmg() * 0.5, Vector2.ZERO)
					break

func spawn_phantom(pos: Vector2, flip: bool) -> void:
	var g := Sprite2D.new()
	g.texture = SpriteLib.frame_tex(Vector2i(2, 0))
	g.position = pos
	g.flip_h = flip
	g.modulate = Color(1.0, 0.94, 0.63, 0.75)
	g.z_index = -1
	add_child(g)
	phantoms.append({"node": g, "life": 3.6 + 0.9 * player.lvl("w_72") + 0.9 * player.lvl("w_clone"), "next": 0.0})

func spawn_fx(pos: Vector2, r: float, color: Color) -> void:
	fx_rings.append({"pos": pos, "r": 12.0, "max": r, "life": 0.38, "color": color})
	queue_redraw()

func _fx_tick(delta: float) -> void:
	for f in fx_rings.duplicate():
		f["life"] -= delta
		f["r"] = lerpf(f["max"], 12.0, f["life"] / 0.38)
		if f["life"] <= 0.0:
			fx_rings.erase(f)
	queue_redraw()

func _draw() -> void:
	for orb in orbs:
		draw_rect(Rect2(orb["pos"] - Vector2(2, 2), Vector2(4, 4)), Color(0.45, 0.9, 1.0))
	for f in fx_rings:
		var c: Color = f["color"]
		c.a = clampf(f["life"] / 0.38, 0.0, 1.0) * 0.8
		draw_arc(f["pos"], f["r"], 0, TAU, 40, c, 3.0)

func on_enemy_died(pos: Vector2) -> void:
	player.on_kill_charge()
	orbs.append({"pos": pos})
	# 雷霆天罚：击杀雷击 80px 内敌人
	if player.lvl("thunder") > 0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(pos) < 80.0:
				e.take_hit(20.0 + 10.0 * player.lvl("thunder"), Vector2.ZERO)
	queue_redraw()

# ---------------- Boss / 收服 ----------------
func _boss_tick(delta: float) -> void:
	if smoke and boss_tamed and player.hero == "tang":
		try_switch_hero()
	if not boss_spawned and elapsed >= 10.0:
		_spawn_boss()
	if boss == null:
		return
	if boss.tame_ready and not boss.is_ally:
		if smoke:
			boss.take_hit(9999.0, Vector2.ZERO)   # 冒烟：自动完成收服判定
		elif Input.is_action_just_pressed("tame"):
			if player.global_position.distance_to(boss.global_position) < 140.0:
				boss.take_hit(9999.0, Vector2.ZERO)
			else:
				toast("再靠近些（<140px）才能收服")

func _spawn_boss() -> void:
	boss_spawned = true
	boss = Node2D.new()
	boss.set_script(BossScript)
	boss.position = player.global_position + Vector2(220, -120)
	add_child(boss)
	boss.setup(self)
	toast("五行山·石猿王现身！打至残血后按 F 收服（不是击杀）")

func on_boss_tame_ready() -> void:
	toast("石猿王力竭：靠近按 F 收服！")

func on_boss_tamed() -> void:
	boss_tamed = true
	if not unlocked.has("wukong"):
		unlocked.append("wukong")
	toast("收服石猿王！悟空归位，队伍 +1")
	get_tree().call_group("enemies", "queue_free")
	chapter = "eagle"
	_write_save()

func _update_boss_hud() -> void:
	if boss == null or boss.is_ally:
		lbl_boss.visible = false
		return
	lbl_boss.visible = true
	var frac: float = boss.hp / 900.0
	var bar := ""
	var filled := int(24.0 * frac)
	for i in 24:
		bar += "█" if i < filled else "░"
	lbl_boss.text = "石猿王 P%d  %s  %d%%%s" % [boss.phase, bar, int(frac * 100), "  · 可收服！" if boss.tame_ready else ""]

func toast(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("ffe9a8"))
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.position = Vector2(200, 78)
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(l)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_property(l, "position:y", 60.0, 2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.finished.connect(func(): l.queue_free())

# ---------------- 存档 ----------------
func _write_save() -> void:
	var data := Save.make(chapter, unlocked, player.upgrades, {"kills": player.kills, "level": player.level, "survived": snappedf(elapsed, 0.1)}, ["wuxing_stone_ape"] if boss_tamed else [])
	Save.write(data)

func try_switch_hero() -> void:
	if unlocked.size() < 2:
		toast("收服更多同伴后才能切换（当前仅唐僧）")
		return
	var next := "wukong" if player.hero == "tang" else "tang"
	player.set_hero(next)

func _load_game() -> void:
	var d := Save.load_save()
	if d.is_empty():
		return
	var u = d.get("unlocked", [])
	if u is Array:
		for h in u:
			if not unlocked.has(str(h)):
				unlocked.append(str(h))
	chapter = d.get("chapter", "wuxing")
	var cards: Dictionary = d.get("cards", {})
	for k in cards.keys():
		player.upgrades[str(k)] = int(cards[k])
	toast("读取存档：章节 %s · 卡牌 %d 张" % [chapter, cards.size()])

# ---------------- 三选一 ----------------
func _on_leveled() -> void:
	if draft_ui.visible:
		pending_drafts += 1
		return
	_open_draft()

func _open_draft() -> void:
	var picks := Cards.roll(player.upgrades, 3, rng, player.hero)
	if picks.is_empty():
		return
	drafts_opened += 1
	draft_log.append(picks.map(func(u): return Cards.cat_of(u)))
	get_tree().paused = true
	draft_ui.open(picks)

func _on_card_picked(id: String) -> void:
	player.apply_card(id)
	get_tree().paused = false
	if pending_drafts > 0:
		pending_drafts -= 1
		_open_draft()

func _on_player_died() -> void:
	deaths += 1
	player.hp = player.max_hp
	player.global_position = Vector2(800, 640)
	get_tree().call_group("enemies", "queue_free")
	orbs.clear()
	queue_redraw()

# ---------------- 冒烟自检 ----------------
func _smoke_tick() -> void:
	if smoke_done or elapsed < 30.0:
		return
	smoke_done = true
	var ok: bool = player.kills >= 5 and player.atk_count >= 10 and drafts_opened >= 2 \
		and player.upgrades.size() >= 2 and int(structure_result["fails"]) == 0 \
		and player.q_count >= 3 and player.e_count >= 2 \
		and player.form_count >= 1 and player.ult_count >= 1 \
		and boss_spawned and boss_tamed \
		and get_tree().get_nodes_in_group("allies").size() >= 1 \
		and bool(save_check["ok"]) \
		and unlocked.size() >= 2 and player.switch_count >= 1
	_finish_smoke(ok)

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
		"q_count": player.q_count, "e_count": player.e_count,
		"form_count": player.form_count, "ult_count": player.ult_count,
		"boss_spawned": boss_spawned, "boss_tamed": boss_tamed,
		"allies": get_tree().get_nodes_in_group("allies").size(), "save_check": save_check,
		"hero": player.hero, "unlocked": unlocked, "switches": player.switch_count,
		"level": player.level, "deaths": deaths, "wave": wave,
		"drafts_opened": drafts_opened, "cards_owned": player.upgrades,
		"draft_log": draft_log, "structure_check": structure_result,
		"elapsed_s": snappedf(elapsed, 0.1), "screenshot": shot,
	}
	var f := FileAccess.open("res://evidence/smoke-result.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  "))
	f.close()
	print("SMOKE_RESULT ", JSON.stringify(result))
	get_tree().quit(0 if passed else 1)
