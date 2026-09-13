extends SceneTree
## M2 真动画升级 · 实况录像舞台（带窗 + --write-movie 录制到 evidence/）
## 用法：Godot_console --path . -s tests/kf_stage.gd --write-movie evidence/<步骤名>.avi -- --title=标题
## 复用真实 player.gd/keyframe_lib.gd，配桩主循环（顿帧/震屏/特效/飘字）与两个木桩敌人，
## 依次演示 7 英雄的 idle/run/flip/Q/E/冲刺/法相/终结，供负责人目测动画观感。

const HEROES := ["tang", "wukong", "whiteDragon", "bajie", "shaWujing", "nezha", "erlang"]
const NAMES := {"tang": "唐僧", "wukong": "悟空", "whiteDragon": "小白龙", "bajie": "八戒",
	"shaWujing": "沙僧", "nezha": "哪吒", "erlang": "杨戬"}

var p: CharacterBody2D
var cam: Camera2D
var lbl_title: Label
var lbl_state: Label

func _initialize() -> void:
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	var title := "M2 真动画升级"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--title="):
			title = arg.trim_prefix("--title=")
	var world := Node2D.new()
	world.name = "KFStage"
	root.add_child(world)
	var stub := StubMain.new()
	stub.stage = self
	world.add_child(stub)
	p = preload("res://scripts/player.gd").new()
	p.position = Vector2(320.0, 240.0)
	world.add_child(p)
	p.main = stub
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	p.add_child(cam)
	cam.make_current()
	for off in [Vector2(112.0, 0.0), Vector2(-112.0, -26.0)]:
		var d := Dummy.new()
		d.position = p.position + off
		world.add_child(d)
	var hud := CanvasLayer.new()
	hud.layer = 10
	world.add_child(hud)
	lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.position = Vector2(8, 330)
	lbl_title.add_theme_font_size_override("font_size", 11)
	lbl_title.add_theme_color_override("font_color", Color("ffe9a8"))
	hud.add_child(lbl_title)
	lbl_state = Label.new()
	lbl_state.position = Vector2(8, 6)
	lbl_state.add_theme_font_size_override("font_size", 11)
	lbl_state.add_theme_color_override("font_color", Color("9adcff"))
	hud.add_child(lbl_state)
	await _wait(0.8)
	for h in HEROES:
		await _hero_pass(h)
	await _wait(0.6)
	print("KF_STAGE done")
	quit(0)

func _hero_pass(h: String) -> void:
	lbl_state.text = "%s · %s" % [NAMES[h], h]
	p.set_hero(h)
	await _wait(0.8)
	Input.action_press("move_right")
	await _wait(0.9)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _wait(0.55)
	Input.action_release("move_left")
	await _wait(0.15)
	p._cast_q()
	await _wait(0.85)
	p._cast_e()
	await _wait(0.85)
	p._do_dash(Vector2.RIGHT)
	await _wait(0.55)
	if h in ["tang", "whiteDragon"]:
		p._cast_g()
		await _wait(1.0)
	p.add_form_charge(100.0)
	await _wait(1.3)
	p.ult = 100.0
	p._cast_ult()
	await _wait(1.5)
	p._exit_form()
	await _wait(0.5)

