extends Node2D
## 大圣火线 Godot 版 · 主场景：世界/刷怪/三选一/经验珠/HUD/冒烟自检

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BossScript := preload("res://scripts/boss.gd")
const SfxLib := preload("res://scripts/sfx.gd")
const CHAPTER_CFG := {
	"wuxing": {"name": "五行山", "boss": "石猿王", "hp": 900.0, "speed": 46.0, "tint": Color(0.72, 0.38, 0.85), "scale": 2.1, "unlock": "wukong", "next": "eagle"},
	"eagle": {"name": "鹰愁涧", "boss": "小白龙·敖烈", "hp": 1100.0, "speed": 72.0, "tint": Color(0.55, 0.85, 1.0), "scale": 2.2, "unlock": "whiteDragon", "next": "gao", "charge_every": 2.6},
	"gao": {"name": "高老庄", "boss": "猪刚鬣", "hp": 1400.0, "speed": 40.0, "tint": Color(1.0, 0.62, 0.35), "scale": 2.5, "unlock": "bajie", "next": "liusha", "contact": 20.0},
	"liusha": {"name": "流沙河", "boss": "卷帘大将·沙悟净", "hp": 1700.0, "speed": 52.0, "tint": Color(0.85, 0.75, 0.45), "scale": 2.3, "unlock": "shaWujing", "next": "huangfeng"},
	"huangfeng": {"name": "黄风岭", "boss": "黄风大圣", "hp": 1900.0, "speed": 58.0, "tint": Color(0.85, 0.8, 0.35), "scale": 2.2, "unlock": "", "next": "wuzhuang", "behavior": "ranged"},
	"wuzhuang": {"name": "五庄观", "boss": "镇元子", "hp": 2100.0, "speed": 42.0, "tint": Color(0.55, 0.75, 0.55), "scale": 2.4, "unlock": "", "next": "pingding", "behavior": "pull"},
	"pingding": {"name": "平顶山", "boss": "金角大王", "hp": 2300.0, "speed": 48.0, "tint": Color(0.9, 0.7, 0.3), "scale": 2.4, "unlock": "", "next": "wuji", "behavior": "summon"},
	"wuji": {"name": "乌鸡国", "boss": "青毛狮子精", "hp": 2500.0, "speed": 64.0, "tint": Color(0.45, 0.55, 0.65), "scale": 2.5, "unlock": "", "next": "huoyun", "behavior": "charge", "charge_every": 2.4},
	"huoyun": {"name": "火云洞", "boss": "红孩儿", "hp": 2700.0, "speed": 56.0, "tint": Color(1.0, 0.45, 0.3), "scale": 2.0, "unlock": "", "next": "chesi", "behavior": "ranged", "ranged_every": 1.6},
	"chesi": {"name": "车迟国", "boss": "虎力大仙", "hp": 3000.0, "speed": 50.0, "tint": Color(0.9, 0.85, 0.6), "scale": 2.4, "unlock": "", "next": "heaven", "behavior": "slam", "slam_every": 3.5},
	"heaven": {"name": "天宫试炼", "boss": "二郎显圣真君", "hp": 3400.0, "speed": 66.0, "tint": Color(0.8, 0.85, 0.95), "scale": 2.4, "unlock": "nezha,erlang", "next": "tongtian", "behavior": "mirror"},
	"tongtian": {"name": "通天·凌云渡", "boss": "六耳猕猴", "hp": 4000.0, "speed": 74.0, "tint": Color(0.6, 0.5, 0.7), "scale": 2.2, "unlock": "", "next": "done", "behavior": "mirror"},
}
const TRIAL_CFG := {
	"dragonStory": {"name": "外传·龙族旧事", "goal": "护送：60 秒队友协力生存", "mods": ["allies_boost"], "time": 60.0},
	"baguaFurnace": {"name": "外传·八卦炉", "goal": "耐炼：60 秒全场火域灼烧", "mods": ["burn_env"], "time": 60.0},
	"fangcun": {"name": "外传·方寸山学艺", "goal": "修行：60 秒双倍经验", "mods": ["double_exp"], "time": 60.0},
	"underworld": {"name": "外传·幽冥地府", "goal": "镇魂：60 秒亡者复苏", "mods": ["revive_once"], "time": 60.0},
	"heavenHavoc": {"name": "外传·大闹天宫", "goal": "齐天：60 秒天兵精锐", "mods": ["elite_waves", "allies_boost"], "time": 60.0},
}
var chapter := "wuxing"
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
var fx_rings: Array = []
var bullets: Array = []       # Boss 弹：{pos, v, dmg, life}
var floaters: Array = []      # 伤害数字
var burst: Array = []         # 击杀爆点粒子
var hitstop := 0.0            # 命中顿帧
var shake := 0.0              # 震屏强度
var hitstop_total := 0.0      # {pos: Vector2, r: float, max: float, life: float, color: Color}
var boss: Node2D = null
var boss_spawned := false
var boss_tamed := false
var chapters_cleared := 0
var victory := false
var trial := {}                 # 当前副本（空=主线）
var trial_done := {}            # 完成标记
var trial_time_left := 0.0
var trial_menu_open := false
var trial_queue: Array = []       # G10 收尾：五外传副本逐个验证队列（测试钩子注入）
var trial_env := []             # 环境火域 {pos, r, until}
var env_cd := 0.0
var thunder_depth := 0
var sfx_pool := []
var unlocked := ["tang"]
var save_check := {}
var drafts_opened := 0
var pending_drafts := 0
var draft_log: Array = []     # 每次三选一的分类记录（审计用）
var structure_result := {}
var smoke := false
var smoke_spawn_mul := 1.0
var enemy_cap_hits := 0        # G10：敌人上限触发次数（诊断）
var smoke_max_frame := 0.0       # G10 诊断：最大实际帧间隔（秒，未含 time_scale）
var smoke_done := false
var deaths := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("main_ctl")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.seed = 20260907
	smoke = "--smoke" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--trial-queue="):
			trial_queue = arg.trim_prefix("--trial-queue=").split(",")
			print("[V1] trial queue set: " + str(trial_queue))
	for i in 6:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		sfx_pool.append(ap)
	_sfx("level", true)
	_build_world()
	_build_player()
	_build_hud()
	_build_draft()
	if smoke:
		# 冒烟隔离：清档全新开局，避免上轮存档把章节进度带进来
		var da := DirAccess.open("user://")
		if da:
			da.remove("w81_save.json")
	else:
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
		print("[V1] smoke ready: time_scale=6")

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
	player = PlayerScript.new()
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
	if Input.is_action_just_pressed("trials") and victory:
		trial_menu_open = not trial_menu_open
		if trial_menu_open:
			toast("外传试炼：1 龙族旧事 · 2 八卦炉 · 3 方寸山 · 4 地府 · 5 大闹天宫（数字键进入）")
	if trial_menu_open:
		for i in TRIAL_CFG.keys().size():
			if Input.is_key_pressed(KEY_1 + i) and not get_tree().paused:
				trial_menu_open = false
				start_trial(TRIAL_CFG.keys()[i])
				break
	elapsed += delta
	# 命中顿帧：冻结战斗推进（保留 HUD/特效），对齐 web 版 hitStop 手感
	if hitstop > 0.0:
		hitstop -= delta
		_shake_tick(delta)
		_visual_tick(delta)
		if camera:
			camera.offset = _shake_offset()
		return
	_spawn_tick(delta)
	_pickup_tick()
	_phantom_tick(delta)
	lbl_hp.text = "HP %d/%d" % [int(player.hp), int(player.max_hp)]
	lbl_exp.text = "Lv%d  EXP %d/%d" % [player.level, player.exp_pts, player.exp_next]
	var cards_txt := " · 卡牌 %d" % player.upgrades.size() if player.upgrades.size() > 0 else ""
	lbl_stats.text = "击杀 %d · 存活 %d · 波次 %d · %.0fs%s" % [player.kills, get_tree().get_nodes_in_group("enemies").size(), wave, elapsed, cards_txt]
	if not trial.is_empty():
		lbl_form.text = "【%s】剩余 %.0fs" % [TRIAL_CFG[trial["id"]]["name"], maxf(0.0, trial_time_left)]
		lbl_form.add_theme_color_override("font_color", Color("ffb84d"))
	elif player.in_form():
		lbl_form.text = "法相天象 · %.1fs · 终结 %d%%" % [player.form_left, int(player.ult)]
		lbl_form.add_theme_color_override("font_color", Color("ffd46b"))
	else:
		lbl_form.text = "法相 %d%% · 终结 %d%%" % [int(player.form_charge), int(player.ult)]
		lbl_form.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	_fx_tick(delta)
	_visual_tick(delta)
	_shake_tick(delta)
	if camera:
		camera.offset = _shake_offset()
	_trial_tick(delta)
	_boss_tick(delta)
	_bullet_tick(delta)
	_update_boss_hud()
	if smoke:
		var real_delta := delta / maxf(Engine.time_scale, 0.1)
		smoke_max_frame = maxf(smoke_max_frame, real_delta)
		if int(elapsed) / 10 != int(elapsed - delta) / 10:
			print("[V1] t=%.0f ch=%s trial=%s enemies=%d kills=%d maxframe=%.3f" % [elapsed, chapter, str(trial.keys()), get_tree().get_nodes_in_group("enemies").size(), player.kills, smoke_max_frame])
			smoke_max_frame = 0.0
		_smoke_tick()

