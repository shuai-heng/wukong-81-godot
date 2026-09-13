class_name KeyframeLib
## V6.1 真实姿势关键帧 → 战斗内演出（数据与 skill_gallery_v6 同源：JSON + 288 张姿势 PNG）
## 只做视觉层：按 角色+动作 逐关键帧离散换装（贴图/位移/旋转/缩放），不改战斗数值与判定。
## 数据或姿势图缺失时回退旧图集动画（调用方以 kf_slug=="" 判定走旧渲染）。

const DATA := "res://data/v6_1_full_keyframes_exact_pose.json"
const POSE_PREFIX := "01_真实PosePNG/"
const POSE_RES := "res://art/v6_pose/"
const POSE_CLEAN := "res://art/v6_pose_clean/"
const BODY_UNIT := 48.0
const POSE_CELL := 256.0
const BASE_CELL := 64.0            # 姿势格映射到 64 世界单位，人物主体≈旧 48px 立绘观感

# ---- M2 真动画调参区（负责人按观感可调） ----
const POSE_INTERP := true          # 子步1：相邻关键帧间位移/旋转/缩放线性插值（false=回到取最近关键帧）
const CROSSFADE_MS := 0.075        # 子步2：姿势交叉淡化时长上限（60–90ms 观感区）
const XFADE_SEG_FRAC := 0.8        # 淡化窗不超过所在关键帧段时长的比例（短段防叠淡闪烁）
const XFADE_MIN := 0.024           # 淡化窗下限（秒）
const XFADE_IN_FROM := 0.0         # 新姿势淡入起始透明度
const STATE_BLEND_MS := 0.10       # 子步3：动作/状态切换过渡时长（idle/run/form↔技能、收招回落）
const BLEND_ALPHA_FROM := 0.25     # 过渡期新动作淡入起始透明度
const STATE_BLEND_SCALE := 0.96    # 过渡期新动作起始缩放缓冲（消切换 pop）
# ---- 子步4：V6.1 打击感元数据调参（hitstop_ms/camera_shake/trail_enabled/afterimage_count/vfx_intensity） ----
const META_HITSTOP_SCALE := 1.0    # hitstop_ms→秒 换算（0=关闭元数据顿帧；仅一次性动作触发）
const META_HITSTOP_MAX := 0.09     # 单段元数据顿帧上限（秒）
const META_SHAKE_SCALE := 2.2      # camera_shake(0-10) → request_shake 强度
const META_AFTER_GAP := 0.15       # 残影生成限频间隔（秒，防逐帧刷屏）
const META_AFTER_LIFE := 0.30      # 元数据残影存活（秒）
const META_AFTER_STAGGER := 0.06   # 多残影寿命间隔（秒）
const META_TRAIL_POINTS := 14      # 拖尾采样点数（60Hz≈0.23s 尾长）
const META_TRAIL_WIDTH := 5.0
const META_TRAIL_COLOR := Color(1.0, 0.92, 0.65, 0.5)
const META_GLOW_ALPHA := 0.45      # vfx_intensity(0-1) → 发光层 alpha 系数（0=关闭）
const META_GLOW_MIN := 0.35        # 发光层启用阈值（idle 基线 0.18 不常亮）
const META_GLOW_COLOR := Color(1.0, 0.88, 0.55)

## 游戏 hero_id → V6.1 character_slug（白龙双形态：化龙时用马形）
const HERO_SLUG := {
	"wukong": "sun_wukong", "tang": "tang_sanzang",
	"whiteDragon": "white_dragon_prince", "whiteDragonHorse": "white_dragon_horse",
	"bajie": "zhu_bajie", "shaWujing": "sha_wujing", "nezha": "nezha", "erlang": "erlang_shen",
}

## 法相/终结类战斗阅读放大（对齐画廊 ACTION_READ_SCALE；普攻/技能 1.0）
const READ_SCALE := {
	"sun_wukong:form": 1.3, "sun_wukong:finisher": 1.5,
	"tang_sanzang:form": 1.3,
	"white_dragon_prince:form": 1.35, "white_dragon_horse:form": 1.35,
	"zhu_bajie:form": 1.35, "sha_wujing:form": 1.35, "nezha:form": 1.4,
	"erlang_shen:form": 1.7, "erlang_shen:finisher": 2.6,
}

