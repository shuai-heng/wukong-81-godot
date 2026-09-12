extends Node2D
## V6 真实姿势技能预览：8 角色 × 83 动作 × 1322 程序关键帧 × 288 真实姿势 PNG
## 每个关键帧 = pose_file 离散换装（Sprite2D.texture DISCRETE 轨道）+ V5 全套程序轨道
## A/D 切角色 · W/S 切动作 · J 播放 · K 暂停 · L 循环
## 自动模式：--shot-path= | --contact-path= | --grid-path= | --gif-dir=

const DATA := "res://data/v6_1_full_keyframes_exact_pose.json"   # V6.1 精确 Pose 映射（V6 原数据已备份 .V6.backup.json）
const POSE_PREFIX := "01_真实PosePNG/"
const POSE_RES := "res://art/v6_pose/"
const POSE_CLEAN := "res://art/v6_pose_clean/"
const DEBUG_KEYS := "命中圈/无敌闪/轨迹/残影/震屏（F1 或 --debug-visuals 开）"
const CHARS_H := 360.0
const BODY_UNIT := 48.0

var chars: Array = []            # [{slug,name,primary,actions:[{slug,name,cat,tier,unlock,kfs:[...]}]}]
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
var rig_base := Vector2(640, 470)
var trail: Line2D
var k := 1.0
var sprite_fit := 1.0

var cur_kfs: Array = []
var last_kf_idx := -1
var hitstop_token := 0
var shake_amp := 0.0
var trail_on := false
var ghosts := []
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
var movie_mode := false
var movie_one := ""
var shot_kf := ""
var debug_visuals := false    # 调试可视化开关：命中圈/无敌闪/轨迹/残影/震屏；正式验收视频必须关
var contact_path := ""
var grid_path := ""
var gif_dir := ""

func _ready() -> void:
	font = ArtBackdrop.cjk_font()
	_load_model()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-path="):
			shot_path = arg.trim_prefix("--shot-path=")
		elif arg.begins_with("--contact-path="):
			contact_path = arg.trim_prefix("--contact-path=")
		elif arg.begins_with("--grid-path="):
			grid_path = arg.trim_prefix("--grid-path=")
		elif arg.begins_with("--gif-dir="):
			gif_dir = arg.trim_prefix("--gif-dir=")
		elif arg == "--movie":
			movie_mode = true
		elif arg.begins_with("--movie-one="):
			movie_one = arg.trim_prefix("--movie-one=")
		elif arg.begins_with("--shot-kf="):
			shot_kf = arg.trim_prefix("--shot-kf=")
		elif arg == "--debug-visuals":
			debug_visuals = true
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
	if contact_path != "":
		_build_contact("sun_wukong")
		_auto_save(contact_path)
	elif grid_path != "":
		_build_grid()
		_auto_save(grid_path)
	elif movie_mode:
		_run_movie_final()
	elif movie_one != "":
		_run_movie_one()
	elif shot_kf != "":
		_run_shot_kf()
	else:
		_mount_character(0)
		if shot_path != "":
			_auto_shot()

func _load_model() -> void:
	var kfs: Array = (JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary)["keyframes"]
	var by_slug := {}
	for kf in kfs:
		var slug := String(kf["character_slug"])
		if not by_slug.has(slug):
			by_slug[slug] = {"slug": slug, "name": String(kf["character_name"]), "primary": String(kf["primary_color"]), "actions": []}
		var c: Dictionary = by_slug[slug]
		var asl := String(kf["action_slug"])
		var act: Dictionary = c["actions"].back() if c["actions"].size() > 0 else {}
		if act.is_empty() or String(act["slug"]) != asl:
			act = {"slug": asl, "name": String(kf["action_name"]), "cat": String(kf["category"]), "tier": String(kf["source_tier"]), "unlock": String(kf["unlock_source"]), "kfs": []}
			c["actions"].append(act)
		act["kfs"].append(kf)
	chars = []
	for slug in by_slug:
		chars.append(by_slug[slug])