var sfx_last_ms := {}
func _sfx(name: String, force := false) -> void:
	if name in ["burn", "tame"]:
		print("[V1] sfx: " + name)
	var now_ms := Time.get_ticks_msec()
	if name in ["hit", "pickup"] and now_ms - int(sfx_last_ms.get(name, -999)) < 80:
		return
	sfx_last_ms[name] = now_ms
	if trial.is_empty() and not force and name in ["hit", "pickup"]:
		return
	for ap in sfx_pool:
		if not ap.playing:
			ap.stream = SfxLib.get_sfx(name)
			ap.volume_db = -14.0
			ap.play()
			return

func _trial_tick(delta: float) -> void:
	if trial.is_empty():
		return
	trial_time_left -= delta
	if trial.has("burn_env"):
		env_cd -= delta
		if env_cd <= 0.0:
			env_cd = 7.0
			for i in 3:
				var ang := rng.randf_range(0.0, TAU)
				trial_env.append({"pos": player.global_position + Vector2(cos(ang), sin(ang)) * rng.randf_range(60.0, 180.0), "r": 90.0, "until": elapsed + 8.0})
			_sfx("burn")
	for env in trial_env.duplicate():
		if elapsed > env["until"]:
			trial_env.erase(env)
		elif player.global_position.distance_to(env["pos"]) < env["r"]:
			player.hp = maxf(0.0, player.hp - 6.0 * delta)
	if trial_time_left <= 0.0:
		var id: String = trial["id"]
		print("[V1] trial complete: " + id)
		trial_done[id] = true
		trial = {}
		trial_env.clear()
		toast("外传完成：%s！记录已存" % TRIAL_CFG[id]["name"])
		_sfx("tame", true)
		_write_save()
		print("[V1] trial save written: " + id)
	queue_redraw()

