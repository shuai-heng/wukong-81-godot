extends Control
## G15 资产画廊：分 characters / enemies / bosses 三组展示 res://art/ 下全部 103 张正式 PNG。
## ←/→ 或 1/2/3 切组，PgUp/PgDn 与滚轮滚动；--shot-path=<绝对路径> 自动逐组截图后退出。
## 仅做节点级展示：图片不改、不缩放源文件，TextureRect 只做显示布局。

const GROUPS := [
	{"key": "characters", "title_zh": "角色与NPC", "dir": "res://art/characters/"},
	{"key": "enemies", "title_zh": "小怪", "dir": "res://art/enemies/"},
	{"key": "bosses", "title_zh": "Boss", "dir": "res://art/bosses/"},
]
const COLS := 8
const CELL_W := 160
const IMG_H := 140
const LBL_H := 22

var group_idx := 0
var shot_path := ""
var font: Font
var scroll: ScrollContainer
var grid: GridContainer
var title_lbl: Label

func _ready() -> void:
	font = ArtBackdrop.cjk_font()
	# 项目全局是 640x360 canvas 2x 拉伸；画廊按真实 1280x720 像素布局
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().size = Vector2i(1280, 720)
	get_window().move_to_center()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-path="):
			shot_path = arg.trim_prefix("--shot-path=")
	_build_static_ui()
	_build_group(0)
	if shot_path != "":
		_auto_shots()

func _build_static_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = ArtBackdrop.checker_texture()
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	title_lbl = Label.new()
	title_lbl.position = Vector2(12, 8)
	title_lbl.add_theme_font_size_override("font_size", 15)
	if font != null:
		title_lbl.add_theme_font_override("font", font)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	add_child(title_lbl)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 40)
	scroll.size = Vector2(1280, 680)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

func _list_pngs(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			out.append(f)
	out.sort()
	return out

func _build_group(idx: int) -> void:
	group_idx = idx
	var g: Dictionary = GROUPS[idx]
	var files := _list_pngs(g["dir"])
	title_lbl.text = "art gallery · %s %s · %d 张  |  ←/→ 切组 · PgUp/PgDn 滚动  |  共 103 张（characters 25 + enemies 30 + bosses 48）" % [g["title_zh"], g["key"], files.size()] if font != null else "art gallery · %s · %d / 103  |  LEFT/RIGHT: switch group" % [g["key"], files.size()]
	if grid != null:
		grid.queue_free()
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid)
	for f in files:
		grid.add_child(_make_cell(g["dir"] + f, f.trim_suffix(".png")))

func _make_cell(path: String, slug: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CELL_W, IMG_H + LBL_H + 4)
	box.add_theme_constant_override("separation", 0)
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.custom_minimum_size = Vector2(CELL_W, IMG_H)
	box.add_child(tr)
	var lbl := Label.new()
	lbl.text = slug
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	if font != null:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	box.add_child(lbl)
	return box

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_1:
				_build_group(0)
			KEY_RIGHT, KEY_2:
				_build_group(1)
			KEY_3:
				_build_group(2)
			KEY_PAGEDOWN:
				scroll.scroll_vertical += 640
			KEY_PAGEUP:
				scroll.scroll_vertical -= 640
			KEY_ESCAPE:
				get_tree().quit()

func _auto_shots() -> void:
	await get_tree().create_timer(0.6).timeout
	for i in GROUPS.size():
		_build_group(i)
		scroll.scroll_vertical = 0
		await get_tree().create_timer(0.45).timeout
		_save_shot(_shot_name(i, false))
		if i == 2:
			scroll.scroll_vertical = 100000
			await get_tree().create_timer(0.3).timeout
			_save_shot(_shot_name(i, true))
	print("[GALLERY] all shots saved")
	get_tree().quit()

func _shot_name(i: int, bottom: bool) -> String:
	if i == 0:
		return shot_path
	return shot_path.replace(".png", "_" + GROUPS[i]["key"] + ("_p2" if bottom else "") + ".png")

func _save_shot(p: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(p)
	print("[GALLERY] shot saved: " + p)
