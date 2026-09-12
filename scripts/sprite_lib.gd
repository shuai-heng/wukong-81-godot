class_name SpriteLib
## 从 assets/atlas.json 构建像素动画（48px cell，脚底中心锚点）
const ATLAS := "res://assets/atlas.png"
const MANIFEST := "res://assets/atlas.json"

static var _tex: Texture2D
static var _manifest: Dictionary

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open(MANIFEST, FileAccess.READ)
		_manifest = JSON.parse_string(f.get_as_text())
	return _manifest

static func atlas_tex() -> Texture2D:
	if _tex == null:
		_tex = load(ATLAS)
	return _tex

## 取某一帧的 AtlasTexture（cell 坐标）
static func frame_tex(cell: Vector2i) -> AtlasTexture:
	var m := manifest()
	var size := int(m.get("cell", 48))
	var at := AtlasTexture.new()
	at.atlas = atlas_tex()
	at.region = Rect2(cell.x * size, cell.y * size, size, size)
	return at

## 构建 SpriteFrames：anims[name] = {"idle":[[..]..], ...}，fps 随帧数自适应
## G11 正式 sprite 覆盖链：heroes/<kind>.png → enemies/<kind>.png → 图集回退
const ART_HERO_DIR := "res://assets/art/heroes/"
const ART_ENEMY_DIR := "res://assets/art/enemies/"
static var _art_cache := {}

## G15 正式资产试接入：官方拆分 PNG（缺失时自动回退原渲染链，不删 fallback）
const ART_TRIAL := {
	"hero:tang": "res://art/characters/tang_sanzang.png",
	"hero:wukong": "res://art/characters/sun_wukong.png",
	"enemy:wolf": "res://art/enemies/wolf_demon.png",
	"boss:黄风大圣": "res://art/bosses/yellow_wind_king.png",
	"boss:黄风怪": "res://art/bosses/yellow_wind_king.png",
	"boss:黄风岭": "res://art/bosses/yellow_wind_king.png",
	"boss:牛魔王": "res://art/bosses/bull_demon_king.png",
}

static func trial_tex(key: String) -> Texture2D:
	var p: String = ART_TRIAL.get(key, "")
	if p == "":
		return null
	var t := _art_tex(p)
	if t != null:
		print("[ART] trial override: " + key + " -> " + p)
	return t

## 新 PNG 尺寸远大于 48px 图集格：只调 Sprite2D.scale 等比归一，不改源图
static func fit_scale(tex: Texture2D, base := 1.0, cell := 48.0) -> float:
	return base * cell / maxf(float(tex.get_width()), float(tex.get_height()))

static func _art_tex(path: String) -> Texture2D:
	if _art_cache.has(path):
		return _art_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_art_cache[path] = t
	return t

static func _frames_single(tex: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for an in ["idle", "run", "atk", "hurt"]:
		sf.add_animation(an)
		sf.set_animation_speed(an, 6.0)
		sf.set_animation_loop(an, an != "atk" and an != "hurt")
		sf.add_frame(an, tex)
	return sf

static func build_frames(kind: String) -> SpriteFrames:
	var art: Texture2D = _art_tex(ART_HERO_DIR + kind + ".png")
	if art == null:
		art = _art_tex(ART_ENEMY_DIR + kind + ".png")
	if art != null:
		print("[ART] override sprite: " + kind)
		return _frames_single(art)
	var m := manifest()
	var anims: Dictionary = m.get("anims", {}).get(kind, {})
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fps := 6.0
	# 归一化：只有 walk/hurt 的帧（小怪系）补出 idle/run/atk，保证英雄接口统一
	if anims.has("walk") and not anims.has("idle"):
		anims["idle"] = [anims["walk"][0]]
		anims["run"] = anims["walk"]
		anims["atk"] = anims.get("hurt", anims["walk"])
	for anim_name in anims.keys():
		var cells: Array = anims[anim_name]
		var an := String(anim_name)
		if not sf.has_animation(an):
			sf.add_animation(an)
		sf.set_animation_speed(an, fps)
		sf.set_animation_loop(an, an != "atk" and an != "hurt")
		for cell in cells:
			sf.add_frame(an, frame_tex(Vector2i(cell[0], cell[1])))
	return sf

static func cell_size() -> int:
	return int(manifest().get("cell", 48))