## 战斗节奏压缩：普攻/位移类短动作加速播放，避免 0.5s 攻击间隔内动作拖沓
const ACTION_SPEED := {"atk_combo": 2.0, "heavy": 1.6, "dodge": 1.5}

# ---- M2 返工（R3）· 完整技能释放编排调参区（负责人按观感可调） ----
const ANCHOR_DATA := "res://data/v6_pose_anchors.json"  # 姿势特效锚点（离线提取：质心/前缘/半径/强度）
const RELEASE_MIN_FRAC := 0.15   # 释放帧钳位下限（动作时长占比）
const RELEASE_MAX_FRAC := 0.75   # 释放帧钳位上限
const RELEASE_FALLBACK_FRAC := 0.45  # 无 hitbox/hitstop 元数据时的释放点
const CHARGE_ORB_BASE := 0.20    # 蓄力光点基础尺寸（×64px 径向纹理）
const CHARGE_ORB_SWELL := 0.30   # 蓄力推进增大的幅度
const CHARGE_PULSE := 0.10       # 蓄力光点呼吸幅度

static var _acts := {}             # character_slug -> {action_slug: Array[kf Dictionary]}
static var _tex_cache := {}
static var _anchors := {}          # "slug/pose.png" -> {c:[x,y], f:[x,y], r:px, w:0-1}
static var _rel_cache := {}        # "slug:action" -> 释放时刻（动作时间轴秒）

static func _load() -> bool:
	if not _acts.is_empty():
		return true
	var raw := FileAccess.get_file_as_string(DATA)
	if raw.is_empty():
		return false
	var parsed = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary) or not parsed.has("keyframes"):
		return false
	for kf in parsed["keyframes"]:
		var cs := String(kf["character_slug"])
		if not _acts.has(cs):
			_acts[cs] = {}
		var asl := String(kf["action_slug"])
		if not _acts[cs].has(asl):
			_acts[cs][asl] = []
		_acts[cs][asl].append(kf)
	return true

static func slug_for(hero: String, dragon: bool) -> String:
	if not _load():
		return ""
	var key := "whiteDragonHorse" if hero == "whiteDragon" and dragon else hero
	var slug: String = HERO_SLUG.get(key, "")
	return slug if _acts.has(slug) else ""

static func has_action(slug: String, action: String) -> bool:
	return _acts.has(slug) and _acts[slug].has(action)

## 挂载关键帧精灵（玩家 _ready 调用；数据不可用则不创建）
static func attach(p) -> void:
	if not _load() or p.get("kf_sprite") != null:
		return
	var s := Sprite2D.new()
	s.name = "KFSprite"
	s.visible = false
	s.z_index = 1
	p.add_child(s)
	p.kf_sprite = s
	var f := Sprite2D.new()
	f.name = "KFFade"
	f.visible = false
	f.z_index = 1
	p.add_child(f)
	p.kf_fade_sprite = f
	var g := Sprite2D.new()
	g.name = "KFGlow"
	g.visible = false
	g.z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	p.add_child(g)
	p.kf_glow_sprite = g
	var tl := Line2D.new()
	tl.name = "KFTrail"
	tl.visible = false
	tl.width = META_TRAIL_WIDTH
	tl.default_color = META_TRAIL_COLOR
	tl.joint_mode = Line2D.LINE_JOINT_ROUND
	tl.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tl.end_cap_mode = Line2D.LINE_CAP_ROUND
	tl.top_level = true
	tl.z_index = -1
	p.add_child(tl)
	p.kf_trail = tl
	# R3：蓄力光点（径向渐变纹理，ADD 混合，锚点跟随）——起手期在武器/施法锚点上凝聚
	var orb := Sprite2D.new()
	orb.name = "KFOrb"
	orb.visible = false
	orb.z_index = 3
	var om := CanvasItemMaterial.new()
	om.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	orb.material = om
	var gt := GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gr.colors = PackedColorArray([Color.WHITE, Color(1.0, 0.97, 0.85, 0.8), Color(1.0, 0.9, 0.6, 0.0)])
	gt.gradient = gr
	orb.texture = gt
	p.add_child(orb)
	p.kf_orb = orb

