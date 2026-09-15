class_name TangFighterV6R8
extends "res://scripts/tang_fighter_v6_r7.gd"

## R8：Release 短窗口。
##
## R7 使用干净人物-only释放姿势；R8 让该姿势只在真正 KeyframeLib release 附近出现。
## 人物、palm、projectile 继续共用 kf_t/kf_release_t，不建立第二套时钟。

const R8_NO_RELEASE := 999.0

var _r8_last_release_action := ""
var _r8_last_release_mode := ""
var _r8_last_release_kf_t := -999.0

func _kf_release_tick() -> void:
	if kf_release_t < 0.0:
		return
	if String(kf_action) != String(kf_cast_action):
		kf_cancel_release()
		return
	if kf_t >= kf_release_t:
		var cb := kf_release_cb
		var release_at := kf_release_t
		var action_before := String(kf_action)
		var mode_before := _r4_mode
		_r8_last_release_action = action_before
		_r8_last_release_mode = mode_before
		_r8_last_release_kf_t = release_at
		kf_cancel_release()
		if hero == "tang" and kf_sprite != null:
			_apply_r4_visual(0.0)
		if cb.is_valid():
			cb.call()
	else:
		KeyframeLib.update_charge(self, kf_t / maxf(kf_release_t, .001))
		if kf_orb != null and kf_orb.visible:
			kf_orb.global_position = _r4_palm_world()

func kf_cancel_release() -> void:
	if kf_release_t >= 0.0 and String(kf_action) != String(kf_cast_action):
		_r8_last_release_action = ""
		_r8_last_release_mode = ""
		_r8_last_release_kf_t = -999.0
	super()

func set_hero(h: String) -> void:
	super(h)
	if h != "tang":
		_r8_last_release_action = ""
		_r8_last_release_mode = ""
		_r8_last_release_kf_t = -999.0

func _r8_release_delta(mode: String) -> float:
	if mode not in ["normal", "q", "g", "r"]:
		return R8_NO_RELEASE
	if kf_release_t >= 0.0 and String(kf_cast_action) == String(kf_action):
		return kf_t - kf_release_t
	if _r8_last_release_mode == mode and _r8_last_release_action == String(kf_action):
		return kf_t - _r8_last_release_kf_t
	return R8_NO_RELEASE

func _r4_pose_for(mode: String, p: float) -> int:
	var d := _r8_release_delta(mode)
	match mode:
		"normal":
			if d < R8_NO_RELEASE * .5:
				if d < -.20: return 13
				if d < -.07: return 2
				if d < -.018: return 3
				if d <= .115: return 24
				if d < .22: return 3
				if d < .34: return 2
				return 13
			if p < .26: return 13
			if p < .43: return 2
			if p < .58: return 3
			if p < .70: return 24
			if p < .82: return 3
			if p < .91: return 2
			return 13
		"q":
			if d < R8_NO_RELEASE * .5:
				if d < -.26: return 2
				if d < -.07: return 3
				if d <= .16: return 24
				if d < .30: return 3
				if d < .44: return 2
				return 13
			if p < .28: return 2
			if p < .46: return 3
			if p < .63: return 24
			if p < .78: return 3
			if p < .91: return 2
			return 13
		"g", "r":
			if _r5_release_hold_left > .001:
				return 24
			if d < R8_NO_RELEASE * .5:
				if d < -.30: return 2
				if d < -.08: return 3
				if d < 0.0: return 24
				if d < .15: return 3
				if d < .31: return 2
				return 13
			if p < .25: return 2
			if p < .44: return 3
			if p < .58: return 24
			if p < .76: return 3
			if p < .90: return 2
			return 13
		_:
			return super(mode, p)

func _apply_r4_visual(dt: float) -> void:
	super(dt)
	if hero != "tang" or kf_sprite == null or not kf_sprite.visible:
		return
	if _r4_pose_id == 24:
		var sign_x := -1.0 if kf_sprite.flip_h else 1.0
		kf_sprite.position.x += 2.4 * sign_x
		kf_sprite.position.y -= .8
		kf_sprite.rotation += deg_to_rad(-.8) * sign_x

func _r8_target_contact(at: Vector2, dir: Vector2) -> void:
	if game == null or not is_instance_valid(game):
		return
	var fx := TangImpactV6.new()
	game.add_child(fx)
	fx.configure(at, "ward_tick", 12.0, HeroIdentity.primary("tang"), HeroIdentity.secondary("tang"), dir)

func _release_e() -> void:
	shield = 3.0
	var ward := TangWardV6.new()
	game.add_child(ward)
	ward.configure(game, self, 3.0, 105.0, 4.0)
	_spawn_tang_impact(global_position, "robe", 170.0)
	var hits := 0
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		var off := e.global_position - global_position
		if off.length() > 190.0:
			continue
		var dir := off.normalized() if off.length_squared() > .01 else facing
		var force := dir * 200.0
		if tang_spell_hit(e, damage() * .4, force, false):
			hits += 1
			_r8_target_contact(e.global_position, dir)
	if hits > 0:
		on_hit()
