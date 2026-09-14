class_name TangSpellProjectileV6
extends Node2D

## 唐僧 V6 world-space 弹体。
## Release 后不再跟随人物；Contact 之后才伤害/Impact；撞地图障碍会在真实接触点消失。
var game
var caster
var velocity := Vector2.ZERO
var destination := Vector2.ZERO
var speed := 720.0
var life := 1.2
var damage := 0.0
var knock := 90.0
var hit_radius := 12.0
var impact_radius := 0.0
var primary := Color("F6C85F")
var secondary := Color("FFF7DC")
var kind := "bolt"
var target_id := 0
var homing := false
var grant_combo := false
var hit_group_id := 0
var cleanse := false
var is_ultimate := false
var style_index := 0
var _done := false
var _trail: Array[Vector2] = []

func configure(g, owner, start: Vector2, target: Vector2, dmg: float, p_kind := "bolt", opts := {}) -> void:
	game = g
	caster = owner
	global_position = start
	destination = target
	damage = dmg
	kind = p_kind
	speed = float(opts.get("speed", speed))
	life = float(opts.get("life", life))
	knock = float(opts.get("knock", knock))
	hit_radius = float(opts.get("hit_radius", hit_radius))
	impact_radius = float(opts.get("impact_radius", 0.0))
	primary = opts.get("primary", primary)
	secondary = opts.get("secondary", secondary)
	target_id = int(opts.get("target_id", 0))
	homing = bool(opts.get("homing", false))
	grant_combo = bool(opts.get("grant_combo", false))
	hit_group_id = int(opts.get("hit_group_id", 0))
	cleanse = bool(opts.get("cleanse", false))
	is_ultimate = bool(opts.get("is_ultimate", false))
	style_index = int(opts.get("style_index", 0)) % 3
	var d := destination - start
	velocity = (d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT) * speed
	_update_depth()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _done:
		return
	if game == null or not is_instance_valid(game):
		queue_free()
		return
	var target = instance_from_id(target_id) if target_id != 0 else null
	if homing and target is Node2D and is_instance_valid(target):
		destination = target.global_position
		var want := (destination - global_position).normalized() * speed
		velocity = velocity.lerp(want, minf(1.0, delta * 6.0))
	var prev := global_position
	global_position += velocity * delta
	life -= delta
	_update_depth()
	_trail.push_front(global_position)
	while _trail.size() > 7:
		_trail.pop_back()

	# 地图 Contact 优先：撞障碍/边界就在真实接触点消散。
	var world_contact = _find_world_contact(prev, global_position)
	if world_contact != null:
		global_position = world_contact
		_spawn_impact("wall", 18.0)
		_done = true
		queue_free()
		return

	# 高速线段扫掠，避免穿模。
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, prev, global_position)
		if closest.distance_to(e.global_position) <= hit_radius + 16.0:
			global_position = closest
			_impact(e)
			return

	if kind == "seal" and global_position.distance_to(destination) <= maxf(12.0, speed * delta * 1.1):
		global_position = destination
		_impact(null)
		return
	if life <= 0.0:
		_spawn_impact("wall", 12.0)
		_done = true
		queue_free()
		return
	queue_redraw()

func _find_world_contact(a: Vector2, b: Vector2):
	if game == null or game.world == null:
		return null
	var min_p := Vector2(36, 60)
	var max_p := PixelWorld.SIZE - Vector2(36, 36)
	if b.x < min_p.x or b.y < min_p.y or b.x > max_p.x or b.y > max_p.y:
		return b.clamp(min_p, max_p)
	for o in game.world.obstacles:
		var center := Vector2(o.x, o.y)
		var closest := Geometry2D.get_closest_point_to_segment(center, a, b)
		if closest.distance_to(center) <= float(o.z) + maxf(3.0, hit_radius * .55):
			return closest
	return null

func _deal(e, force: Vector2) -> bool:
	if caster != null and is_instance_valid(caster) and caster.has_method("tang_spell_hit"):
		return bool(caster.tang_spell_hit(e, damage, force, is_ultimate))
	if e == null or not is_instance_valid(e) or e.dead or e.tame_ready:
		return false
	return e.hit(damage, force, false, true, is_ultimate)