## 隐藏全部关键帧演出层（动作清空/换装/退出法相时）
static func hide_visuals(p) -> void:
	if p.get("kf_sprite") != null:
		p.kf_sprite.visible = false
	if p.get("kf_fade_sprite") != null:
		p.kf_fade_sprite.visible = false
		p.kf_xfade_left = 0.0
		p.kf_blend_left = 0.0
	if p.get("kf_glow_sprite") != null:
		p.kf_glow_sprite.visible = false
	if p.get("kf_orb") != null:
		p.kf_orb.visible = false
	if p.get("kf_trail") != null:
		p.kf_trail.visible = false
		p.kf_trail.clear_points()
	p.kf_seg = -1

## 发起一次动作；one_shot=false 为循环基底（idle/run/form）。不存在该动作时静默忽略。
static func play_action(p, action: String, one_shot := true) -> void:
	var slug: String = p.kf_slug
	if slug == "" or not has_action(slug, action):
		return
	if p.kf_action == action and one_shot:
		return   # 同名一次性动作不打断重播（普攻连击保持连贯）
	_switch_action(p, action, one_shot)

## 子步3：所有动作/状态切换走统一入口——旧姿势快照进过渡层淡出，
## 新动作以 BLEND_ALPHA_FROM 淡入 + STATE_BLEND_SCALE 缩放缓冲，消除切换 pop。
static func _switch_action(p, action: String, one_shot: bool) -> void:
	_snapshot_fade(p, STATE_BLEND_MS)
	if p.has_method("kf_cancel_release"):
		p.kf_cancel_release()   # 动作被打断即取消未释放的判定（R3 编排）
	p.kf_action = action
	p.kf_t = 0.0
	p.kf_one_shot = one_shot
	p.kf_speed = float(ACTION_SPEED.get(action, 1.0))
	p.kf_sprite.visible = true
	p.sprite.visible = false
	p.kf_blend_left = STATE_BLEND_MS
	p.kf_blend_dur = STATE_BLEND_MS
	p.kf_seg = -1
	p.kf_after_t = -1.0
	p.kf_freeze_left = 0.0

## 每物理帧推进。循环基底（idle/run/form）按移动/法相状态实时切换；
## 一次性动作播完自动清空 kf_action 回落循环基底（子步2 起回落经淡化层软化，不瞬切）。
static func tick(p, delta: float, moving: bool) -> void:
	if p.kf_slug == "":
		return
	if p.kf_action == "" or not p.kf_one_shot:
		var want := _want_loop(p, moving)
		if want != p.kf_action and has_action(p.kf_slug, want):
			_switch_action(p, want, false)
		elif p.kf_action == "" and not has_action(p.kf_slug, want):
			p.sprite.visible = true
			hide_visuals(p)
			return
	if p.kf_action == "":
		return
	var kfs: Array = _acts[p.kf_slug][p.kf_action]
	# 子步4：元数据顿帧期间定格姿势（淡化计时同步暂停，保留定格感）
	if p.kf_freeze_left > 0.0:
		p.kf_freeze_left = maxf(0.0, p.kf_freeze_left - delta)
		delta = 0.0
	var t: float = float(p.kf_t) + delta * float(p.kf_speed)
	var dur: float = float(kfs[kfs.size() - 1]["time_ms"]) / 1000.0
	if p.kf_one_shot and t >= dur:
		p.kf_action = ""
		_glow_update(p, 0.0)
		_trail_update(p, false)
		return
	if t >= dur:
		t = wrapf(t, 0.0, dur)   # 循环基底
		p.kf_seg = -1            # 环回重触发首段元数据
	p.kf_t = t
	var seg := _seg_index(kfs, t * 1000.0)
	if seg != p.kf_seg:
		p.kf_seg = seg
		_fire_meta(p, kfs[seg])
	var pre_tex: Texture2D = p.kf_sprite.texture
	var pre_pos: Vector2 = p.kf_sprite.position
	var pre_rot: float = p.kf_sprite.rotation
	var pre_scl: Vector2 = p.kf_sprite.scale
	var pre_flip: bool = p.kf_sprite.flip_h
	_apply_pose(p, kfs)
	if p.kf_sprite.texture != pre_tex and pre_tex != null:
		var win: float = CROSSFADE_MS
		if seg + 1 < kfs.size():
			win = (float(kfs[seg + 1]["time_ms"]) - float(kfs[seg]["time_ms"])) / 1000.0 * XFADE_SEG_FRAC
		_snapshot_fade(p, clampf(win, XFADE_MIN, CROSSFADE_MS), pre_tex, pre_pos, pre_rot, pre_scl, pre_flip)
	_advance_fades(p, delta)
	_glow_update(p, float(kfs[seg].get("vfx_intensity", 0.0)))
	_trail_update(p, bool(kfs[seg].get("trail_enabled", false)))

