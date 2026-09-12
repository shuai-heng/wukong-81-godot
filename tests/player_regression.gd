extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "CDriveRepairValidation-20260908":
		printerr("Run this test in an isolated validation copy; see repair evidence.")
		quit(2)
		return
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var p = scene.player
	p.upgrades.clear()
	p.set_hero("tang")
	check(p.get_script() != null, "player script attached")
	check(p.hp == 100.0 and p.magnet_r() == 70.0, "health and pickup API")
	p.take_damage(10.0)
	check(p.hp == 90.0, "damage API")
	var enemy = load("res://scripts/enemy.gd").new()
	enemy.setup("wolf", scene)
	enemy.position = Vector2(1100, 900)
	scene.add_child(enemy)
	p._cast_g()
	check(p.g_count == 1 and p.g_cd_left == 25.0, "Tang G")
	check(enemy.hp == 30.0, "Tang G damages real enemy")
	p._cast_g()
	check(p.g_count == 1, "G cooldown rejects repeat")
	p._physics_process(1.0)
	check(p.g_cd_left == 24.0, "G cooldown ticks")
	p.set_hero("whiteDragon")
	p.g_cd_left = 0.0
	var speed = p.move_speed()
	var damage = p.base_dmg()
	p._cast_g()
	check(p.dragon_left == 10.0 and p.g_cd_left == 30.0, "dragon activation")
	check(is_equal_approx(p.move_speed(), speed * 1.38), "dragon speed")
	check(is_equal_approx(p.base_dmg(), damage * 1.25), "dragon damage")
	p._physics_process(0.1)
	check(p.sprite.scale == Vector2(1.22, 1.22), "dragon visual active")
	p.dragon_left = 0.01
	p._physics_process(0.02)
	check(p.dragon_left == 0.0 and p.sprite.scale == Vector2.ONE and p.sprite.modulate == Color.WHITE, "dragon expires")
	p.g_cd_left = 0.0
	p._cast_g()
	p.set_hero("tang")
	check(p.dragon_left == 0.0 and p.sprite.scale == Vector2.ONE, "switch clears dragon")
	for i in 120:
		await physics_frame
	print("PLAYER_REGRESSION failures=", failures)
	quit(0 if failures == 0 else 1)