func _pose_res(kf: Dictionary) -> String:
	return _pose_tex_path(String(kf["pose_file"]).replace(POSE_PREFIX, ""))

func _pose_tex_path(rel: String) -> String:
	# 大面积特效姿势使用羽化圆角清理版（仅 alpha 外圈，人物本体未动）
	var clean := POSE_CLEAN + rel
	if ResourceLoader.exists(clean):
		return clean
	return POSE_RES + rel

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
	lbl_kf = _label("", Vector2(860, 14), 19)
	lbl_idx = _label("", Vector2(860, 44), 14, Color(0.75, 0.8, 0.88))
	lbl_flags = _label("", Vector2(860, 70), 14)
	if not debug_visuals:
		lbl_flags.visible = false
	lbl_help = _label("A/D 切角色 · W/S 切动作 · J 播放 · K 暂停 · L 循环", Vector2(24, 688), 14, Color(0.7, 0.74, 0.82))
	var names := {"命中": Color(1, 0.4, 0.3), "无敌": Color(0.6, 1, 0.7), "轨迹": Color(0.6, 0.9, 1), "残影": Color(1, 0.8, 0.5), "震屏": Color(1, 0.6, 0.9), "顿帧": Color(1, 1, 0.6)}
	var x := 860.0
	if not debug_visuals:
		return
	for n in names:
		var r := ColorRect.new()
		r.position = Vector2(x, 100)
		r.size = Vector2(12, 12)
		r.color = Color(names[n], 0.15)
		add_child(r)
		_label(n, Vector2(x + 16, 96), 13, Color(names[n], 0.35))
		flag_rects[n] = [r, names[n]]
		x += 62.0

## 从 JSON 重建当前角色的 AnimationPlayer：texture 离散轨道 + V5 全套程序轨道
func _mount_character(ci: int) -> void:
	for g in ghosts:
		g["node"].queue_free()
	ghosts.clear()
	trail.clear_points()
	if rig != null:
		rig.free()   # 立即释放：queue_free 延迟一帧会让新 Rig 被迫改名，轨道全部失配
	var c: Dictionary = chars[ci]
	var col := Color.html(String(c["primary"]))
	k = CHARS_H / BODY_UNIT
	sprite_fit = BODY_UNIT / 256.0    # 256px 姿势格 → 48 单位身体
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
	vfx_glow.scale = Vector2(0.85, 0.85)
	vfx_glow.modulate = Color(1, 1, 1, 0.18)
	vfx_root.add_child(vfx_glow)

	form_overlay = Sprite2D.new()
	form_overlay.name = "FormOverlay"
	form_overlay.scale = Vector2(sprite_fit * 1.3, sprite_fit * 1.3)
	form_overlay.self_modulate = Color(1.9, 1.62, 1.12, 1.0)
	form_overlay.z_index = -2
	visual_root.add_child(form_overlay)

	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(_pose_res(c["actions"][act_idx]["kfs"][0]))
	sprite.scale = Vector2(sprite_fit, sprite_fit)
	visual_root.add_child(sprite)

	hitbox_root = Node2D.new()
	hitbox_root.name = "HitboxRoot"
	hitbox_root.visible = false
	rig.add_child(hitbox_root)
	hitbox_ring = Sprite2D.new()
	hitbox_ring.texture = _ring_tex(Color(1, 0.42, 0.28))
	hitbox_ring.scale = Vector2(0.42, 0.42)
	hitbox_root.add_child(hitbox_ring)

	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	anim_player.root_node = NodePath("../..")
	rig.add_child(anim_player)
	var lib := AnimationLibrary.new()
	anim_player.add_animation_library("", lib)
	for a in c["actions"]:
		lib.add_animation(String(a["slug"]), _build_action(c, a))
	print("[V6.1] mount ", c["slug"], " anims=", lib.get_animation_list())
	_apply_action()