## 子步4：按关键帧元数据触发打击感——顿帧（main.hitstop+姿势定格）/震屏/残影；
## 仅一次性动作触发（idle/run/form 循环段的同类字段会周期性刷屏，不采用）
static func _fire_meta(p, kf: Dictionary) -> void:
	if not p.kf_one_shot:
		return
	var hs: float = float(kf.get("hitstop_ms", 0))
	if hs > 0.0 and META_HITSTOP_SCALE > 0.0:
		var sec: float = minf(hs / 1000.0 * META_HITSTOP_SCALE, META_HITSTOP_MAX)
		if p.get("main") != null and p.main != null:
			p.main.hitstop = maxf(float(p.main.hitstop), sec)
		p.kf_freeze_left = maxf(float(p.kf_freeze_left), sec)
	var cs: float = float(kf.get("camera_shake", 0.0))
	if cs > 0.0 and p.get("main") != null and p.main != null and p.main.has_method("request_shake"):
		p.main.request_shake(cs * META_SHAKE_SCALE)
	if int(kf.get("afterimage_count", 0)) > 0 and float(p.kf_t) - float(p.kf_after_t) >= META_AFTER_GAP:
		p.kf_after_t = float(p.kf_t)
		if p.get("main") != null and p.main != null and p.main.has_method("spawn_phantom"):
			for j in mini(int(kf.get("afterimage_count", 0)), 3):
				p.main.spawn_phantom(p.global_position, p.sprite.flip_h, p.kf_sprite.texture, p.kf_sprite.scale, META_AFTER_LIFE + META_AFTER_STAGGER * j)

## 子步4：vfx_intensity → 发光层（ADD 混合姿势叠层，法相/终结高强度时明显）
static func _glow_update(p, intensity: float) -> void:
	if p.kf_glow_sprite == null:
		return
	var a: float = clampf(intensity, 0.0, 1.0) * META_GLOW_ALPHA
	if intensity < META_GLOW_MIN or a < 0.02 or not p.kf_sprite.visible:
		p.kf_glow_sprite.visible = false
		return
	var g: Sprite2D = p.kf_glow_sprite
	g.texture = p.kf_sprite.texture
	g.flip_h = p.kf_sprite.flip_h
	g.position = p.kf_sprite.position
	g.rotation = p.kf_sprite.rotation
	g.scale = p.kf_sprite.scale
	g.modulate = Color(META_GLOW_COLOR.r, META_GLOW_COLOR.g, META_GLOW_COLOR.b, a)
	g.visible = true

## 子步4：trail_enabled → Line2D 拖尾（激活时采样全局坐标，失活时收缩回收）
static func _trail_update(p, active: bool) -> void:
	if p.kf_trail == null:
		return
	var tl: Line2D = p.kf_trail
	if active and p.kf_sprite.visible:
		tl.add_point(p.global_position)
		while tl.get_point_count() > META_TRAIL_POINTS:
			tl.remove_point(0)
	else:
		for j in mini(2, tl.get_point_count()):
			tl.remove_point(0)
	tl.visible = tl.get_point_count() >= 2

