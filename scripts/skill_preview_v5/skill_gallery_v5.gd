extends Node2D
## V5 技能程序关键帧预览：8 角色 × 83 动作 × 1322 程序关键帧
## 数据源：res://data/v5_full_keyframes.json（唯一动画依据；V4 帧映射未使用）
## 节点结构按 GODOT_V5_KEYFRAME_SCHEMA：VisualRoot/Sprite2D/AfterimageRoot/VFXRoot/FormOverlay/HitboxRoot/AnimationPlayer/CameraImpulse
## A/D 切角色 · W/S 切动作 · J 播放 · K 暂停 · L 循环
## 自动模式（-- 之后）：--shot-path= | --grid-path= | --gif-dir=

const DATA := "res://data/v5_full_keyframes.json"
const CELL := 209          # 基准表 6x6 网格单元
const CHARS_H := 280.0     # 主预览角色屏幕高度
const BODY_UNIT := 48.0    # body_x/y 的单位（48px 格角色尺度）

var data: Dictionary
var chars: Array
var kfs: Array
var char_idx := 0
var act_idx := 0
var loop_on := true
var font: Font

var rig: Node2D
var visual_root: Node2D
var sprite: Sprite2D
var vfx_root: Node2D
var vfx_glow: Sprite2D
var form_overlay: Sprite2D
var hitbox_root: Node2D
var hitbox_ring: Sprite2D
var afterimage_root: Node2D
var anim_player: AnimationPlayer
var cam_impulse := Vector2.ZERO
var rig_base := Vector2(640, 470)
var trail: Line2D
var k := 1.0                     # 48px 单位 → 屏幕px 系数
var sprite_fit := 1.0            # 基准单元格内容 → 48 单位 的贴图缩放

var cur_kf_times: Array = []
var cur_kf_meta: Array = []
var last_kf_idx := -1
var hitstop_token := 0
var shake_amp := 0.0
var trail_on := false
var ghosts := []                 # [{node, life}]
var emit_cd := 0.0

var lbl_char: Label
var lbl_act: Label
var lbl_tier: Label
var lbl_kf: Label
var lbl_idx: Label
var lbl_help: Label
var lbl_flags: Label
var flag_rects := {}
var shot_path := ""
var grid_path := ""
var gif_dir := ""

func _ready() -> void:
	font = ArtBackdrop.cjk_font()
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	chars = data["characters"]
	kfs = data["keyframes"]
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
	_build_backdrop()
	_build_hud()
	afterimage_root = Node2D.new()
	afterimage_root.name = "AfterimageRoot"
	add_child(afterimage_root)
	trail = Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(1, 1, 1, 0.4)
	add_child(trail)
	if grid_path != "":
		_build_grid()
		_auto_grid()
	elif gif_dir != "":
		_auto_gif()
	else:
		_mount_character(0)
		if shot_path != "":
			_auto_shot()

func _build_backdrop() -> void:
	var bg := TextureRect.new()
	bg.texture = ArtBackdrop.checker_texture()
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

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

func _build_hud() -> void:
	lbl_char = _label("", Vector2(24, 14), 28)
	lbl_act = _label("", Vector2(24, 54), 20, Color(0.98, 0.85, 0.45))
	lbl_tier = _label("", Vector2(24, 86), 15, Color(0.72, 0.86, 1.0))
	lbl_kf = _label("", Vector2(880, 14), 19)
	lbl_idx = _label("", Vector2(880, 44), 14, Color(0.75, 0.8, 0.88))
	lbl_flags = _label("", Vector2(880, 70), 14)
	lbl_help = _label("A/D 切角色 · W/S 切动作 · J 播放 · K 暂停 · L 循环", Vector2(24, 688), 14, Color(0.7, 0.74, 0.82))
	var names := {"命中": Color(1, 0.4, 0.3), "无敌": Color(0.6, 1, 0.7), "轨迹": Color(0.6, 0.9, 1), "残影": Color(1, 0.8, 0.5), "震屏": Color(1, 0.6, 0.9), "顿帧": Color(1, 1, 0.6)}
	var x := 880.0
	for n in names:
		var r := ColorRect.new()
		r.position = Vector2(x, 100)
		r.size = Vector2(12, 12)
		r.color = Color(names[n], 0.15)
		add_child(r)
		var t := _label(n, Vector2(x + 16, 96), 13, Color(names[n], 0.35))
		flag_rects[n] = [r, t, names[n]]
		x += 62.0