## 战斗阅读尺寸：普通动作 360px 级主体；法相/终结按动作放大（面板类姿势人物占比小，需更高倍率）
## 只调 Godot scale，不改源 PNG；画面单元格上限 1000px（终结技允许溢出屏幕的满屏演出）
const ACTION_READ_SCALE := {
	"sun_wukong:form": 1.3, "sun_wukong:finisher": 1.5,
	"tang_sanzang:form": 1.3,
	"white_dragon_prince:form": 1.35, "white_dragon_horse:form": 1.35,
	"zhu_bajie:form": 1.35,
	"sha_wujing:form": 1.35,
	"nezha:form": 1.4,
	"erlang_shen:form": 1.7, "erlang_shen:finisher": 2.6,
}
func _update_read_scale() -> void:
	var c: Dictionary = chars[char_idx]
	var a: Dictionary = c["actions"][act_idx]
	var cat := String(a["cat"])
	var mult := 1.0
	if ACTION_READ_SCALE.has(c["slug"] + ":" + a["slug"]):
		mult = float(ACTION_READ_SCALE[c["slug"] + ":" + a["slug"]])
	elif cat in ["法相", "终结技"]:
		mult = 1.14
	var cell := 256.0 * (BODY_UNIT / 256.0) * k * mult
	if cell > 1000.0:
		mult *= 1000.0 / cell
	if rig != null:
		rig.scale = Vector2(k * mult, k * mult)

func _build_action(c: Dictionary, a: Dictionary) -> Animation:
	var kfs_a: Array = a["kfs"]
	var cat := String(a["cat"])
	var dur: float = float(kfs_a[kfs_a.size() - 1]["time_ms"]) / 1000.0
	var anim := Animation.new()
	anim.length = dur
	anim.loop_mode = Animation.LOOP_LINEAR if loop_on else Animation.LOOP_NONE
	# 真实姿势离散换装轨道（Texture 不插值）
	var t_tex := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_tex, NodePath("Rig/VisualRoot/Sprite2D:texture"))
	anim.value_track_set_update_mode(t_tex, Animation.UPDATE_DISCRETE)
	var t_tex2 := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_tex2, NodePath("Rig/VisualRoot/FormOverlay:texture"))
	anim.value_track_set_update_mode(t_tex2, Animation.UPDATE_DISCRETE)
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
		var tex: Texture2D = load(_pose_res(kf))
		anim.track_insert_key(t_tex, t, tex)
		anim.track_insert_key(t_tex2, t, tex)
		anim.track_insert_key(t_pos, t, Vector2(float(kf["body_x"]), float(kf["body_y"])))
		anim.track_insert_key(t_pos2, t, Vector2(float(kf["body_x"]), float(kf["body_y"])))
		anim.track_insert_key(t_rot, t, deg_to_rad(float(kf["rotation_deg"])))
		anim.track_insert_key(t_scl, t, Vector2(sprite_fit * float(kf["scale_x"]), sprite_fit * float(kf["scale_y"])))
		anim.track_insert_key(t_vfx, t, float(kf["vfx_intensity"]))
		var ovl: float = float(kf["vfx_intensity"]) * 0.55 if cat in ["法相", "终结技"] else 0.0
		anim.track_insert_key(t_ovl, t, ovl)
		anim.track_insert_key(t_m, t, {"method": "on_event", "args": [kf]})
	return anim