func set_trial_queue(ids: Array) -> void:
	trial_queue = ids.duplicate()

func start_trial(id: String) -> void:
	if not victory:
		toast("通关主线（通天）后解锁外传试炼")
		return
	trial = {"id": id}
	trial_time_left = float(TRIAL_CFG[id]["time"])
	get_tree().call_group("enemies", "queue_free")
	orbs.clear()
	toast("进入 %s：%s" % [TRIAL_CFG[id]["name"], TRIAL_CFG[id]["goal"]])
	_sfx("tame", true)

func _spawn_tick(delta: float) -> void:
	spawn_cd -= delta
	if spawn_cd > 0.0:
		return
	enemy_cap_hits += 1
	# G10 修复：场上敌人上限 90（冒烟 2.5x 密度下防止 200+ 敌人性能死亡螺旋）
	if get_tree().get_nodes_in_group("enemies").size() >= 90:
		return
	wave += 1
	var mul := smoke_spawn_mul * (1.6 if trial.has("elite_waves") else 1.0)
	spawn_cd = maxf(0.55, 1.4 - wave * 0.02) / mul
	var n := mini(int((1 + wave / 6) * mul), 16)
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
			player.gain_exp(2 if trial.has("double_exp") else 1)
			_sfx("pickup")
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
		var ally_fast: float = 0.4 if trial.has("allies_boost") else 0.8
		if g["next"] <= 0.0 and (player.lvl("w_72") > 0 or trial.has("allies_boost")):
			g["next"] = ally_fast
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


