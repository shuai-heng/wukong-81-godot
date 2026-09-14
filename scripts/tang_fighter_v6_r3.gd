class_name TangFighterV6R3
extends TangFighterV6R2

## R3：唐僧正式新技能执行层。
## - cast() 动态分派只走新 Q/E/G/R；旧 Tang 模板仅保留继承历史，不再运行。
## - 所有起手/释放仍由 KeyframeLib.kf_t 决定。
## - 释放后的余印/念珠/梵音矢不再 create_timer() 各自计时，统一挂到本角色 player-tick 时钟。
## - world-space projectile 自己负责 Travel -> Contact -> Impact。
## - 不改旧伤害/CD/护盾/净化/终结技上限等平衡口径。

var _r3_clock := 0.0
var _r3_jobs: Array = []

func tick(dt: float, input_enabled: bool=true) -> void:
	super(dt, input_enabled)
	# game hitstop 时 game.gd 不会调用 player.tick，因此这个时钟会和人物动作一起停住。
	_r3_clock += dt
	_drain_r3_jobs()

func _schedule_r3(delay: float, cb: Callable) -> void:
	_r3_jobs.append({"at": _r3_clock + maxf(0.0, delay), "cb": cb})

func _drain_r3_jobs() -> void:
	# 倒序删除，允许不同技能的后续释放共存；不会因为新动作开始而把已进入释放段的弹幕抹掉。
	for i in range(_r3_jobs.size() - 1, -1, -1):
		var job: Dictionary = _r3_jobs[i]
		if _r3_clock + .0001 < float(job.get("at", 0.0)):
			continue
		var cb: Callable = job.get("cb", Callable())
		_r3_jobs.remove_at(i)
		if cb.is_valid():
			cb.call()

