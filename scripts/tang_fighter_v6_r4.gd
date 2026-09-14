class_name TangFighterV6R4
extends TangFighterV6R3

## R4：唐僧“纯人物动作层”。
## 目标不是新增技能数值，而是把 R3 已经正确的 projectile/contact 逻辑，
## 绑定到真正符合远程法师身份的现有 V6 Pose 上。
##
## 硬规则：
## - 不改伤害/CD/护盾/净化/法相数值；
## - 不修改全局 V6.1 1322 帧映射，避免影响其他角色；
## - 唐僧运行时只从现有 36 Pose 中挑选低污染人物姿势；
## - 普攻/Q/E/G 禁止使用 14–18 的近战挥杖姿势与 19–29 的大块烘焙技能板；
## - run 明确禁用横飞的 POSE_06；
## - 法相/终结只使用 POSE_31 + POSE_36，禁用巨大莲花 POSE_35；
## - 人物与技能仍共用 KeyframeLib.kf_t；这里只重映射“同一时刻该显示哪张人物 Pose”。

const POSE_ROOT := "res://art/v6_pose/tang_sanzang/"
const POSE_CLEAN_ROOT := "res://art/v6_pose_clean/tang_sanzang/"
const POSE_FILES := {
	1: "tang_sanzang__POSE_01__R1C1.png",
	2: "tang_sanzang__POSE_02__R1C2.png",
	3: "tang_sanzang__POSE_03__R1C3.png",
	4: "tang_sanzang__POSE_04__R1C4.png",
	5: "tang_sanzang__POSE_05__R1C5.png",
	13: "tang_sanzang__POSE_13__R3C1.png",
	31: "tang_sanzang__POSE_31__R6C1.png",
	36: "tang_sanzang__POSE_36__R6C6.png",
}

# 这些持续时间直接来自现有 V6.1 Tang action timeline；R4 不建立第二套技能时钟。
const ACTION_DURATION := {
	"idle": .900,
	"run": .820,
	"normal": .900,
	"q": 1.400,
	"e": 1.500,
	"g": 1.800,
	"form": 1.900,
	"r": 2.800,
}

# 每个保留 Pose 的掌心/施法端点，坐标为原 256×256 Pose 的归一化位置。
# x 会随 flip_h 镜像；再乘当前 Sprite2D scale/rotation，因此不是 player.position 固定偏移。
const PALM_UV := {
	1: Vector2(.60, .58),
	2: Vector2(.50, .55),
	3: Vector2(.72, .63),
	4: Vector2(.67, .61),
	5: Vector2(.69, .60),
	13: Vector2(.62, .61),
	31: Vector2(.55, .56),
	36: Vector2(.55, .56),
}

const BASE_SCALE := .34
const FORM_SCALE := .38
const R_SCALE := .37
const POSE_FADE := .055

var _r4_mode := ""
var _r4_pose_id := 1
var _r4_last_pose_id := -1
var _r4_tex_cache := {}
var _r4_fade: Sprite2D
var _r4_fade_left := 0.0

func _ready() -> void:
	super()
	_r4_fade = Sprite2D.new()
	_r4_fade.name = "TangR4PoseFade"
	_r4_fade.visible = false
	_r4_fade.z_index = 1
	add_child(_r4_fade)

func set_hero(h: String) -> void:
	super(h)
	if h != "tang":
		_r4_mode = ""
		_r4_pose_id = 1
		_r4_last_pose_id = -1
		if _r4_fade != null:
			_r4_fade.visible = false

func tick(dt: float, input_enabled: bool=true) -> void:
	super(dt, input_enabled)
	if hero != "tang" or kf_slug == "" or kf_sprite == null:
		return
	# 父级 V6 的 crossfade/glow 会携带旧 V6.1 Pose；R4 禁止它们把近战/大技能板漏回画面。
	if kf_fade_sprite != null:
		kf_fade_sprite.visible = false
		kf_xfade_left = 0.0
	if kf_glow_sprite != null:
		kf_glow_sprite.visible = false
	_apply_r4_visual(dt)
	queue_redraw()