# ---------------- 打击感（顿帧/震屏/飘字/爆点） ----------------
func on_hit_feedback(pos: Vector2, dmg: float, heavy: bool) -> void:
	if hitstop > 0.0 and not heavy:
		return
	hitstop = 0.052 if heavy else 0.028
	hitstop_total += hitstop
	shake = maxf(shake, 9.0 if heavy else 4.0)
	if heavy or dmg >= 60.0 or true:
		floaters.append({"pos": pos + Vector2(randf_range(-6, 6), -10), "text": str(int(dmg)), "life": 0.6, "crit": dmg >= 100.0})

func on_kill_burst(pos: Vector2) -> void:
	for i in 6:
		burst.append({"pos": pos, "v": Vector2(cos(TAU * i / 6.0), sin(TAU * i / 6.0)) * randf_range(60, 140), "life": 0.35, "max": 0.35})
	shake = maxf(shake, 5.0)

func spawn_bullet(pos: Vector2, dir: Vector2, speed: float, dmg: float) -> void:
	bullets.append({"pos": pos, "v": dir * speed, "dmg": dmg, "life": 3.0})

func _bullet_tick(delta: float) -> void:
	for b in bullets.duplicate():
		b["pos"] += b["v"] * delta
		b["life"] -= delta
		if b["life"] <= 0.0 or not WORLD.has_point(b["pos"]):
			bullets.erase(b)
			continue
		if player.global_position.distance_to(b["pos"]) < 18.0:
			player.take_damage(b["dmg"], b["v"].normalized() * 70.0)
			bullets.erase(b)
	queue_redraw()

func summon_minions(center: Vector2, n: int) -> void:
	for i in n:
		var ang := TAU * i / float(n)
		_spawn_one(center + Vector2(cos(ang), sin(ang)) * 90.0)
	toast("妖风四起——Boss 召唤援军！")

func request_shake(s: float) -> void:
	shake = maxf(shake, s)

func _shake_tick(delta: float) -> void:
	shake = maxf(0.0, shake - 42.0 * delta)

func _shake_offset() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	return Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

func _visual_tick(delta: float) -> void:
	for f in floaters.duplicate():
		f["life"] -= delta
		f["pos"].y -= 26.0 * delta
		if f["life"] <= 0.0:
			floaters.erase(f)
	for b in burst.duplicate():
		b["life"] -= delta
		b["pos"] += b["v"] * delta
		b["v"] *= 0.90
		if b["life"] <= 0.0:
			burst.erase(b)
	queue_redraw()