# ====================== Q：掌印镇压 ======================
func _tang_q(target) -> void:
	# 旧 Q 数值不变：1.9×伤害、185+22*t_nova 范围、200击退、净化。
	# 改的是动作语义：掌印必须从 palm 飞出去，Contact 后才展开范围。
	var radius := 185.0 + 22.0 * upgrade("t_nova")
	var dmg := damage() * 1.9
	var target_pos := target.position if target != null else position + facing * 250.0
	var group := _next_spell_group()
	var cb := Callable(self, "_release_q_r3").bind(target_pos, dmg, radius, group)
	var windup := _kf_cast("core_1", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "q"

func _release_q_r3(target_pos: Vector2, dmg: float, radius: float, group: int) -> void:
	_spawn_spell(target_pos, dmg, "seal", {
		"speed": 560.0,
		"life": 1.15,
		"knock": 200.0,
		"impact_radius": radius,
		"grant_combo": true,
		"hit_group_id": group,
		"cleanse": true
	})
	var echo_lv := upgrade("t_ring")
	if echo_lv > 0:
		var echo_damage := dmg * .5 * echo_lv
		# 余印仍是同一次 Q 动作的 release continuation；不用独立 SceneTreeTimer。
		_schedule_r3(.24, Callable(self, "_release_q_echo_r3").bind(target_pos, echo_damage, radius * 1.30, group))

func _release_q_echo_r3(target_pos: Vector2, dmg: float, radius: float, group: int) -> void:
	if is_dead or game == null:
		return
	# 余印必须重新从此刻真实 palm 脱手，不能在目标点凭空爆第二圈。
	_spawn_spell(target_pos, dmg, "seal", {
		"speed": 610.0,
		"life": 1.0,
		"knock": 90.0,
		"impact_radius": radius,
		"grant_combo": true,
		"hit_group_id": group,
		"cleanse": true,
		"style_index": 1
	})

# ====================== E：锦襕袈裟 ======================
func _tang_e() -> void:
	var cb := Callable(self, "_release_e")
	var windup := _kf_cast("core_2", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "e"

# ====================== G：诵经·定妖 ======================
func _tang_g() -> void:
	var dmg := damage() * 2.2
	var cb := Callable(self, "_release_g").bind(dmg)
	var windup := _kf_cast("unlock_1", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "g"

func _release_g(dmg: float) -> void:
	# 旧 G 系统效果原样保留。
	hp = minf(max_hp, hp + max_hp * .18)
	game.clear_hazards(position, 420)
	reveal = 6
	if position.distance_to(game.objective_at) < 490.0 and game.chapter.mechanic in ["seal", "cleanse", "rain"]:
		game.mechanic_solved = true

	var ids: Array[int] = []
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		if position.distance_to(e.position) <= 390.0:
			ids.append(e.get_instance_id())
	var group := _next_spell_group()
	# 42ms 节奏分批释放。每枚真正生成时重新读取 palm，因此人物姿势变化会反映到来源点。
	for i in ids.size():
		var delay := float(i % 7) * .042 + floori(float(i) / 7.0) * .018
		_schedule_r3(delay, Callable(self, "_release_g_bead").bind(ids[i], dmg, group))

# ====================== R：大乘梵音·万字诛邪 ======================
func _ultimate() -> bool:
	if hero != "tang":
		return super()
	if form_left <= 0 or form_age < .8 or ultimate < 100:
		game.toast("法相中积满终结灵力后，按 R 释放")
		return false
	var primary := HeroIdentity.primary("tang")
	game.cinematic("大乘梵音·万字诛邪", primary)
	game.sound.play("ultimate")
	cool.r = 18
	invulnerable = maxf(invulnerable, .8)
	animate("cast", .7)
	var action := "finisher" if KeyframeLib.has_action(kf_slug, "finisher") else "unlock_1"
	var cb := Callable(self, "_release_r").bind(damage() * 8.0)
	var windup := _kf_cast(action, cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "r"
	# 不在这里 end_form()：最后一批梵音矢释放后才收法相。
	return true

func _release_r(dmg: float) -> void:
	var ids: Array[int] = []
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		if position.distance_to(e.position) <= 630.0:
			ids.append(e.get_instance_id())
	var group := _next_spell_group()
	var last_delay := 0.0
	for i in ids.size():
		var delay := float(i % 8) * .040 + floori(float(i) / 8.0) * .080
		last_delay = maxf(last_delay, delay)
		_schedule_r3(delay, Callable(self, "_release_r_arrow").bind(ids[i], dmg, group))
	# 起手视觉由 _draw() 的扇形经文 + V6 法相承担，不在掌心伪造一个“Impact”。
	# 空场也要自然收法相；有目标则等最后一批真正 release 后再收束。
	_schedule_r3(last_delay + .20, Callable(self, "_finish_r_form"))

# ====================== 受击反射：清除最后一个旧 ring 模板 ======================
func take_hit(amount: float, from: Vector2) -> bool:
	if hero != "tang":
		return super(amount, from)
	if invulnerable > 0 or dash_left > 0 or is_dead:
		return false
	amount *= float(game.save.settings.get("difficulty", 1.0))
	var reduction := minf(.65, .08 * upgrade("dr") + (.4 if shield > 0 else 0))
	var actual := amount * (1 - reduction)
	hp = maxf(0, hp - actual)
	invulnerable = .55
	combo = 0
	combo_left = 0
	if anim_left <= 0:
		animate("hurt", .2)
	game.sound.play("hurt")
	game.fx.number(position, "-" + str(int(actual)), Color("ff8d88"), true)
	game.shake = maxf(game.shake, 4)
	game.hurt_flash = .22
	var away := position - from
	if away.length_squared() > .001:
		position = game.world.resolve(position + away.normalized() * 9, 10)

	var reflect_damage := 8.0 + 5.0 * upgrade("thorns") + 8.0 * upgrade("t_reflect")
	var reflect_enabled := upgrade("thorns") > 0 or (shield > 0 and upgrade("t_reflect") > 0)
	if reflect_enabled:
		# 旧逻辑是 70 半径 circle/ring；新逻辑保持同一近身筛选范围和伤害，
		# 但每个目标必须接到一枚从实时 palm 发出的短程经文珠，Contact 后才受伤。
		_schedule_r3(.02, Callable(self, "_release_reflect_r3").bind(reflect_damage))
	if hp <= 0:
		is_dead = true
		game.fail_run()
	return true

func _release_reflect_r3(dmg: float) -> void:
	if is_dead or game == null:
		return
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		if e.global_position.distance_to(global_position) > 70.0:
			continue
		_spawn_spell(e.global_position, dmg, "bead", {
			"speed": 680.0,
			"life": .42,
			"knock": 60.0,
			"target_id": e.get_instance_id(),
			"homing": true,
			"grant_combo": false,
			"hit_group_id": 0
		})
