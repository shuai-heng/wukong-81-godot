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

static var _acts := {}             # character_slug -> {action_slug: Array[kf Dictionary]}
static var _tex_cache := {}

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

## 发起一次动作；one_shot=false 为循环基底（idle/run/form）。不存在该动作时静默忽略。
static func play_action(p, action: String, one_shot := true) -> void:
	var slug: String = p.kf_slug
	if slug == "" or not has_action(slug, action):
		return
	if p.kf_action == action and one_shot:
		return   # 同名一次性动作不打断重播（普攻连击保持连贯）
	p.kf_action = action
	p.kf_t = 0.0
	p.kf_one_shot = one_shot
	p.kf_speed = float(ACTION_SPEED.get(action, 1.0))
	p.kf_sprite.visible = true
	p.sprite.visible = false

## 每物理帧推进。循环基底（idle/run/form）按移动/法相状态实时切换；
## 一次性动作播完自动清空 kf_action 回落循环基底。
static func tick(p, delta: float, moving: bool) -> void:
	if p.kf_slug == "":
		return
	if p.kf_action == "" or not p.kf_one_shot:
		var want := _want_loop(p, moving)
		if want != p.kf_action and has_action(p.kf_slug, want):
			p.kf_action = want
			p.kf_t = 0.0
			p.kf_one_shot = false
			p.kf_speed = float(ACTION_SPEED.get(want, 1.0))
			p.kf_sprite.visible = true
			p.sprite.visible = false
		elif p.kf_action == "" and not has_action(p.kf_slug, want):
			p.sprite.visible = true
			p.kf_sprite.visible = false
			return
	if p.kf_action == "":
		return
	var kfs: Array = _acts[p.kf_slug][p.kf_action]
	var t: float = float(p.kf_t) + delta * float(p.kf_speed)
	var dur: float = float(kfs[kfs.size() - 1]["time_ms"]) / 1000.0
	if p.kf_one_shot and t >= dur:
		p.kf_action = ""
		p.kf_sprite.visible = false
		return
	if t >= dur:
		t = wrapf(t, 0.0, dur)   # 循环基底
	p.kf_t = t
	_apply_pose(p, kfs)

## 循环基底选择：法相 > 跑动 > 站立
static func _want_loop(p, moving: bool) -> String:
	if p.in_form() and has_action(p.kf_slug, "form"):
		return "form"
	return "run" if moving else "idle"

static func _apply_pose(p, kfs: Array) -> void:
	var kf: Dictionary = kfs[0]
	var t_ms: float = float(p.kf_t) * 1000.0
	for k in kfs:
		if float(k["time_ms"]) <= t_ms:
			kf = k
		else:
			break
	var flip: bool = p.sprite.flip_h
	p.kf_sprite.texture = _pose_tex(kf)
	p.kf_sprite.flip_h = flip
	var rs: float = _read_scale(p.kf_slug, p.kf_action)
	var fit := BASE_CELL / POSE_CELL
	var scl := Vector2(fit * float(kf["scale_x"]), fit * float(kf["scale_y"])) * rs
	if p.get("dragon_left") != null and float(p.dragon_left) > 0.0:
		scl *= 1.22
	p.kf_sprite.scale = scl
	var off := Vector2(float(kf["body_x"]), float(kf["body_y"])) * (BASE_CELL / BODY_UNIT)
	if flip:
		off.x = -off.x
	p.kf_sprite.position = off
	p.kf_sprite.rotation = -deg_to_rad(float(kf["rotation_deg"])) if flip else deg_to_rad(float(kf["rotation_deg"]))
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