func _draw() -> void:
	for orb in orbs:
		draw_rect(Rect2(orb["pos"] - Vector2(2, 2), Vector2(4, 4)), Color(0.45, 0.9, 1.0))
	for f in fx_rings:
		var c: Color = f["color"]
		c.a = clampf(f["life"] / 0.38, 0.0, 1.0) * 0.8
		draw_arc(f["pos"], f["r"], 0, TAU, 40, c, 3.0)
	for b in burst:
		var a: float = clampf(b["life"] / float(b["max"]), 0.0, 1.0)
		draw_rect(Rect2(b["pos"] - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.85, 0.5, a))
	for bl in bullets:
		draw_rect(Rect2(bl["pos"] - Vector2(3, 3), Vector2(6, 6)), Color(0.95, 0.5, 0.4))
	for env in trial_env:
		draw_arc(env["pos"], env["r"], 0, TAU, 32, Color(1.0, 0.45, 0.25, 0.5), 4.0)
	var fnt := ThemeDB.fallback_font
	for f in floaters:
		var a2: float = clampf(f["life"] / 0.6, 0.0, 1.0)
		var col := Color("ffe27a") if not f["crit"] else Color("ff9e7a")
		col.a = a2
		draw_string(fnt, f["pos"] - Vector2(-2, 0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

func on_enemy_died(pos: Vector2) -> void:
	player.on_kill_charge()
	_sfx("hit", true)
	on_kill_burst(pos)
	orbs.append({"pos": pos})
	# 雷霆天罚：击杀雷击 80px 内敌人（深度护栏：防连锁击杀无限递归栈溢出）
	if player.lvl("thunder") > 0 and thunder_depth < 3:
		thunder_depth += 1
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(pos) < 80.0:
				e.take_hit(20.0 + 10.0 * player.lvl("thunder"), Vector2.ZERO)
		thunder_depth -= 1
	queue_redraw()

# ---------------- Boss / 收服 ----------------
func _boss_tick(delta: float) -> void:
	if smoke:
		if boss_spawned and boss != null and not boss.is_ally and elapsed - _boss_seen_at > 1.2:
			boss.take_hit(9999.0, Vector2.ZERO)
		if boss_tamed and player.switch_count < chapters_cleared:
			try_switch_hero()
		if victory and trial.is_empty():
			if trial_queue.size() > 0:
				start_trial(trial_queue.pop_front())
			elif trial_done.size() == 0:
				start_trial("baguaFurnace")
	if not boss_spawned and elapsed >= 8.0:
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

var _boss_seen_at := 0.0
func _spawn_boss() -> void:
	boss_spawned = true
	_boss_seen_at = elapsed
	var cfg: Dictionary = CHAPTER_CFG[chapter]
	boss = Node2D.new()
	boss.set_script(BossScript)
	boss.position = player.global_position + Vector2(220, -120)
	add_child(boss)
	boss.setup(self, cfg)
	toast("%s·%s 现身！打至残血后按 F 收服（不是击杀）" % [cfg["name"], cfg["boss"]])

func on_boss_tame_ready() -> void:
	toast("石猿王力竭：靠近按 F 收服！")

func on_boss_tamed(unlocked_hero: String = "wukong") -> void:
	boss_tamed = true
	chapters_cleared += 1
	var gained := []
	for uh in str(unlocked_hero).split(","):
		uh = uh.strip_edges()
		if uh != "" and Cards.HERO_STATS.has(uh) and not unlocked.has(uh):
			unlocked.append(uh)
			gained.append(Cards.HERO_STATS[uh]["name"])
	var join_msg := "收服 %s！" % CHAPTER_CFG[chapter]["boss"]
	if gained.size() > 0:
		join_msg += "%s 归位，队伍 +1" % "、".join(gained)
	toast(join_msg)
	get_tree().call_group("enemies", "queue_free")
	var next: String = CHAPTER_CFG[chapter]["next"]
	_write_save()
	if next == "done":
		victory = true
		toast("取经队伍集结完毕！按 B 开启外传试炼")
	else:
		chapter = next
		boss = null
		boss_spawned = false
		toast("进入下一章：%s" % CHAPTER_CFG[chapter]["name"])

func _update_boss_hud() -> void:
	if boss == null or boss.is_ally:
		lbl_boss.visible = false
		return
	lbl_boss.visible = true
	var frac: float = boss.hp / boss.max_hp
	var bar := ""
	var filled := int(24.0 * frac)
	for i in 24:
		bar += "█" if i < filled else "░"
	lbl_boss.text = "%s P%d  %s  %d%%%s" % [boss.boss_name, boss.phase, bar, int(frac * 100), "  · 可收服！" if boss.tame_ready else ""]

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
	data["trials_done"] = trial_done
	Save.write(data)

func try_switch_hero() -> void:
	var order: Array = Cards.HERO_ORDER.filter(func(h): return unlocked.has(h))
	if order.size() < 2:
		toast("收服更多同伴后才能切换（当前仅唐僧）")
		return
	var i := order.find(player.hero)
	player.set_hero(order[(i + 1) % order.size()])

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
	var td = d.get("trials_done", {})
	if td is Dictionary:
		trial_done = td
	var cards: Dictionary = d.get("cards", {})
	for k in cards.keys():
		player.upgrades[str(k)] = int(cards[k])
	toast("读取存档：章节 %s · 卡牌 %d 张" % [chapter, cards.size()])

# ---------------- 三选一 ----------------
func _on_leveled() -> void:
	if draft_ui.visible:
		if pending_drafts < 3:
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
	if smoke_done or elapsed < 72.0:
		return
	# G10 收尾：victory 后自动驾驶按队列逐个开启外传（各 60s）——等全部副本完成再评估
	if victory and trial_done.size() < 5 and elapsed < 400.0:
		return
	if victory and trial_done.size() < 5:
		print("[V1] trial verification incomplete at cap: " + str(trial_done.keys()))
	print("[V1] smoke tick enter: elapsed=%.0f trial_done=%s" % [elapsed, str(trial_done.keys())])
	smoke_done = true
	var ok: bool = player.kills >= 5 and player.atk_count >= 10 and drafts_opened >= 2 \
		and player.upgrades.size() >= 2 and int(structure_result["fails"]) == 0 \
		and player.q_count >= 3 and player.e_count >= 2 \
		and player.g_count >= 1 \
		and player.form_count >= 1 and player.ult_count >= 1 \
		and boss_spawned and chapters_cleared >= 10 \
		and unlocked.size() >= 7 and victory \
		and trial_done.has("baguaFurnace") \
		and get_tree().get_nodes_in_group("allies").size() >= 1 \
		and bool(save_check["ok"]) \
		and unlocked.size() >= 2 and player.switch_count >= 1 \
		and hitstop_total > 0.3
	_finish_smoke(ok)

func _finish_smoke(passed: bool) -> void:
	print("[V1] finish_smoke enter, passed=" + str(passed))
	Engine.time_scale = 1.0
	var shot := "unavailable(headless)"
	if DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		if img:
			img.save_png("res://evidence/smoke.png")
			shot = "saved"
	var result := {
		"pass": passed, "kills": player.kills, "atk_count": player.atk_count,
		"q_count": player.q_count, "e_count": player.e_count, "g_count": player.g_count,
		"form_count": player.form_count, "ult_count": player.ult_count,
		"boss_spawned": boss_spawned, "boss_tamed": boss_tamed,
		"chapter": chapter, "chapters_cleared": chapters_cleared, "victory": victory,
		"allies": get_tree().get_nodes_in_group("allies").size(), "save_check": save_check,
		"hero": player.hero, "unlocked": unlocked, "switches": player.switch_count,
		"trial_done": trial_done,
		"hitstop_total_s": snappedf(hitstop_total, 0.2), "floaters_spawned": floaters.size(),
		"level": player.level, "deaths": deaths, "wave": wave,
		"chapter_now": chapter, "cards_owned": player.upgrades,
		"draft_log": draft_log, "structure_check": structure_result,
		"elapsed_s": snappedf(elapsed, 0.1), "screenshot": shot,
	}
	print("[V1] finish_smoke writing json")
	var f := FileAccess.open("res://evidence/smoke-result.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "  "))
		f.close()
	else:
		# evidence/ 目录缺失时不得阻断退出——否则冒烟进程会以 6 倍速无限运行
		print("[V1] WARN: cannot write smoke-result.json (res://evidence/ missing)")
	print("SMOKE_RESULT ", JSON.stringify(result))
	get_tree().quit(0 if passed else 1)