func _kf_of(slug: String, action: String) -> Array:
	var out := []
	for kf in kfs:
		if kf["character_slug"] == slug and kf["action_slug"] == action:
			out.append(kf)
	return out

func _sheet_for(slug: String) -> Texture2D:
	return load("res://art/v5_base/%s.png" % slug)

## 从 JSON 重建当前角色的整套 AnimationPlayer 动画
func _mount_character(ci: int) -> void:
	for g in ghosts:
		g["node"].queue_free()
	ghosts.clear()
	trail.clear_points()
	if rig != null:
		rig.queue_free()
	var c: Dictionary = chars[ci]
	var col: Color = Color.html(String(c["primary"]))
	k = CHARS_H / BODY_UNIT
	sprite_fit = BODY_UNIT / float(CELL)   # 209px 单元内容 → 48 单位身体
	rig = Node2D.new()
	rig.name = "Rig"
	rig.position = rig_base
	rig.scale = Vector2(k, k)
	add_child(rig)

	visual_root = Node2D.new()
	visual_root.name = "VisualRoot"
	rig.add_child(visual_root)

	vfx_root = Node2D.new()
	vfx_root.name = "VFXRoot"
	vfx_root.z_index = -1
	visual_root.add_child(vfx_root)
	vfx_glow = Sprite2D.new()
	vfx_glow.texture = _radial_tex(col)
	vfx_glow.scale = Vector2(0.6, 0.6)
	vfx_glow.modulate = Color(1, 1, 1, 0.18)
	vfx_root.add_child(vfx_glow)

	form_overlay = Sprite2D.new()
	form_overlay.name = "FormOverlay"
	form_overlay.texture = _sheet_for(String(c["slug"]))
	form_overlay.region_enabled = true
	form_overlay.region_rect = Rect2(0, 0, CELL, CELL)
	form_overlay.scale = Vector2(sprite_fit * 1.32, sprite_fit * 1.32)
	# 法相 ghost：暖色过亮染色（乘法染色会把原图压暗）
	form_overlay.self_modulate = Color(1.9, 1.62, 1.12, 1.0)
	form_overlay.z_index = -2
	visual_root.add_child(form_overlay)

	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = _sheet_for(String(c["slug"]))
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, CELL, CELL)
	sprite.scale = Vector2(sprite_fit, sprite_fit)
	visual_root.add_child(sprite)

	hitbox_root = Node2D.new()
	hitbox_root.name = "HitboxRoot"
	hitbox_root.visible = false
	rig.add_child(hitbox_root)
	hitbox_ring = Sprite2D.new()
	hitbox_ring.texture = _ring_tex(Color(1, 0.42, 0.28))
	hitbox_ring.scale = Vector2(0.36, 0.36)
	hitbox_root.add_child(hitbox_ring)

	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	# root_node 指向场景根：方法轨道直接调用本脚本；节点路径带 Rig/ 前缀
	anim_player.root_node = NodePath("../..")
	rig.add_child(anim_player)
	var lib := AnimationLibrary.new()
	anim_player.add_animation_library("", lib)
	for a in c["actions"]:
		lib.add_animation(String(a[0]), _build_action(c, a))
	_apply_action()

