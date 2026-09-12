extends Control
## V4 技能关键帧预览：8 角色 × 13 组动作 × 36 帧，全部使用原始交付 PNG（res://art/frames/）
## A/D 切角色 · W/S 切动作 · J 播放 · K 暂停 · L 循环开关
## 自动验收参数（-- 之后传）：
##   --shot-path=<绝对路径>   截单张主图后退出
##   --grid-path=<绝对路径>   8 角色同屏网格图后退出
##   --gif-dir=<绝对目录>     按动作序列抓帧输出 png 序列后退出（外部合成 GIF）

const MANIFEST := "res://scripts/skill_preview/skill_manifest.json"
const FPS := 8.0

var chars: Array = []
var char_idx := 0
var anim_idx := 0
var loop_on := true
var sprite: AnimatedSprite2D
var frames_cache := {}
var font: Font
var lbl_char: Label
var lbl_anim: Label
var lbl_frame: Label
var lbl_help: Label
var lbl_idx: Label
var shot_path := ""
var grid_path := ""
var gif_dir := ""

func _ready() -> void:
	font = ArtBackdrop.cjk_font()
	chars = (JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary)["characters"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-path="):
			shot_path = arg.trim_prefix("--shot-path=")
		elif arg.begins_with("--grid-path="):
			grid_path = arg.trim_prefix("--grid-path=")
		elif arg.begins_with("--gif-dir="):
			gif_dir = arg.trim_prefix("--gif-dir=")
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().size = Vector2i(1280, 720)
	get_window().move_to_center()
	_build_ui()
	if grid_path != "":
		_build_grid()
		_auto_grid_shot()
	elif gif_dir != "":
		_auto_gif_seq()
	else:
		_apply_all()
		if shot_path != "":
			_auto_shot()

func _label(text: String, pos: Vector2, size: int, color := Color(0.95, 0.93, 0.82)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = ArtBackdrop.checker_texture()
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	sprite = AnimatedSprite2D.new()
	sprite.position = Vector2(640, 400)
	sprite.scale = Vector2(2.2, 2.2)
	add_child(sprite)
	lbl_char = _label("", Vector2(24, 16), 30)
	lbl_anim = _label("", Vector2(24, 60), 21, Color(0.98, 0.85, 0.45))
	lbl_frame = _label("", Vector2(950, 16), 22)
	lbl_idx = _label("", Vector2(950, 48), 15, Color(0.75, 0.8, 0.88))
	lbl_help = _label("A/D 切角色 · W/S 切动作 · J 播放 · K 暂停 · L 循环", Vector2(24, 676), 15, Color(0.7, 0.74, 0.82))

func _build_frames(ci: int) -> SpriteFrames:
	if frames_cache.has(ci):
		return frames_cache[ci]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in chars[ci]["anims"]:
		var an := String(a["slug"])
		sf.add_animation(an)
		sf.set_animation_speed(an, FPS)
		sf.set_animation_loop(an, true)
		for p in a["frames"]:
			sf.add_frame(an, load(String(p)))
	frames_cache[ci] = sf
	return sf

func _apply_all() -> void:
	sprite.sprite_frames = _build_frames(char_idx)
	sprite.animation = String(chars[char_idx]["anims"][anim_idx]["slug"])
	sprite.frame = 0
	if loop_on:
		sprite.play()
	lbl_char.text = "%s · %s" % [chars[char_idx]["name_zh"], chars[char_idx]["code"]]
	var a: Dictionary = chars[char_idx]["anims"][anim_idx]
	lbl_anim.text = "%s（%s）· %s" % [a["name_zh"], a["type"], a["slug"]]
	lbl_idx.text = "角色 %d/8 · 动作 %d/13" % [char_idx + 1, anim_idx + 1]

func _process(_delta: float) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var total := sprite.sprite_frames.get_frame_count(sprite.animation)
	lbl_frame.text = "关键帧 %d/%d · 角色总帧 36" % [sprite.frame + 1, total]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_switch_char(-1)
			KEY_D, KEY_RIGHT:
				_switch_char(1)
			KEY_W, KEY_UP:
				_switch_anim(-1)
			KEY_S, KEY_DOWN:
				_switch_anim(1)
			KEY_J:
				sprite.frame = 0
				sprite.play()
			KEY_K:
				sprite.pause()
			KEY_L:
				loop_on = not loop_on
				for a in chars[char_idx]["anims"]:
					sprite.sprite_frames.set_animation_loop(String(a["slug"]), loop_on)
				lbl_help.text = "A/D 切角色 · W/S 切动作 · J 播放 · K 暂停 · L 循环（当前=%s）" % ("开" if loop_on else "关")

func _switch_char(d: int) -> void:
	char_idx = wrapi(char_idx + d, 0, chars.size())
	anim_idx = 0
	_apply_all()

func _switch_anim(d: int) -> void:
	anim_idx = wrapi(anim_idx + d, 0, chars[char_idx]["anims"].size())
	_apply_all()

func _save_shot(p: String) -> void:
	get_viewport().get_texture().get_image().save_png(p)
	print("[SKILL] saved: " + p)

func _auto_shot() -> void:
	anim_idx = 7  # skill_core_1，代表核心技能
	_apply_all()
	await get_tree().create_timer(0.7).timeout
	_save_shot(shot_path)
	get_tree().quit()

func _build_grid() -> void:
	sprite.visible = false
	lbl_anim.text = ""
	lbl_frame.text = ""
	lbl_idx.text = ""
	lbl_char.text = "8 角色同屏 · 各自播放 idle（原始 PNG 209×209，Nearest）"
	for i in chars.size():
		var s := AnimatedSprite2D.new()
		s.sprite_frames = _build_frames(i)
		s.animation = "idle"
		s.play()
		s.position = Vector2(105 + i * 154, 380)
		s.scale = Vector2(0.72, 0.72)
		add_child(s)
		var l := _label(String(chars[i]["name_zh"]), Vector2(105 + i * 154 - 70, 480), 15, Color(0.85, 0.88, 0.95))
		l.custom_minimum_size = Vector2(140, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position.x = 105 + i * 154 - 70

func _auto_grid_shot() -> void:
	await get_tree().create_timer(0.6).timeout
	_save_shot(grid_path)
	get_tree().quit()

func _auto_gif_seq() -> void:
	var seq := [[0, "skill_core_1"], [0, "finisher"], [0, "ultimate_charge"], [1, "skill_core_2"], [4, "skill_core_1"], [6, "ultimate_charge"], [7, "finisher"]]
	var n := 0
	for pair in seq:
		char_idx = pair[0]
		for ai in chars[char_idx]["anims"].size():
			if String(chars[char_idx]["anims"][ai]["slug"]) == String(pair[1]):
				anim_idx = ai
		_apply_all()
		for k in 4:
			await get_tree().create_timer(0.13).timeout
			_save_shot(gif_dir.path_join("f%03d.png" % n))
			n += 1
	get_tree().quit()