# ====================== 同一动作时钟上的 Tang 专属人物 Pose ======================
func _r4_current_mode() -> String:
	if _r4_mode != "" and kf_one_shot and kf_action != "":
		return _r4_mode
	if _r4_mode != "" and (kf_action == "" or not kf_one_shot):
		_r4_mode = ""
	if form_left > 0.0:
		return "form"
	return "run" if move_vector.length_squared() > .01 or dash_left > 0.0 else "idle"

func _r4_phase(mode: String) -> float:
	var dur := float(ACTION_DURATION.get(mode, 1.0))
	if dur <= .001:
		return 0.0
	if mode in ["idle", "run", "form"]:
		return fmod(maxf(0.0, kf_t), dur) / dur
	return clampf(kf_t / dur, 0.0, 1.0)

func _r4_pose_for(mode: String, p: float) -> int:
	match mode:
		"idle":
			# 大部分时间持杖站立，循环末端短暂合掌，不再无意义频繁变身。
			return 1 if p < .78 else 2
		"run":
			# 明确排除 POSE_06 横飞。3→4→5→4→3 构成地面跑步循环。
			if p < .16: return 3
			if p < .38: return 4
			if p < .64: return 5
			if p < .86: return 4
			return 3
		"normal":
			# 远程平A：持杖定身 → 合掌 → 袖手前送 → 合掌 → 回位；禁止 14–18 挥杖近战。
			if p < .15: return 13
			if p < .34: return 2
			if p < .72: return 3
			if p < .88: return 2
			return 13
		"q":
			# 掌印镇压：合掌聚印 → 袖手推出 → 收掌。
			if p < .18: return 2
			if p < .70: return 3
			if p < .90: return 2
			return 13
		"e":
			# 袈裟护持不需要“举巨大盾”；身体只做合掌/挺身，袈裟线由程序 VFX 承担。
			if p < .28: return 2
			if p < .68: return 13
			if p < .90: return 2
			return 1
		"g":
			# 持续诵经：合掌 → 袖手前引 → 合掌持势；弹幕由 world-space 念珠承担。
			if p < .22: return 2
			if p < .66: return 3
			if p < .90: return 2
			return 13
		"r":
			# 终结：法身收束 → 悬空诵经释放 → 收束。避开 32/33/34/35 大块烘焙板。
			if p < .18: return 31
			if p < .74: return 36
			if p < .91: return 31
			return 36
		"form":
			# 常驻法相本体保持清楚的人形，法身投影由 _sync_form_echo() 单独形成。
			return 31
		_:
			return 1

func _apply_r4_visual(dt: float) -> void:
	var mode := _r4_current_mode()
	var phase := _r4_phase(mode)
	var pose_id := _r4_pose_for(mode, phase)
	var tex := _r4_pose_tex(pose_id)
	if tex == null:
		return

	if pose_id != _r4_last_pose_id:
		_snapshot_r4_fade()
		_r4_last_pose_id = pose_id
	_r4_pose_id = pose_id

	kf_sprite.texture = tex
	kf_sprite.visible = true
	sprite.visible = false
	kf_sprite.flip_h = sprite.flip_h
	kf_sprite.modulate = sprite.modulate

	var sign_x := -1.0 if kf_sprite.flip_h else 1.0
	var s := BASE_SCALE
	var off := Vector2(0, -4)
	var rot := 0.0
	match mode:
		"idle":
			off.y += sin(phase * TAU) * 1.0
		"run":
			off.x += sin(phase * TAU) * 2.3 * sign_x
			off.y += -abs(sin(phase * TAU)) * 1.7
			rot = deg_to_rad(sin(phase * TAU) * 1.15) * sign_x
		"normal":
			off.x += sin(phase * PI) * 3.6 * sign_x
			off.y -= sin(phase * PI) * 1.2
			rot = deg_to_rad(-1.8 * sin(phase * PI)) * sign_x
		"q":
			off.x += sin(phase * PI) * 2.8 * sign_x
			off.y -= sin(phase * PI) * 1.0
		"e":
			s *= 1.02 + sin(phase * PI) * .025
		"g":
			off.y -= sin(phase * PI) * 2.0
		"form":
			s = FORM_SCALE
			off.y = -7 + sin(phase * TAU) * 1.1
		"r":
			s = R_SCALE
			off.y = -8 - sin(phase * PI) * 2.0

	kf_sprite.position = off
	kf_sprite.rotation = rot
	kf_sprite.scale = Vector2.ONE * s
	_update_r4_fade(dt)