func _build_action(c: Dictionary, a: Array) -> Animation:
	var slug := String(a[0])
	var cat := String(a[2])
	var kfs_a := _kf_of(String(c["slug"]), slug)
	var dur: float = float(kfs_a[kfs_a.size() - 1]["time_ms"]) / 1000.0
	var anim := Animation.new()
	anim.length = dur
	anim.loop_mode = Animation.LOOP_LINEAR if loop_on else Animation.LOOP_NONE
	var t_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_pos, NodePath("Rig/VisualRoot:position"))
	var t_pos2 := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_pos2, NodePath("Rig/HitboxRoot:position"))
	var t_rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_rot, NodePath("Rig/VisualRoot/Sprite2D:rotation"))
	var t_scl := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_scl, NodePath("Rig/VisualRoot/Sprite2D:scale"))
	var t_vfx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_vfx, NodePath("Rig/VisualRoot/VFXRoot:modulate:a"))
	var t_ovl := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_ovl, NodePath("Rig/VisualRoot/FormOverlay:modulate:a"))
	var t_m := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t_m, NodePath("."))
	for kf in kfs_a:
		var t: float = float(kf["time_ms"]) / 1000.0
		anim.track_insert_key(t_pos, t, Vector2(float(kf["body_x"]), float(kf["body_y"])))
		anim.track_insert_key(t_pos2, t, Vector2(float(kf["body_x"]), float(kf["body_y"])))
		anim.track_insert_key(t_rot, t, deg_to_rad(float(kf["rotation_deg"])))
		anim.track_insert_key(t_scl, t, Vector2(sprite_fit * float(kf["scale_x"]), sprite_fit * float(kf["scale_y"])))
		anim.track_insert_key(t_vfx, t, float(kf["vfx_intensity"]))
		var ovl: float = float(kf["vfx_intensity"]) * 0.55 if cat in ["法相", "终结技"] else 0.0
		anim.track_insert_key(t_ovl, t, ovl)
		var ev := {"method": "on_event", "args": [kf]}
		anim.track_insert_key(t_m, t, ev)
	return anim

## 方法轨道事件：命中/无敌/轨迹/残影/震屏/顿帧状态推进
func on_event(kf: Dictionary) -> void:
	hitbox_root.visible = bool(kf["hitbox_active"])
	if kf["hitbox_active"]:
		sprite.modulate = Color(2.0, 2.0, 2.0)
	set_invul(bool(kf["invulnerable"]))
	set_trail(bool(kf["trail_enabled"]))
	if float(kf["camera_shake"]) > 0.0:
		shake_amp = float(kf["camera_shake"])
	sprite.set_meta("kf_idx", int(kf["keyframe_index"]) - 1)

func set_invul(b: bool) -> void:
	sprite.self_modulate.a = 0.55 if b else 1.0

func set_trail(b: bool) -> void:
	trail_on = b
	if not b:
		trail.clear_points()