## 桩主循环：对齐 main.gd 的视觉接口（顿帧/震屏/光环/飘字/残影），不改战斗数值
class StubMain extends Node2D:
	var stage: SceneTree
	var rng := RandomNumberGenerator.new()
	var hitstop := 0.0
	var shake := 0.0
	var fx_rings: Array = []
	var floaters: Array = []
	var ghosts: Array = []

	func _ready() -> void:
		rng.seed = 20260913
		set_process(true)

	func _process(delta: float) -> void:
		if stage and stage.p != null:
			if stage.p.kf_slug != "":
				var a := str(stage.p.kf_action)
				stage.lbl_state.text = stage.lbl_state.text.split(" · ")[0] + " · " + (a if a != "" else "(回落)")
		if hitstop > 0.0:
			hitstop -= delta
			_shake_tick(delta)
			_visual_tick(delta)
			return
		_shake_tick(delta)
		_visual_tick(delta)
		for g in ghosts.duplicate():
			g["life"] -= delta
			g["node"].modulate.a = maxf(0.0, minf(0.6, g["life"] * 2.0))
			if g["life"] <= 0.0:
				g["node"].queue_free()
				ghosts.erase(g)
		if stage and stage.cam != null:
			stage.cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.0 else Vector2.ZERO
		queue_redraw()

	func toast(msg: String) -> void:
		print("[STAGE] " + msg)

	func spawn_fx(pos: Vector2, r: float, color: Color) -> void:
		fx_rings.append({"pos": pos, "r": 12.0, "max": r, "life": 0.38, "color": color})
		queue_redraw()

	func request_shake(s: float) -> void:
		shake = maxf(shake, s)

	func spawn_phantom(pos: Vector2, flip: bool, tex: Texture2D = null, scl := Vector2.ONE, life := -1.0) -> void:
		var g := Sprite2D.new()
		if tex != null:
			g.texture = tex
			g.flip_h = flip
			g.scale = scl
			g.z_index = -1
		else:
			g.texture = SpriteLib.frame_tex(Vector2i(2, 0))
			g.flip_h = flip
			g.z_index = -1
		g.position = pos
		g.modulate = Color(1.0, 0.94, 0.63, 0.6)
		add_child(g)
		ghosts.append({"node": g, "life": 0.3 if life <= 0.0 else life})

	func on_hit_feedback(pos: Vector2, dmg: float, heavy: bool) -> void:
		if hitstop > 0.0 and not heavy:
			return
		hitstop = 0.052 if heavy else 0.028
		shake = maxf(shake, 9.0 if heavy else 4.0)
		floaters.append({"pos": pos + Vector2(randf_range(-6, 6), -10), "text": str(int(dmg)), "life": 0.6, "crit": dmg >= 100.0})

	func _shake_tick(delta: float) -> void:
		shake = maxf(0.0, shake - 42.0 * delta)

	func _visual_tick(delta: float) -> void:
		for f in floaters.duplicate():
			f["life"] -= delta
			f["pos"].y -= 26.0 * delta
			if f["life"] <= 0.0:
				floaters.erase(f)
		for f in fx_rings.duplicate():
			f["life"] -= delta
			f["r"] = lerpf(f["max"], 12.0, f["life"] / 0.38)
			if f["life"] <= 0.0:
				fx_rings.erase(f)

	func _draw() -> void:
		draw_rect(Rect2(-600, -400, 1840, 1160), Color(0.07, 0.09, 0.13))
		draw_rect(Rect2(40, 60, 560, 360), Color(0.10, 0.13, 0.18))
		draw_line(Vector2(40, 320), Vector2(600, 320), Color(0.25, 0.3, 0.38), 2.0)
		for f in fx_rings:
			var c: Color = f["color"]
			c.a = clampf(f["life"] / 0.38, 0.0, 1.0) * 0.8
			draw_arc(f["pos"], f["r"], 0, TAU, 40, c, 3.0)
		var fnt := ThemeDB.fallback_font
		for f in floaters:
			var a: float = clampf(f["life"] / 0.6, 0.0, 1.0)
			var col := Color("ffe27a") if not f["crit"] else Color("ff9e7a")
			col.a = a
			draw_string(fnt, f["pos"] - Vector2(-2, 0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

## 木桩敌人：站桩承击（hit_r/hp/take_hit），供自动攻击与技能演出有目标
class Dummy extends Node2D:
	var hit_r := 22.0
	var hp := 999999.0
	var flash := 0.0

	func _ready() -> void:
		add_to_group("enemies")

	func _process(delta: float) -> void:
		flash = maxf(0.0, flash - delta)
		queue_redraw()

	func take_hit(dmg: float, knock: Vector2) -> void:
		hp -= dmg
		flash = 0.12
		position += knock * 0.05
		position = position.clamp(Vector2(140, 100), Vector2(500, 400))

	func _draw() -> void:
		var c := Color(0.45, 0.5, 0.6) if flash <= 0.0 else Color(1.0, 0.6, 0.5)
		draw_rect(Rect2(-12, -34, 24, 48), c)
		draw_rect(Rect2(-12, -42, 24, 6), Color(0.3, 0.34, 0.4))
		draw_line(Vector2(-12, 20), Vector2(12, 20), Color(0.2, 0.24, 0.3), 3.0)
