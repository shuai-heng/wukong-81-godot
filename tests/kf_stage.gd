extends SceneTree
## M2 返工（R3）· 完整技能释放 实况录像舞台（带窗 + --write-movie 录制到 evidence/）
## 用法：Godot_console --path . -s tests/kf_stage.gd --write-movie evidence/<名>.avi -- --title=标题
## 复用真实 player.gd/keyframe_lib.gd/main 式特效系统，配 tiled 地面与木桩敌人，
## 依次演示 7 英雄：起手蓄力（锚点光点）→ 释放帧结算 → 弹体轨迹 → 命中冲击 → 地图反馈（尘土/焦痕/预告圈）。

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
	var title := "R3 完整技能释放：起手→锚点生成→轨迹→命中→地图反馈"
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
	for off in [Vector2(150.0, -14.0), Vector2(210.0, 40.0), Vector2(-130.0, -30.0)]:
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
	await _wait(0.8)
	print("KF_STAGE done")
	quit(0)

func _hero_pass(h: String) -> void:
	lbl_state.text = "%s · %s" % [NAMES[h], h]
	p.set_hero(h)
	await _wait(0.7)
	Input.action_press("move_right")
	await _wait(0.7)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _wait(0.35)
	Input.action_release("move_left")
	await _wait(0.2)
	p.sprite.flip_h = false   # 面向右侧木桩演示技能全链条
	p._cast_q()
	await _wait(1.25)         # 起手（蓄力光点）+ 释放 + 命中反馈
	p._cast_e()
	await _wait(1.25)         # 落点预告圈 → 砸落 → 尘土焦痕
	p._do_dash(Vector2.RIGHT)
	await _wait(0.45)
	if h in ["tang", "whiteDragon"]:
		p._cast_g()
		await _wait(0.9)
	if h == "wukong":
		p.add_form_charge(100.0)
		await _wait(1.2)
		p.ult = 100.0
		p._cast_ult()
		await _wait(1.4)
		p._exit_form()
		await _wait(0.4)