func _radial_tex(col: Color) -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(col, 0.85))
	grad.set_color(1, Color(col, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	return tex

func _ring_tex(col: Color) -> Texture2D:
	var img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var cc := Vector2(64, 64)
	for y in 128:
		for x in 128:
			var d := Vector2(x, y).distance_to(cc)
			var a := 0.0
			if d > 42.0 and d < 56.0:
				a = clampf(1.0 - absf(d - 49.0) / 7.0, 0.0, 1.0) * 0.95
			elif d <= 42.0:
				a = 0.05
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)

func _apply_action() -> void:
	var c: Dictionary = chars[char_idx]
	var a: Array = c["actions"][act_idx]
	var col := Color.html(String(c["primary"]))
	cur_kf_times.clear()
	cur_kf_meta.clear()
	for kf in _kf_of(String(c["slug"]), String(a[0])):
		cur_kf_times.append(float(kf["time_ms"]) / 1000.0)
		cur_kf_meta.append(kf)
	last_kf_idx = -1
	lbl_char.text = "%s · %s · 主色 %s" % [c["name"], c["slug"], c["primary"]]
	lbl_act.text = "%s · %s · %s" % [a[1], a[0], a[2]]
	lbl_tier.text = "source_tier: %s · 解锁来源: %s" % [a[3], a[4]]
	lbl_idx.text = "角色 %d/8 · 动作 %d/%d" % [char_idx + 1, act_idx + 1, c["actions"].size()]
	# 主色体现在 HUD 与特效（每角色严格用自己的 primary_color）
	lbl_act.add_theme_color_override("font_color", col.lightened(0.25))
	vfx_glow.texture = _radial_tex(col)
	trail.default_color = Color(col, 0.4)
	anim_player.play(String(a[0]))
	if not loop_on:
		anim_player.pause()

func _switch_char(d: int) -> void:
	char_idx = wrapi(char_idx + d, 0, chars.size())
	act_idx = 0
	_mount_character(char_idx)

func _switch_act(d: int) -> void:
	act_idx = wrapi(act_idx + d, 0, chars[char_idx]["actions"].size())
	_apply_action()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_switch_char(-1)
			KEY_D, KEY_RIGHT:
				_switch_char(1)
			KEY_W, KEY_UP:
				_switch_act(-1)
			KEY_S, KEY_DOWN:
				_switch_act(1)
			KEY_J:
				anim_player.speed_scale = 1.0
				anim_player.play(String(chars[char_idx]["actions"][act_idx][0]))
			KEY_K:
				anim_player.pause()
			KEY_L:
				loop_on = not loop_on
				for a in chars[char_idx]["actions"]:
					var an := anim_player.get_animation(String(a[0]))
					an.loop_mode = Animation.LOOP_LINEAR if loop_on else Animation.LOOP_NONE

func _pos_at(t: float) -> int:
	var i := 0
	while i < cur_kf_times.size() and cur_kf_times[i] <= t:
		i += 1
	return clampi(i - 1 if i > 0 else 0, 0, cur_kf_times.size() - 1)

func _process(delta: float) -> void:
	if anim_player == null or not anim_player.is_playing():
		return
	var t := anim_player.current_animation_position
	var idx := _pos_at(t)
	if idx != last_kf_idx:
		last_kf_idx = idx
		var kf: Dictionary = cur_kf_meta[idx]
		lbl_kf.text = "KF %d/%d · t=%dms" % [idx + 1, int(kf["keyframe_count"]), int(kf["time_ms"])]
		# 顿帧：命中帧处短暂冻结播放
		var hs: int = int(kf["hitstop_ms"])
		if hs > 0:
			hitstop_token += 1
			var token := hitstop_token
			anim_player.speed_scale = 0.0
			get_tree().create_timer(hs / 1000.0).timeout.connect(func():
				if token == hitstop_token:
					anim_player.speed_scale = 1.0)
	# 特效衰减与标签状态
	var kf2: Dictionary = cur_kf_meta[idx]
	sprite.modulate = sprite.modulate.lerp(Color.WHITE, minf(1.0, delta * 14.0))
	shake_amp = maxf(0.0, shake_amp - delta * 26.0)
	var sh := shake_amp * k * 0.12
	rig.position = rig_base + Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
	if trail_on:
		trail.add_point(visual_root.global_position)
		if trail.get_point_count() > 26:
			trail.remove_point(0)
	lbl_flags.text = ""
	var names := {"命中": kf2["hitbox_active"], "无敌": kf2["invulnerable"], "轨迹": kf2["trail_enabled"], "残影": int(kf2["afterimage_count"]) > 0, "震屏": float(kf2["camera_shake"]) > 0.0, "顿帧": int(kf2["hitstop_ms"]) > 0}
	for n in names:
		var on: bool = names[n]
		flag_rects[n][0].color = Color(flag_rects[n][2], 1.0 if on else 0.15)
		flag_rects[n][1].add_theme_color_override("font_color", Color(flag_rects[n][2], 1.0 if on else 0.35))
	# 残影发射
	var need: int = int(kf2["afterimage_count"])
	emit_cd -= delta
	if need > 0 and emit_cd <= 0.0:
		emit_cd = 0.4 / float(need)
		_spawn_ghost()
	for g in ghosts.duplicate():
		g["life"] -= delta
		g["node"].modulate.a = maxf(0.0, g["life"] / 0.36) * 0.5
		if g["life"] <= 0.0:
			g["node"].queue_free()
			ghosts.erase(g)

func _spawn_ghost() -> void:
	var c: Dictionary = chars[char_idx]
	var g := Sprite2D.new()
	g.texture = _sheet_for(String(c["slug"]))
	g.region_enabled = true
	g.region_rect = Rect2(0, 0, CELL, CELL)
	g.global_transform = sprite.global_transform
	g.self_modulate = Color(Color.html(String(c["primary"])), 0.5)
	afterimage_root.add_child(g)
	ghosts.append({"node": g, "life": 0.36})

func _save_shot(p: String) -> void:
	get_viewport().get_texture().get_image().save_png(p)
	print("[V5] saved: " + p)

func _auto_shot() -> void:
	# 主截图：悟空 法天象地（法相层级，高 vfx + 残影）
	_find_action(0, "form")
	await get_tree().create_timer(1.15).timeout
	_save_shot(shot_path)
	get_tree().quit()

func _find_action(ci: int, slug: String) -> void:
	char_idx = ci
	for i in chars[ci]["actions"].size():
		if String(chars[ci]["actions"][i][0]) == slug:
			act_idx = i
	_mount_character(ci)

func _build_grid() -> void:
	if rig != null:
		rig.queue_free()
		rig = null
	trail.clear_points()
	lbl_char.text = "8 角色同屏 · 各自 idle 程序动画 · 每角色严格使用自己的 primary_color"
	lbl_act.text = ""
	lbl_tier.text = ""
	lbl_kf.text = ""
	lbl_idx.text = ""
	lbl_flags.text = ""
	for i in chars.size():
		var c: Dictionary = chars[i]
		var col := Color.html(String(c["primary"]))
		var holder := Node2D.new()
		holder.name = "GridRig%d" % i
		holder.position = Vector2(105 + i * 154, 380)
		holder.scale = Vector2(0.5, 0.5)
		add_child(holder)
		var vr := Node2D.new()
		vr.name = "VisualRoot"
		holder.add_child(vr)
		var glow := Sprite2D.new()
		glow.texture = _radial_tex(col)
		glow.scale = Vector2(1.6, 1.6)
		glow.modulate = Color(1, 1, 1, 0.3)
		glow.z_index = -1
		vr.add_child(glow)
		var sp := Sprite2D.new()
		sp.texture = _sheet_for(String(c["slug"]))
		sp.region_enabled = true
		sp.region_rect = Rect2(0, 0, CELL, CELL)
		sp.scale = Vector2(BODY_UNIT / float(CELL), BODY_UNIT / float(CELL))
		vr.add_child(sp)
		var ap := AnimationPlayer.new()
		ap.root_node = NodePath("../..")
		holder.add_child(ap)
		var lib := AnimationLibrary.new()
		ap.add_animation_library("", lib)
		var kf_a := _kf_of(String(c["slug"]), "idle")
		var an := Animation.new()
		an.length = float(kf_a[kf_a.size() - 1]["time_ms"]) / 1000.0
		an.loop_mode = Animation.LOOP_LINEAR
		var t_pos := an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(t_pos, NodePath("GridRig%d/VisualRoot:position" % i))
		for kf in kf_a:
			an.track_insert_key(t_pos, float(kf["time_ms"]) / 1000.0, Vector2(float(kf["body_x"]), float(kf["body_y"])))
		lib.add_animation("idle", an)
		ap.play("idle")
		var l := _label("%s %s" % [c["name"], c["primary"]], Vector2(105 + i * 154 - 72, 470), 13, col.lightened(0.2))
		l.custom_minimum_size = Vector2(144, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position.x = 105 + i * 154 - 72

func _auto_grid() -> void:
	await get_tree().create_timer(0.7).timeout
	_save_shot(grid_path)
	get_tree().quit()

func _auto_gif() -> void:
	var seq := [[0, "form"], [0, "finisher"], [1, "form"], [4, "core_1"], [5, "core_1"], [6, "form"], [7, "core_2"]]
	var n := 0
	for pair in seq:
		_find_action(pair[0], String(pair[1]))
		await get_tree().create_timer(0.12).timeout
		for f in 6:
			await get_tree().create_timer(0.15).timeout
			_save_shot(gif_dir.path_join("f%03d.png" % n))
			n += 1
	print("[V5] gif frames done: %d" % n)
	get_tree().quit()
