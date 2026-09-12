extends Node2D
## G15 美术试接入冒烟：用游戏正式脚本（player.gd / enemy.gd / boss.gd）渲染 5 张新 PNG，
## 证明它们已被 Godot 运行时真实读取（非文件夹摆拍）。保留原渲染 fallback。
## 运行: godot --path . res://scenes/art_smoke.tscn -- --shot-path=<绝对路径>

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BossScript := preload("res://scripts/boss.gd")

var shot_path := ""

## main.gd 的最小桩：只提供实体脚本运行所需的接口，不参与玩法
class StubMain extends Node2D:
	var player: Node2D
	var rng := RandomNumberGenerator.new()
	var trial := {}
	func spawn_fx(_p: Vector2, _r: float, _c: Color) -> void: pass
	func spawn_phantom(_p: Vector2, _f: bool) -> void: pass
	func toast(_t: String) -> void: pass
	func request_shake(_s: float) -> void: pass
	func on_hit_feedback(_p: Vector2, _d: float, _big: bool) -> void: pass
	func on_enemy_died(_p: Vector2) -> void: pass
	func on_boss_tame_ready() -> void: pass
	func on_boss_tamed(_h: String) -> void: pass
	func summon_minions(_p: Vector2, _n: int) -> void: pass
	func spawn_bullet(_p: Vector2, _d: Vector2, _s: float, _dmg: float) -> void: pass
	func try_switch_hero() -> void: pass

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-path="):
			shot_path = arg.trim_prefix("--shot-path=")
	_build()
	if shot_path != "":
		_auto_shot()

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = ArtBackdrop.checker_texture()
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.position = Vector2.ZERO
	bg.size = Vector2(640, 360)
	bg.z_index = -10
	add_child(bg)

	var main := StubMain.new()
	add_child(main)

	# 唐僧 / 孙悟空：正式 player.gd（hero 名与主游戏一致）
	var tang: CharacterBody2D = PlayerScript.new()
	tang.position = Vector2(80, 215)
	add_child(tang)
	tang.main = main
	var wukong: CharacterBody2D = PlayerScript.new()
	wukong.hero = "wukong"
	wukong.position = Vector2(190, 215)
	add_child(wukong)
	wukong.main = main
	main.player = tang

	# 狼妖：正式 enemy.gd
	var wolf := Node2D.new()
	wolf.set_script(EnemyScript)
	wolf.position = Vector2(310, 262)
	add_child(wolf)
	wolf.setup("wolf", main)

	# 黄风怪 / 牛魔王：正式 boss.gd（按章节 Boss 名映射正式 PNG）
	var ywk := Node2D.new()
	ywk.set_script(BossScript)
	ywk.position = Vector2(462, 210)
	add_child(ywk)
	ywk.setup(main, {"name": "黄风大圣", "hp": 1900.0, "speed": 0.0, "scale": 2.2, "behavior": "ranged", "ranged_every": 999.0})
	var bdk := Node2D.new()
	bdk.set_script(BossScript)
	bdk.position = Vector2(578, 215)
	add_child(bdk)
	bdk.setup(main, {"name": "牛魔王", "hp": 4000.0, "speed": 0.0, "scale": 2.4, "charge_every": 999.0})

	var font := ArtBackdrop.cjk_font()
	_label("G15 ART TRIAL SMOKE · 5 official PNGs rendered by player.gd / enemy.gd / boss.gd", Vector2(10, 4), 9, font)
	var names := [
		["唐僧 tang_sanzang", 80], ["孙悟空 sun_wukong", 190], ["狼妖 wolf_demon", 310],
		["黄风怪 yellow_wind_king", 462], ["牛魔王 bull_demon_king", 578],
	]
	for n in names:
		var text: String = n[0] if font != null else n[0].split(" ")[1]
		_label(text, Vector2(n[1] - 78, 296), 8, font, 156)

func _label(text: String, pos: Vector2, size: int, font: Font, width := 400) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.custom_minimum_size = Vector2(width, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	if font != null:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	add_child(lbl)

func _auto_shot() -> void:
	await get_tree().create_timer(0.55).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("[SMOKE] shot saved: " + shot_path)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