## 桩主循环：对齐 main.gd 的视觉接口（顿帧/震屏/环/飘字/残影 + R3 弹体/尘土/焦痕/预告圈）
class StubMain extends Node2D:
	var stage: SceneTree
	var rng := RandomNumberGenerator.new()
	var hitstop := 0.0
	var shake := 0.0
	var fx_rings: Array = []
	var floaters: Array = []
	var ghosts: Array = []
	var fx_shots: Array = []
	var fx_dust: Array = []
	var fx_decals: Array = []
	var fx_marks: Array = []

	func _ready() -> void:
		rng.seed = 20260913
		set_process(true)

	func _process(delta: float) -> void:
		if stage and stage.p != null:
			if stage.p.kf_slug != "":
				var a := str(stage.p.kf_action)
				var phase := "蓄力" if float(stage.p.kf_release_t) >= 0.0 else ""
				stage.lbl_state.text = stage.lbl_state.text.split(" · ")[0] + " · " + (a if a != "" else "(回落)") + ("·" + phase if phase != "" else "")
		if hitstop > 0.0:
			hitstop -= delta
			_shake_tick(delta)
			_visual_tick(delta)
			return
		_shake_tick(delta)
		_visual_tick(delta)
		_fx_tick(delta)
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

	func spawn_skill_shot(from: Vector2, to: Vector2, dur: float, color: Color, r := 9.0, on_arrive: Callable = Callable()) -> void:
		fx_shots.append({"pos": from, "from": from, "to": to, "t": 0.0, "dur": maxf(dur, 0.04), "color": color, "r": r, "on_arrive": on_arrive})

	func spawn_dust(pos: Vector2, r: float, n := 4) -> void:
		for i in n:
			var ang := rng.randf_range(0.0, TAU)
			fx_dust.append({"pos": pos + Vector2(cos(ang), sin(ang) * 0.42) * r * 0.55,
				"r": rng.randf_range(r * 0.35, r * 0.8), "life": 0.5, "max": 0.5,
				"vx": cos(ang) * 26.0, "vy": -rng.randf_range(14.0, 34.0)})

	func spawn_decal(pos: Vector2, r: float, color: Color) -> void:
		fx_decals.append({"pos": pos + Vector2(0, 4), "r": r, "life": 2.6, "max": 2.6, "color": color})

	func spawn_ground_mark(pos: Vector2, r: float, life: float, color: Color) -> void:
		fx_marks.append({"pos": pos, "r": r, "life": maxf(life, 0.05), "max": maxf(life, 0.05), "color": color})

	func spawn_impact(pos: Vector2, r: float, color: Color) -> void:
		spawn_fx(pos, r * 0.9, color)
		spawn_dust(pos, minf(r, 90.0), 6)
		spawn_decal(pos, minf(r, 80.0), color)

	func _fx_tick(delta: float) -> void:
		for s in fx_shots.duplicate():
			s["t"] = float(s["t"]) + delta
			var sfrom: Vector2 = s["from"]
			var sto: Vector2 = s["to"]
			var k: float = clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
			s["pos"] = sfrom.lerp(sto, 1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				var cb: Callable = s["on_arrive"]
				fx_shots.erase(s)
				if cb.is_valid():
					cb.call()
		for d in fx_dust.duplicate():
			d["life"] = float(d["life"]) - delta
			var dp: Vector2 = d["pos"]
			dp.x += float(d["vx"]) * delta
			dp.y += float(d["vy"]) * delta
			d["pos"] = dp
			if float(d["life"]) <= 0.0:
				fx_dust.erase(d)
		for dc in fx_decals.duplicate():
			dc["life"] = float(dc["life"]) - delta
			if float(dc["life"]) <= 0.0:
				fx_decals.erase(dc)
		for mk in fx_marks.duplicate():
			mk["life"] = float(mk["life"]) - delta
			if float(mk["life"]) <= 0.0:
				fx_marks.erase(mk)

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
		# 地图：双色 tiled 地面 + 碎石点（技能地图反馈的载体）
		for iy in 16:
			for ix in 23:
				var v := (ix * 7 + iy * 13) % 3
				var c := Color(0.10, 0.13, 0.17) if v == 0 else (Color(0.12, 0.15, 0.20) if v == 1 else Color(0.11, 0.14, 0.185))
				draw_rect(Rect2(-600 + ix * 52, -400 + iy * 52, 52, 52), c)
				if v == 2:
					draw_circle(Vector2(-600 + ix * 52 + 26, -400 + iy * 52 + 30), 2.2, Color(0.16, 0.19, 0.24))
		draw_rect(Rect2(-600, -400, 1840, 1160), Color(0.05, 0.07, 0.1), false, 2.0)
		# 地面层：焦痕 / 预告圈 / 尘土
		for dc in fx_decals:
			var da: float = clampf(float(dc["life"]) / float(dc["max"]), 0.0, 1.0)
			var dpos: Vector2 = dc["pos"]
			var dcol: Color = dc["color"]
			dcol = Color(dcol.r * 0.30 + 0.04, dcol.g * 0.24 + 0.03, dcol.b * 0.20 + 0.03, 0.36 * da)
			draw_set_transform(dpos + Vector2(0, 3), 0.0, Vector2(1.0, 0.42))
			draw_circle(Vector2.ZERO, float(dc["r"]), dcol)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for mk in fx_marks:
			var mpos: Vector2 = mk["pos"]
			var lf: float = clampf(float(mk["life"]) / float(mk["max"]), 0.0, 1.0)
			var mcol: Color = mk["color"]
			mcol.a = (0.28 + 0.5 * (1.0 - lf)) * (0.55 + 0.45 * absf(sin(float(mk["life"]) * 9.0)))
			draw_arc(mpos, float(mk["r"]), 0, TAU, 40, mcol, 2.0)
			var mcol2: Color = mcol
			mcol2.a *= 0.55
			draw_arc(mpos, float(mk["r"]) * lf, 0, TAU, 32, mcol2, 1.5)
		for d in fx_dust:
			var dfa: float = clampf(float(d["life"]) / float(d["max"]), 0.0, 1.0)
			var fdpos: Vector2 = d["pos"]
			draw_circle(fdpos, float(d["r"]) * (1.0 + 0.5 * (1.0 - dfa)), Color(0.78, 0.74, 0.66, 0.35 * dfa))
		# 技能弹体
		for s in fx_shots:
			var spos: Vector2 = s["pos"]
			var sto: Vector2 = s["to"]
			var scol: Color = s["color"]
			var dirv: Vector2 = sto - spos
			if dirv.length() > 1.0:
				dirv = dirv.normalized()
				var tail: Vector2 = spos - dirv * 26.0
				draw_line(tail, spos, Color(scol.r, scol.g, scol.b, 0.4), float(s["r"]) * 0.7)
				draw_line(tail - dirv * 14.0, tail, Color(scol.r, scol.g, scol.b, 0.18), float(s["r"]) * 0.4)
			draw_circle(spos, float(s["r"]) * 1.7, Color(scol.r, scol.g, scol.b, 0.35))
			draw_circle(spos, float(s["r"]), Color(1.0, 1.0, 1.0, 0.9))
		# 扩散环 / 飘字
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
		position = position.clamp(Vector2(140, 100), Vector2(540, 400))

	func apply_burn(bl: int, dur: float) -> void:
		flash = 0.2

	func apply_frost(dur: float, slow: float) -> void:
		flash = 0.16

	func has_dragon() -> bool:
		return false

	func _draw() -> void:
		draw_set_transform(Vector2(0, 26), 0.0, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, 15.0, Color(0.0, 0.0, 0.0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var c := Color(0.45, 0.5, 0.6) if flash <= 0.0 else Color(1.0, 0.6, 0.5)
		draw_rect(Rect2(-12, -34, 24, 48), c)
		draw_rect(Rect2(-12, -42, 24, 6), Color(0.3, 0.34, 0.4))
		draw_line(Vector2(-12, 20), Vector2(12, 20), Color(0.2, 0.24, 0.3), 3.0)