## 把一份姿势快照交给过渡层（子步2 姿势淡化 / 子步3 状态过渡共用）
static func _snapshot_fade(p, dur: float, old_tex: Texture2D = null, old_pos := Vector2.INF, old_rot := 0.0, old_scl := Vector2.INF, old_flip := false) -> void:
	if p.kf_fade_sprite == null:
		return
	if old_tex == null:
		if p.kf_sprite.texture == null or not p.kf_sprite.visible:
			return
		old_tex = p.kf_sprite.texture
		old_pos = p.kf_sprite.position
		old_rot = p.kf_sprite.rotation
		old_scl = p.kf_sprite.scale
		old_flip = p.kf_sprite.flip_h
	var f: Sprite2D = p.kf_fade_sprite
	f.texture = old_tex
	f.flip_h = old_flip
	f.position = old_pos
	f.rotation = old_rot
	f.scale = old_scl
	p.kf_fade_base = p.kf_sprite.modulate
	f.visible = true
	p.kf_xfade_left = dur
	p.kf_xfade_dur = dur

## 每帧推进两层过渡：姿势淡化（旧姿势 alpha 1→0）+ 状态过渡（新动作淡入/缩放缓冲）
static func _advance_fades(p, delta: float) -> void:
	if p.kf_fade_sprite == null:
		return
	var a_in := 1.0
	if p.kf_blend_left > 0.0:
		p.kf_blend_left = maxf(0.0, p.kf_blend_left - delta)
		var kb: float = 1.0 - p.kf_blend_left / maxf(p.kf_blend_dur, 0.001)
		a_in *= lerpf(BLEND_ALPHA_FROM, 1.0, kb)
		p.kf_sprite.scale = p.kf_sprite.scale * lerpf(STATE_BLEND_SCALE, 1.0, kb)
	if p.kf_xfade_left > 0.0:
		p.kf_xfade_left = maxf(0.0, p.kf_xfade_left - delta)
		var kx: float = 1.0 - p.kf_xfade_left / maxf(p.kf_xfade_dur, 0.001)
		a_in *= lerpf(XFADE_IN_FROM, 1.0, kx)
		var b: Color = p.kf_fade_base
		p.kf_fade_sprite.modulate = Color(b.r, b.g, b.b, b.a * (1.0 - kx))
		if p.kf_xfade_left <= 0.0:
			p.kf_fade_sprite.visible = false
	elif p.kf_fade_sprite.visible:
		p.kf_fade_sprite.visible = false
	var m: Color = p.kf_sprite.modulate
	m.a = a_in
	p.kf_sprite.modulate = m

## 循环基底选择：法相 > 跑动 > 站立
static func _want_loop(p, moving: bool) -> String:
	if p.in_form() and has_action(p.kf_slug, "form"):
		return "form"
	return "run" if moving else "idle"

## 段索引：当前时刻落在哪个关键帧段（纹理=该段起始关键帧的姿势，即仍在关键帧时刻切换）
static func _seg_index(kfs: Array, t_ms: float) -> int:
	var i := 0
	for j in kfs.size():
		if float(kfs[j]["time_ms"]) <= t_ms:
			i = j
		else:
			break
	return i