func _snapshot_r4_fade() -> void:
	if _r4_fade == null or kf_sprite == null or kf_sprite.texture == null or _r4_last_pose_id < 0:
		return
	_r4_fade.texture = _r4_pose_tex(_r4_last_pose_id)
	_r4_fade.flip_h = kf_sprite.flip_h
	_r4_fade.position = kf_sprite.position
	_r4_fade.rotation = kf_sprite.rotation
	_r4_fade.scale = kf_sprite.scale
	var m := sprite.modulate
	_r4_fade.modulate = Color(m.r, m.g, m.b, m.a)
	_r4_fade.visible = true
	_r4_fade_left = POSE_FADE

func _update_r4_fade(dt: float) -> void:
	if _r4_fade == null or not _r4_fade.visible:
		return
	_r4_fade_left = maxf(0.0, _r4_fade_left - dt)
	var a := _r4_fade_left / POSE_FADE
	var m := sprite.modulate
	_r4_fade.modulate = Color(m.r, m.g, m.b, m.a * a)
	if _r4_fade_left <= 0.0:
		_r4_fade.visible = false

func _r4_pose_tex(pose_id: int) -> Texture2D:
	if _r4_tex_cache.has(pose_id):
		return _r4_tex_cache[pose_id]
	var file := String(POSE_FILES.get(pose_id, ""))
	if file.is_empty():
		return null
	var clean := POSE_CLEAN_ROOT + file
	var base := POSE_ROOT + file
	var tex: Texture2D = null
	if ResourceLoader.exists(clean):
		tex = load(clean)
	elif ResourceLoader.exists(base):
		tex = load(base)
	if tex != null:
		_r4_tex_cache[pose_id] = tex
	return tex

# ====================== 真正跟当前人物 Pose 走的掌心锚点 ======================
func _r4_palm_local() -> Vector2:
	if kf_sprite == null:
		return Vector2.ZERO
	var uv: Vector2 = PALM_UV.get(_r4_pose_id, Vector2(.60, .58))
	var p := (uv - Vector2(.5, .5)) * 256.0
	if kf_sprite.flip_h:
		p.x = -p.x
	p = Vector2(p.x * kf_sprite.scale.x, p.y * kf_sprite.scale.y)
	p = p.rotated(kf_sprite.rotation)
	return kf_sprite.position + p

func _r4_palm_world() -> Vector2:
	# 在 release callback 同帧先同步一次当前 kf_t 对应 Pose，避免上一帧锚点残留。
	if hero == "tang" and kf_sprite != null:
		_apply_r4_visual(0.0)
	return to_global(_r4_palm_local())

func _spawn_spell(target_pos: Vector2, dmg: float, p_kind: String, opts := {}) -> void:
	var cfg := opts.duplicate()
	if not cfg.has("from"):
		cfg["from"] = _r4_palm_world()
	super(target_pos, dmg, p_kind, cfg)

# ====================== 把技能语义映射到同一个 kf_t ======================
func _auto(target) -> void:
	_r4_mode = "normal"
	super(target)

func _tang_q(target) -> void:
	_r4_mode = "q"
	super(target)

func _tang_e() -> void:
	_r4_mode = "e"
	super()

func _tang_g() -> void:
	_r4_mode = "g"
	super()

func _ultimate() -> bool:
	var ok := super()
	if ok and hero == "tang":
		_r4_mode = "r"
	return ok