func _impact(direct_target) -> void:
	if _done:
		return
	_done = true
	var hit_any := false
	var hit_count := 0
	var dir := velocity.normalized()

	if impact_radius > 0.0:
		for e in game.foes.duplicate():
			if not is_instance_valid(e) or e.dead or e.tame_ready:
				continue
			var off := e.global_position - global_position
			if off.length() <= impact_radius + 20.0:
				var force := off.normalized() * knock if off.length_squared() > .01 else dir * knock
				if _deal(e, force):
					hit_any = true
					hit_count += 1
	else:
		var victim = direct_target
		if victim == null and target_id != 0:
			victim = instance_from_id(target_id)
		if victim is Node2D and is_instance_valid(victim) and not victim.dead and not victim.tame_ready:
			hit_any = _deal(victim, dir * knock)
			if hit_any:
				hit_count = 1

	if cleanse:
		var clean_r := impact_radius if impact_radius > 0.0 else 44.0
		game.clear_hazards(global_position, clean_r)
		# 旧 resolve_attack(cleanse) 同时能推进 seal/cleanse/rain 机制，继续保留。
		if global_position.distance_to(game.objective_at) < clean_r + 100.0 and game.chapter.mechanic in ["seal", "cleanse", "rain"]:
			game.mechanic_solved = true
	if hit_any and grant_combo and caster != null and is_instance_valid(caster):
		if caster.has_method("register_spell_hit"):
			caster.register_spell_hit(hit_group_id)
		else:
			caster.on_hit()

	var vfx_radius := 16.0
	match kind:
		"seal": vfx_radius = impact_radius
		"bead": vfx_radius = 20.0
		"ultimate": vfx_radius = 42.0
		_: vfx_radius = 16.0
	_spawn_impact(kind, vfx_radius)
	_apply_feedback(hit_any, hit_count)
	queue_free()

func _apply_feedback(hit_any: bool, hit_count: int) -> void:
	if not hit_any or game == null:
		return
	game.sound.play("heavy" if is_ultimate else "hit", .82)
	# 平A不夸张停顿；Q轻停；R才有明显重量。
	if game.feedback_gap <= 0.0:
		if is_ultimate:
			game.hitstop = maxf(game.hitstop, .050)
			game.shake = maxf(game.shake, 2.4)
			game.feedback_gap = .10
		elif kind == "seal":
			game.hitstop = maxf(game.hitstop, .018)
			game.shake = maxf(game.shake, .55)
			game.feedback_gap = .07
		elif kind == "bead" and hit_count >= 3:
			game.hitstop = maxf(game.hitstop, .010)
			game.feedback_gap = .06

func _spawn_impact(p_kind: String, p_radius: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	var fx := TangImpactV6.new()
	game.add_child(fx)
	fx.configure(global_position, p_kind, p_radius, primary, secondary, velocity.normalized())

func _update_depth() -> void:
	z_index = clampi(int(global_position.y / 10.0) + 2, 0, 220)

func _draw() -> void:
	# 2-4px 级短拖尾，完全来自弹体真实历史位置。
	for i in range(_trail.size() - 1):
		var a: Vector2 = _trail[i] - global_position
		var b: Vector2 = _trail[i + 1] - global_position
		var alpha := 0.26 * (1.0 - float(i) / maxf(1.0, _trail.size()))
		draw_line(a, b, Color(primary.r, primary.g, primary.b, alpha), maxf(1.0, 2.8 - i * .28))
	var ang := velocity.angle()
	if kind == "bead":
		draw_circle(Vector2.ZERO, 4.8, primary)
		draw_circle(Vector2.ZERO, 2.0, secondary)
		draw_line(Vector2(-7, 0).rotated(ang), Vector2(7, 0).rotated(ang), Color(secondary.r, secondary.g, secondary.b, .72), 1.0)
	elif kind == "seal":
		var pts := PackedVector2Array()
		for i in 8:
			pts.append(Vector2.from_angle(i * TAU / 8.0 + ang) * (10.0 if i % 2 == 0 else 6.0))
		draw_colored_polygon(pts, Color(primary.r, primary.g, primary.b, .72))
		draw_line(Vector2(-5, 0).rotated(ang), Vector2(5, 0).rotated(ang), secondary, 2.0)
		draw_line(Vector2(0, -5).rotated(ang), Vector2(0, 5).rotated(ang), secondary, 2.0)
	elif kind == "ultimate":
		var up := direction.rotated(-PI * .5)
		var p := PackedVector2Array([direction * 13.0, up * 7.0, -direction * 10.0, -up * 7.0])
		draw_colored_polygon(p, Color(primary.r, primary.g, primary.b, .84))
		draw_line(-direction * 13.0, direction * 16.0, secondary, 2.0)
	else:
		# 平A三拍只换几何节奏，不多造伤害弹。
		if style_index == 0:
			var p0 := PackedVector2Array([Vector2(10,0).rotated(ang), Vector2(0,-5).rotated(ang), Vector2(-7,0).rotated(ang), Vector2(0,5).rotated(ang)])
			draw_colored_polygon(p0, primary)
			draw_circle(Vector2.ZERO, 2.0, secondary)
		elif style_index == 1:
			draw_line(Vector2(-7,-3).rotated(ang), Vector2(9,-1).rotated(ang), secondary, 2.0)
			draw_line(Vector2(-6,3).rotated(ang), Vector2(8,1).rotated(ang), primary, 2.0)
			draw_circle(Vector2(7,0).rotated(ang), 2.2, secondary)
		else:
			var pts2 := PackedVector2Array()
			for i in 6:
				pts2.append(Vector2.from_angle(ang + i * TAU / 6.0) * (7.0 if i % 2 == 0 else 4.5))
			draw_colored_polygon(pts2, Color(primary.r, primary.g, primary.b, .84))
			draw_circle(Vector2.ZERO, 1.8, secondary)