func on_event(kf: Dictionary) -> void:
	# 命中白闪/顿帧属于真实演出；命中圈/无敌闪/轨迹/残影/震屏为调试可视化（debug_visuals 门控）
	hitbox_root.visible = debug_visuals and bool(kf["hitbox_active"])
	if kf["hitbox_active"]:
		sprite.modulate = Color(2.0, 2.0, 2.0)
	sprite.self_modulate.a = (0.55 if bool(kf["invulnerable"]) else 1.0) if debug_visuals else 1.0
	trail_on = debug_visuals and bool(kf["trail_enabled"])
	if not trail_on:
		trail.clear_points()
	if debug_visuals and float(kf["camera_shake"]) > 0.0:
		shake_amp = float(kf["camera_shake"])

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
	var a: Dictionary = c["actions"][act_idx]
	var col := Color.html(String(c["primary"]))
	cur_kfs = a["kfs"]
	last_kf_idx = -1
	lbl_char.text = "%s · %s · 主色 %s" % [c["name"], c["slug"], c["primary"]]
	lbl_act.text = "%s · %s · %s" % [a["name"], a["slug"], a["cat"]]
	lbl_tier.text = "source_tier: %s · 解锁来源: %s" % [a["tier"], a["unlock"]]
	lbl_idx.text = "角色 %d/8 · 动作 %d/%d" % [char_idx + 1, act_idx + 1, c["actions"].size()]
	lbl_act.add_theme_color_override("font_color", col.lightened(0.25))
	vfx_glow.texture = _radial_tex(col)
	trail.default_color = Color(col, 0.4)
	_update_read_scale()
	anim_player.play(String(a["slug"]))
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
				anim_player.play(String(chars[char_idx]["actions"][act_idx]["slug"]))
			KEY_K:
				anim_player.pause()
			KEY_F1:
				debug_visuals = not debug_visuals
				lbl_flags.visible = debug_visuals
			KEY_L:
				loop_on = not loop_on
				for a in chars[char_idx]["actions"]:
					anim_player.get_animation(String(a["slug"])).loop_mode = Animation.LOOP_LINEAR if loop_on else Animation.LOOP_NONE

func _pos_at(t: float) -> int:
	var i := 0
	while i < cur_kfs.size() and float(cur_kfs[i]["time_ms"]) / 1000.0 <= t:
		i += 1
	return clampi(i - 1 if i > 0 else 0, 0, cur_kfs.size() - 1)

func _process(delta: float) -> void:
	if anim_player == null or not anim_player.is_playing():
		return
	var t := anim_player.current_animation_position
	var idx := _pos_at(t)
	if idx != last_kf_idx:
		last_kf_idx = idx
		var kf: Dictionary = cur_kfs[idx]
		lbl_kf.text = "KF %d/%d · t=%dms · %s" % [idx + 1, int(kf["keyframe_count"]), int(kf["time_ms"]), kf["pose_note"]]
		var hs: int = int(kf["hitstop_ms"])
		if hs > 0:
			hitstop_token += 1
			var token := hitstop_token
			anim_player.speed_scale = 0.0
			get_tree().create_timer(hs / 1000.0).timeout.connect(func():
				if token == hitstop_token:
					anim_player.speed_scale = 1.0)
	var kf2: Dictionary = cur_kfs[idx]
	sprite.modulate = sprite.modulate.lerp(Color.WHITE, minf(1.0, delta * 14.0))
	shake_amp = maxf(0.0, shake_amp - delta * 26.0)
	var sh := shake_amp * k * 0.12 if debug_visuals else 0.0
	rig.position = rig_base + Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
	if trail_on and debug_visuals:
		trail.add_point(visual_root.global_position)
		if trail.get_point_count() > 26:
			trail.remove_point(0)
	for n in flag_rects:
		var on: bool = false
		match n:
			"命中": on = bool(kf2["hitbox_active"])
			"无敌": on = bool(kf2["invulnerable"])
			"轨迹": on = bool(kf2["trail_enabled"])
			"残影": on = int(kf2["afterimage_count"]) > 0
			"震屏": on = float(kf2["camera_shake"]) > 0.0
			"顿帧": on = int(kf2["hitstop_ms"]) > 0
		flag_rects[n][0].color = Color(flag_rects[n][1], 1.0 if on else 0.15)
	var need: int = int(kf2["afterimage_count"]) if debug_visuals else 0
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
	g.texture = sprite.texture
	g.global_transform = sprite.global_transform
	g.self_modulate = Color(Color.html(String(c["primary"])), 0.5)
	afterimage_root.add_child(g)
	ghosts.append({"node": g, "life": 0.36})