# ====================== 法相：只用人形 Pose 31 + 悬空 Pose 36 ======================
func _sync_form_echo(dt: float) -> void:
	var now := hero == "tang" and form_left > 0.0
	if now and not _was_form:
		_form_birth = 0.0
	if not now:
		if _form_echo != null:
			_form_echo.visible = false
		_was_form = false
		return
	_was_form = true
	_form_birth = minf(1.0, _form_birth + dt / .58)
	if _form_echo == null:
		return
	var tex := _r4_pose_tex(36)
	if tex == null:
		_form_echo.visible = false
		return
	var eased := _form_birth * _form_birth * (3.0 - 2.0 * _form_birth)
	_form_echo.texture = tex
	_form_echo.flip_h = sprite.flip_h
	_form_echo.position = Vector2(0, -12 - 5 * eased)
	_form_echo.rotation = 0.0
	_form_echo.scale = Vector2.ONE * lerpf(.20, .54, eased)
	_form_echo.modulate = Color(1.0, .88, .48, .04 + .18 * eased)
	_form_echo.visible = true

# ====================== 只强化真实动作，不再画旧中心环/大图 ======================
func _draw() -> void:
	if hero != "tang":
		super()
		return
	# 地面阴影只说明站位，不参与技能。
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, .4))
	draw_circle(Vector2.ZERO, 17, Color(0, 0, 0, .34))
	draw_set_transform(Vector2.ZERO)
	var primary := HeroIdentity.primary("tang")
	var secondary := HeroIdentity.secondary("tang")
	var palm := _r4_palm_local()
	var clock := kf_t
	var pre_release := kf_release_t >= 0.0

	if pre_release and kf_sprite != null and kf_sprite.visible:
		match _r4_mode:
			"q":
				var rr := 7.0 + 3.0 * clampf(clock / maxf(kf_release_t, .001), 0.0, 1.0)
				var pts := PackedVector2Array()
				for i in 8:
					pts.append(palm + Vector2.from_angle(i * TAU / 8.0 + clock * .8) * rr)
				pts.append(pts[0])
				draw_polyline(pts, Color(primary.r, primary.g, primary.b, .72), 2.0)
				draw_line(palm - Vector2(4,0), palm + Vector2(4,0), secondary, 1.0)
				draw_line(palm - Vector2(0,4), palm + Vector2(0,4), secondary, 1.0)
			"e":
				# 袈裟沿肩向外展开；不是人物中心圆盾。
				var body := kf_sprite.position + Vector2(0, -9)
				draw_arc(body + Vector2(-7,-13), 23, 1.72, 3.02, 12, Color(primary.r, primary.g, primary.b, .52), 2.0)
				draw_arc(body + Vector2(7,-13), 23, .12, 1.42, 12, Color(secondary.r, secondary.g, secondary.b, .58), 2.0)
			"g":
				for i in 6:
					var a := clock * 2.1 + i * TAU / 6.0
					var q := palm + Vector2.from_angle(a) * 10.0
					draw_circle(q, 1.7, secondary if i % 2 else primary)
			"r":
				for i in 7:
					var a := lerpf(-.92, .92, float(i) / 6.0) + facing.angle()
					var q0 := palm + Vector2.from_angle(a) * 10.0
					var q1 := palm + Vector2.from_angle(a) * 18.0
					draw_line(q0, q1, Color(primary.r, primary.g, primary.b, .62), 2.0)
			_:
				# 平A只有四点小法印；真正的“攻击主体”是从 palm 脱手的独立 projectile。
				for i in 4:
					var a := clock * 3.0 + i * TAU / 4.0
					var q := palm + Vector2.from_angle(a) * 7.0
					draw_colored_polygon(PackedVector2Array([q+Vector2(0,-2),q+Vector2(2,0),q+Vector2(0,2),q+Vector2(-2,0)]), secondary if i % 2 else primary)

	if form_left > 0.0:
		# 法相只有少量经文刻度；主体是后方逐渐形成的 Pose 36 法身投影。
		var ramp := clampf(_form_birth, 0.0, 1.0)
		for i in 9:
			var a2 := i * TAU / 9.0 + clock * .16
			var p2 := Vector2(cos(a2) * 43.0, -24 + sin(a2) * 24.0) * ramp
			draw_line(p2 - Vector2(2,0), p2 + Vector2(2,0), Color(primary.r, primary.g, primary.b, .55), 2.0)