## 子步1：变换取相邻关键帧线性插值；纹理仍按关键帧时刻整张切换
static func _apply_pose(p, kfs: Array) -> void:
	var t_ms: float = float(p.kf_t) * 1000.0
	var i := _seg_index(kfs, t_ms)
	var kf: Dictionary = kfs[i]
	var bx := float(kf["body_x"])
	var by := float(kf["body_y"])
	var rot := float(kf["rotation_deg"])
	var sx := float(kf["scale_x"])
	var sy := float(kf["scale_y"])
	if POSE_INTERP and i + 1 < kfs.size():
		var nxt: Dictionary = kfs[i + 1]
		var span: float = float(nxt["time_ms"]) - float(kf["time_ms"])
		if span > 0.5:
			var a: float = clampf((t_ms - float(kf["time_ms"])) / span, 0.0, 1.0)
			bx = lerpf(bx, float(nxt["body_x"]), a)
			by = lerpf(by, float(nxt["body_y"]), a)
			rot = lerpf(rot, float(nxt["rotation_deg"]), a)
			sx = lerpf(sx, float(nxt["scale_x"]), a)
			sy = lerpf(sy, float(nxt["scale_y"]), a)
	var flip: bool = p.sprite.flip_h
	p.kf_sprite.texture = _pose_tex(kf)
	p.kf_sprite.flip_h = flip
	var rs: float = _read_scale(p.kf_slug, p.kf_action)
	var fit := BASE_CELL / POSE_CELL
	var scl := Vector2(fit * sx, fit * sy) * rs
	if p.get("dragon_left") != null and float(p.dragon_left) > 0.0:
		scl *= 1.22
	p.kf_sprite.scale = scl
	var off := Vector2(bx, by) * (BASE_CELL / BODY_UNIT)
	if flip:
		off.x = -off.x
	p.kf_sprite.position = off
	p.kf_sprite.rotation = -deg_to_rad(rot) if flip else deg_to_rad(rot)
	p.kf_sprite.modulate = p.sprite.modulate

static func _read_scale(slug: String, action: String) -> float:
	if READ_SCALE.has(slug + ":" + action):
		return float(READ_SCALE[slug + ":" + action])
	return 1.14 if action in ["form", "finisher"] else 1.0

static func _pose_tex(kf: Dictionary) -> Texture2D:
	var rel := String(kf["pose_file"]).replace(POSE_PREFIX, "")
	for base in [POSE_CLEAN, POSE_RES]:
		var path: String = String(base) + rel
		if _tex_cache.has(path):
			return _tex_cache[path]
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			_tex_cache[path] = tex
			return tex
	return null

# ================= R3 · 完整技能释放编排（锚点/释放帧/蓄力） =================

static func _load_anchors() -> void:
	if not _anchors.is_empty():
		return
	var raw := FileAccess.get_file_as_string(ANCHOR_DATA)
	if raw.is_empty():
		return
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		_anchors = parsed

## 当前姿势的锚点（归一化 [0,1]，随关键帧插值平滑移动）
## kind: "c"=特效质心（周身/nova 生成点） "f"=前缘点（突刺/投射物生成点，≈武器端方向）
static func _anchor_norm(p, kind: String) -> Vector2:
	_load_anchors()
	var def := Vector2(0.5, 0.6)
	if p.kf_slug == "" or p.kf_action == "":
		return def
	var kfs: Array = _acts.get(String(p.kf_slug), {}).get(String(p.kf_action), [])
	if kfs.is_empty():
		return def
	var seg := _seg_index(kfs, float(p.kf_t) * 1000.0)
	var kf: Dictionary = kfs[seg]
	var key := String(p.kf_slug) + "/" + String(kf["pose_file"]).get_file()
	var a: Dictionary = _anchors.get(key, {})
	var nx: float = float(Array(a.get(kind, [def.x, def.y]))[0])
	var ny: float = float(Array(a.get(kind, [def.x, def.y]))[1])
	if POSE_INTERP and seg + 1 < kfs.size():
		var nxt: Dictionary = kfs[seg + 1]
		var b: Dictionary = _anchors.get(String(p.kf_slug) + "/" + String(nxt["pose_file"]).get_file(), {})
		var bx: float = float(Array(b.get(kind, [nx, ny]))[0])
		var by: float = float(Array(b.get(kind, [nx, ny]))[1])
		var span: float = float(nxt["time_ms"]) - float(kf["time_ms"])
		if span > 0.5:
			var al: float = clampf((float(p.kf_t) * 1000.0 - float(kf["time_ms"])) / span, 0.0, 1.0)
			nx = lerpf(nx, bx, al)
			ny = lerpf(ny, by, al)
	return Vector2(nx, ny)