func _save_shot(p: String) -> void:
	get_viewport().get_texture().get_image().save_png(p)
	print("[V6] saved: " + p)

func _auto_save(p: String) -> void:
	await get_tree().create_timer(0.7).timeout
	_save_shot(p)
	get_tree().quit()

func _auto_shot() -> void:
	# 主截图：悟空 法天象地 中段（真实姿势连续切换 + 法相 overlay）
	_find_action(0, "form")
	await get_tree().create_timer(1.15).timeout
	_save_shot(shot_path)
	get_tree().quit()

func _find_action(ci: int, slug: String) -> bool:
	for i in chars[ci]["actions"].size():
		if String(chars[ci]["actions"][i]["slug"]) == slug:
			char_idx = ci
			act_idx = i
			_mount_character(ci)
			return true
	return false

func _build_contact(slug: String) -> void:
	# 36 姿势联络表：6×6，带 POSE_ID 标签
	var ci := 0
	for i in chars.size():
		if String(chars[i]["slug"]) == slug:
			ci = i
	var c: Dictionary = chars[ci]
	var col := Color.html(String(c["primary"]))
	lbl_char.text = "%s · 36 真实姿势联络表（01_真实PosePNG 全量）· 主色 %s" % [c["name"], c["primary"]]
	lbl_act.text = ""
	lbl_tier.text = ""
	lbl_flags.text = ""
	lbl_kf.text = ""
	lbl_idx.text = ""
	for pi in range(1, 37):
		var f := "%s__POSE_%02d__R%dC%d.png" % [slug, pi, (pi - 1) / 6 + 1, (pi - 1) % 6 + 1]
		var tr := TextureRect.new()
		tr.texture = load(POSE_RES + slug + "/" + f)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(84, 84)
		tr.position = Vector2(250 + ((pi - 1) % 6) * 136, 118 + ((pi - 1) / 6) * 96)
		tr.size = Vector2(84, 84)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(tr)
		var l := _label("POSE_%02d" % pi, Vector2(250 + ((pi - 1) % 6) * 136 + 16, 196 + ((pi - 1) / 6) * 96), 12, col.lightened(0.2))

