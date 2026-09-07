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
static func build_frames(kind: String) -> SpriteFrames:
	var m := manifest()
	var anims: Dictionary = m.get("anims", {}).get(kind, {})
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fps := 6.0
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