## 当前姿势特效强度（0-1，蓄力光点大小参考）
static func _anchor_w(p) -> float:
	_load_anchors()
	if p.kf_slug == "" or p.kf_action == "":
		return 0.0
	var kfs: Array = _acts.get(String(p.kf_slug), {}).get(String(p.kf_action), [])
	if kfs.is_empty():
		return 0.0
	var seg := _seg_index(kfs, float(p.kf_t) * 1000.0)
	var kf: Dictionary = kfs[seg]
	var a: Dictionary = _anchors.get(String(p.kf_slug) + "/" + String(kf["pose_file"]).get_file(), {})
	return float(a.get("w", 0.0))

## 锚点的世界坐标（套用姿势精灵的位移/旋转/缩放/flip 镜像——技能从此点生成）
static func anchor_world(p, kind := "f") -> Vector2:
	if p.get("kf_sprite") == null or p.kf_sprite.texture == null or not p.kf_sprite.visible:
		return p.global_position
	var an := _anchor_norm(p, kind)
	var lx := (an.x - 0.5) * POSE_CELL
	var ly := (an.y - 0.5) * POSE_CELL
	if p.kf_sprite.flip_h:
		lx = -lx
	var v: Vector2 = Vector2(lx, ly) * p.kf_sprite.scale
	v = v.rotated(p.kf_sprite.rotation)
	return p.global_position + p.kf_sprite.position + v

## 判定释放时刻（动作自身时间轴，秒）：首个 hitbox_active 关键帧；
## 退回首个 hitstop_ms>0；再退回时长占比 45%。钳位 [15%, 75%]。
static func release_time(slug: String, action: String) -> float:
	var ck := slug + ":" + action
	if _rel_cache.has(ck):
		return float(_rel_cache[ck])
	var kfs: Array = _acts.get(slug, {}).get(action, [])
	var dur := 0.6
	if not kfs.is_empty():
		dur = float(kfs[kfs.size() - 1]["time_ms"]) / 1000.0
	var ms := -1.0
	for kf in kfs:
		if bool(kf.get("hitbox_active", false)):
			ms = float(kf["time_ms"])
			break
	if ms < 0.0:
		for kf in kfs:
			if float(kf.get("hitstop_ms", 0)) > 0.0:
				ms = float(kf["time_ms"])
				break
	if ms < 0.0:
		ms = dur * 1000.0 * RELEASE_FALLBACK_FRAC
	var rel: float = clampf(ms / 1000.0, dur * RELEASE_MIN_FRAC, dur * RELEASE_MAX_FRAC)
	_rel_cache[ck] = rel
	return rel

## 登记一次待释放判定（玩家 _kf_cast 调用；tick 推进到释放时刻由玩家回调结算）
static func schedule_release(p, action: String, cb: Callable) -> void:
	p.kf_release_t = release_time(String(p.kf_slug), action)
	p.kf_release_cb = cb
	p.kf_cast_action = action

## 蓄力光点跟随锚点（释放前每帧调用；progress<0 隐藏）
static func update_charge(p, progress: float) -> void:
	if p.get("kf_orb") == null:
		return
	var orb: Sprite2D = p.kf_orb
	if progress < 0.0:
		orb.visible = false
		return
	var col := action_color(p)
	orb.global_position = anchor_world(p, "f")
	var s: float = CHARGE_ORB_BASE + CHARGE_ORB_SWELL * clampf(progress, 0.0, 1.0) + 0.10 * _anchor_w(p)
	s *= 1.0 + CHARGE_PULSE * sin(float(p.kf_t) * 46.0)
	orb.scale = Vector2(s, s)
	orb.modulate = Color(col.r, col.g, col.b, 0.55 + 0.40 * clampf(progress, 0.0, 1.0))
	orb.visible = true

## 当前关键帧的官方特效主色（primary_color "#RRGGBB"）
static func action_color(p) -> Color:
	if p.kf_slug == "" or p.kf_action == "":
		return Color("ffd46b")
	var kfs: Array = _acts.get(String(p.kf_slug), {}).get(String(p.kf_action), [])
	if kfs.is_empty():
		return Color("ffd46b")
	var seg := _seg_index(kfs, float(p.kf_t) * 1000.0)
	var c := Color("ffd46b")
	var raw := String(kfs[seg].get("primary_color", ""))
	if raw.begins_with("#"):
		c = Color(raw)
	return c