func _build_grid() -> void:
	if rig != null:
		rig.queue_free()
		rig = null
	trail.clear_points()
	lbl_char.text = "8 角色同屏 · idle 真实姿势程序动画 · 每角色严格使用自己的 primary_color"
	lbl_act.text = ""
	lbl_tier.text = ""
	lbl_kf.text = ""
	lbl_idx.text = ""
	lbl_flags.text = ""
	for i in chars.size():
		var c: Dictionary = chars[i]
		var col := Color.html(String(c["primary"]))
		var idle_kfs: Array = c["actions"][0]["kfs"]
		var holder := Node2D.new()
		holder.name = "GridRig%d" % i
		holder.position = Vector2(105 + i * 154, 380)
		holder.scale = Vector2(0.56, 0.56)
		add_child(holder)
		var vr := Node2D.new()
		vr.name = "VisualRoot"
		holder.add_child(vr)
		var glow := Sprite2D.new()
		glow.texture = _radial_tex(col)
		glow.scale = Vector2(1.35, 1.35)
		glow.modulate = Color(1, 1, 1, 0.3)
		glow.z_index = -1
		vr.add_child(glow)
		var sp := Sprite2D.new()
		sp.name = "Sprite2D"
		sp.texture = load(_pose_res(idle_kfs[0]))
		sp.scale = Vector2(sprite_fit, sprite_fit)
		vr.add_child(sp)
		var ap := AnimationPlayer.new()
		ap.root_node = NodePath("../..")
		holder.add_child(ap)
		var lib := AnimationLibrary.new()
		ap.add_animation_library("", lib)
		var an := Animation.new()
		an.length = float(idle_kfs[idle_kfs.size() - 1]["time_ms"]) / 1000.0
		an.loop_mode = Animation.LOOP_LINEAR
		var t_tex := an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(t_tex, NodePath("GridRig%d/VisualRoot/Sprite2D:texture" % i))
		an.value_track_set_update_mode(t_tex, Animation.UPDATE_DISCRETE)
		var t_pos := an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(t_pos, NodePath("GridRig%d/VisualRoot:position" % i))
		for kf in idle_kfs:
			var t: float = float(kf["time_ms"]) / 1000.0
			an.track_insert_key(t_tex, t, load(_pose_res(kf)))
			an.track_insert_key(t_pos, t, Vector2(float(kf["body_x"]), float(kf["body_y"])))
		lib.add_animation("idle", an)
		ap.play("idle")
		var l := _label("%s %s" % [c["name"], c["primary"]], Vector2(105 + i * 154 - 72, 484), 13, col.lightened(0.2))
		l.custom_minimum_size = Vector2(144, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position.x = 105 + i * 154 - 72

## V6.1 验收视频：全部 83 动作连续真实播放（配合 --write-movie 逐帧录制，非时间点拼接）
func _run_movie() -> void:
	var total := 0
	for ci in chars.size():
		char_idx = ci   # 同步全局索引：_apply_action 依赖 char_idx/act_idx
		act_idx = 0
		_mount_character(ci)
		for ai in chars[ci]["actions"].size():
			act_idx = ai
			_apply_action()
			var slug := String(chars[ci]["actions"][ai]["slug"])
			print("[V6.1] play ", slug, " has=", anim_player.has_animation(slug))
			if anim_player.has_animation(slug):
				anim_player.get_animation(slug).loop_mode = Animation.LOOP_NONE
			await anim_player.animation_finished
			await get_tree().create_timer(0.12).timeout
			total += 1
	print("[V6.1] movie actions played: %d" % total)
	get_tree().quit()

## hotfix 取证：定格到指定关键帧截图（--shot-kf=<char>:<action>:<kf>）
func _run_shot_kf() -> void:
	var parts := shot_kf.split(":")
	var ci := 0
	for i in chars.size():
		if String(chars[i]["slug"]) == String(parts[0]):
			ci = i
	var asl := String(parts[1])
	var kfnum := int(parts[2])
	for ai in chars[ci]["actions"].size():
		if String(chars[ci]["actions"][ai]["slug"]) == asl:
			char_idx = ci
			act_idx = ai
	_mount_character(ci)
	anim_player.get_animation(asl).loop_mode = Animation.LOOP_NONE
	var t := 0.0
	for kf in cur_kfs:
		if int(kf["keyframe_index"]) == kfnum:
			t = float(kf["time_ms"]) / 1000.0
	anim_player.play(asl)
	anim_player.seek(t, true)
	anim_player.pause()
	var idx := _pos_at(t)
	var kf: Dictionary = cur_kfs[idx]
	lbl_kf.text = "KF %d/%d · t=%dms · %s" % [idx + 1, int(kf["keyframe_count"]), int(kf["time_ms"]), kf["pose_note"]]
	await get_tree().process_frame
	await get_tree().process_frame
	_save_shot(shot_path)
	get_tree().quit()

## hotfix 视频：单动作连播两遍（--movie-one=<char>:<action>，debug 关）
func _run_movie_one() -> void:
	if debug_visuals:
		print("[V6.1] REFUSING: movie requires debug_visuals off")
		get_tree().quit(2)
		return
	var parts := movie_one.split(":")
	var ci := 0
	for i in chars.size():
		if String(chars[i]["slug"]) == String(parts[0]):
			ci = i
	var asl := String(parts[1])
	for ai in chars[ci]["actions"].size():
		if String(chars[ci]["actions"][ai]["slug"]) == asl:
			char_idx = ci
			act_idx = ai
	_mount_character(ci)
	anim_player.get_animation(asl).loop_mode = Animation.LOOP_NONE
	await get_tree().create_timer(1.2).timeout
	_apply_action()
	anim_player.get_animation(asl).loop_mode = Animation.LOOP_NONE
	anim_player.play(asl)
	await anim_player.animation_finished
	await get_tree().create_timer(0.6).timeout
	print("[V6.1] movie-one done")
	get_tree().quit()

## 最终 polish 验收视频：指定动作链连续播放（--write-movie 逐帧，debug_visuals 必须关）
func _run_movie_final() -> void:
	if debug_visuals:
		print("[V6.1] REFUSING: final movie requires debug_visuals off")
		get_tree().quit(2)
		return
	var seq := {
		"sun_wukong": ["form", "unlock_1", "unlock_2", "finisher"],
		"tang_sanzang": ["core_1", "form"],
		"zhu_bajie": ["heavy", "core_1"],
		"nezha": ["form"],
		"erlang_shen": ["core_1", "finisher"],
	}
	var order := ["sun_wukong", "tang_sanzang", "zhu_bajie", "nezha", "erlang_shen"]
	var total := 0
	for slug in order:
		var ci := 0
		for i in chars.size():
			if String(chars[i]["slug"]) == slug:
				ci = i
		char_idx = ci
		act_idx = 0
		_mount_character(ci)
		# 每角色以 idle 起手，便于阅读切换
		await get_tree().create_timer(0.85).timeout
		for asl in seq[slug]:
			var found := false
			for ai in chars[ci]["actions"].size():
				if String(chars[ci]["actions"][ai]["slug"]) == String(asl):
					act_idx = ai
					found = true
			if not found:
				continue
			_apply_action()
			anim_player.get_animation(String(asl)).loop_mode = Animation.LOOP_NONE
			await anim_player.animation_finished
			await get_tree().create_timer(0.45).timeout
			total += 1
	print("[V6.1] final movie actions played: %d" % total)
	get_tree().quit()

func _auto_gif() -> void:
	# 指令·强制视觉验收 链路：每角色按指定动作顺序连续播放并抓帧
	var chains := {
		"sun_wukong": ["atk_combo", "heavy", "core_1", "unlock_1", "unlock_2", "form", "finisher"],
		"tang_sanzang": ["atk_combo", "core_1", "core_2", "unlock_1", "form", "finisher"],
		"white_dragon_prince": ["atk_combo", "dodge", "core_1", "unlock_1", "form", "finisher"],
		"white_dragon_horse": ["run", "dodge", "atk_combo", "core_1", "form", "finisher"],
		"zhu_bajie": ["atk_combo", "heavy", "core_1", "core_2", "unlock_1", "form", "finisher"],
		"sha_wujing": ["atk_combo", "core_1", "core_2", "unlock_1", "form", "finisher"],
		"nezha": ["atk_combo", "core_1", "core_2", "unlock_1", "unlock_2", "form", "finisher"],
		"erlang_shen": ["atk_combo", "core_1", "core_2", "unlock_1", "form", "finisher"],
	}
	var n := 0
	var ci := 0
	for c in chars:
		var slugs: Array = chains.get(String(c["slug"]), [])
		for asl in slugs:
			if not _find_action(ci, String(asl)):
				continue
			var dur: float = float(cur_kfs[cur_kfs.size() - 1]["time_ms"]) / 1000.0
			var marks := [0.18, 0.55, 0.88]
			for i in marks.size():
				var wait: float = dur * marks[i] if i == 0 else dur * (marks[i] - marks[i - 1])
				await get_tree().create_timer(wait).timeout
				_save_shot(gif_dir.path_join("f%03d.png" % n))
				n += 1
		ci += 1
	print("[V6] gif frames done: %d" % n)
	get_tree().quit()
