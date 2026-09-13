extends CharacterBody2D
## 玩家：WASD 移动 / 自动攻击 / 冲刺 / Q 乾坤一棒 / E 定地重击 / 法相·终结技（G02）

signal attacked
signal died
signal leveled
signal form_entered
signal ult_fired(pos: Vector2)

const SPEED_BASE := 130.0
const DASH_SPEED := 460.0
const DASH_TIME := 0.18
const DASH_CD_BASE := 1.2
const ATK_INTERVAL_BASE := 0.5
const ATK_RANGE_BASE := 95.0
const Q_CD_BASE := 2.9
const E_CD_BASE := 5.6
const Q_RADIUS := 195.0
const E_RADIUS := 175.0
const FORM_TIME_BASE := 9.0
const ULT_CD := 15.0
const WORLD := Rect2(24, 24, 1552, 1152)

var hp := 100.0
var max_hp := 100.0
var level := 1
var exp_pts := 0
var exp_next := 5
var kills := 0
var atk_count := 0
var q_count := 0
var e_count := 0
var ult_count := 0
var form_count := 0
var upgrades := {}                 # id -> level
var hero := "tang"                 # 出战英雄
var rage := 0.0                    # 八戒怒气 0-100
var wheels_left := 0.0             # 哪吒风火轮持续
var tone := Color.WHITE            # 英雄着色（受伤闪烁恢复基准）
var switch_count := 0
var shield_left := 0.0
var auto_pilot := false
var dash_cd_left := 0.0
var dash_left := 0.0
var dash_dir := Vector2.RIGHT
var dash_from := Vector2.ZERO
var atk_cd_left := 0.0
var atk_anim_left := 0.0
var hurt_cd := 0.0
var stance_step := 0
var q_cd_left := 0.0

var g_count := 0
var g_cd_left := 0.0
var dragon_left := 0.0
var e_cd_left := 0.0
var ult_cd_left := 0.0
var form_charge := 0.0             # 0-100 → 法相
var form_left := 0.0               # >0 即法相中
var ult := 0.0                     # 0-100（法相内可放终结）
var ai_skill_cd := 0.0
var sprite: AnimatedSprite2D
var main: Node2D
var art_scale := 1.0               # G15 新正式 PNG 归一缩放（只调 scale，不改源图）

# ---- V6.1 关键帧演出状态（KeyframeLib 驱动，纯视觉层） ----
var kf_sprite: Sprite2D
var kf_slug := ""                  # 当前角色 V6.1 slug；""=回退旧图集渲染
var kf_action := ""                # 当前动作；""=无（tick 会回落 idle/run/form 循环）
var kf_t := 0.0
var kf_one_shot := false
var kf_speed := 1.0
var kf_dragon := false             # 白龙化龙形态跟踪（切 prince/horse 两套姿势库）
var kf_fade_sprite: Sprite2D       # 子步2：交叉淡化层（旧姿势淡出）
var kf_xfade_left := 0.0
var kf_xfade_dur := 0.075
var kf_fade_base := Color.WHITE    # 快照时的着色（受伤/化龙 tint）
var kf_blend_left := 0.0           # 子步3：状态过渡混合计时
var kf_blend_dur := 0.1
var kf_glow_sprite: Sprite2D       # 子步4：vfx_intensity 发光层（ADD 混合）
var kf_trail: Line2D               # 子步4：trail_enabled 拖尾
var kf_seg := -1                   # 当前关键帧段索引（元数据触发去重）
var kf_freeze_left := 0.0          # 子步4：元数据顿帧定格计时
var kf_after_t := -1.0             # 子步4：上次残影生成的动作时刻（限频）
var kf_orb: Sprite2D               # R3：蓄力光点（锚点跟随，起手期凝聚）
var kf_release_t := -1.0           # R3：判定释放时刻（动作时间轴秒；-1=无待释放）
var kf_release_cb: Callable = Callable()  # R3：释放时结算的回调（伤害/特效/位移）
var kf_cast_action := ""           # R3：待释放判定的归属动作（被打断即取消）
# ---- R4 · 动作锚点编排：武器挥击弧（弧=真实棍端世界轨迹采样） ----
var kf_swing_id := -1
var kf_swing_action := ""
var kf_swing_kind := ""
var kf_swing_w0 := 0.0
var kf_swing_w1 := 0.0

# ---- 卡牌数值（web BALANCE_CAPS 同源） ----
func lvl(id: String) -> int:
	return upgrades.get(id, 0)

func dmg_mul() -> float:
	var m := 1.0 + Cards.CAPS["dmgPerLevel"] * lvl("dmg")
	if in_form():
		m *= 1.35 + 0.12 * lvl("w_giant")
	return m

func base_dmg() -> float:
	return Cards.hero_stat(hero, "dmg") * dmg_mul() * (1.25 if dragon_left > 0.0 else 1.0)

func cd_mul() -> float:
	return maxf(0.60, 1.0 - 0.12 * lvl("cdr")) * (0.8 if in_form() else 1.0)

func atk_interval() -> float:
	var m := ATK_INTERVAL_BASE * maxf(Cards.CAPS["atkCdMin"], 1.0 - 0.12 * lvl("atkSpeed"))
	if wheels_left > 0.0:
		m *= 0.55
	return m

func atk_range() -> float:
	return Cards.hero_stat(hero, "auto_range") * (1.0 + 0.16 * lvl("range")) * (1.0 + 0.08 * lvl("w_arc"))

func atk_arc() -> float:
	return deg_to_rad(65.0) + 0.3 * lvl("w_arc")

func crit_chance() -> float:
	return minf(Cards.CAPS["critMax"], 0.14 * lvl("crit"))

func dr() -> float:
	return minf(Cards.CAPS["drMax"], 0.10 * lvl("dr"))

func move_speed() -> float:
	var m := Cards.hero_stat(hero, "speed") * (1.0 + 0.07 * lvl("moveSpeed")) * (1.38 if dragon_left > 0.0 else 1.0)
	if wheels_left > 0.0:
		m *= 1.3 + 0.08 * lvl("n_wheels")
	return m

func dash_cd() -> float:
	return DASH_CD_BASE * maxf(Cards.CAPS["dashCdMin"], 1.0 - 0.22 * lvl("dashCd"))

func dash_dmg() -> float:
	return 20.0 + 14.0 * lvl("dashDmg")

func magnet_r() -> float:
	return 70.0 + 45.0 * lvl("magnet")

func in_form() -> bool:
	return form_left > 0.0

func ult_gain_mul() -> float:
	return 1.0 + 0.4 * lvl("ultGain")

# ---- 生命周期 ----
func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	tone = HERO_TONE[hero]
	var trial := SpriteLib.trial_tex("hero:" + hero)
	if trial != null:
		art_scale = SpriteLib.fit_scale(trial)
		sprite.sprite_frames = SpriteLib._frames_single(trial)
		sprite.scale = Vector2(art_scale, art_scale)
	else:
		sprite.sprite_frames = SpriteLib.build_frames(HERO_FRAME[hero])
	sprite.animation = "idle"
	sprite.play()
	add_child(sprite)
	KeyframeLib.attach(self)
	_kf_rebuild()

func _kf_rebuild() -> void:
	var slug := KeyframeLib.slug_for(hero, kf_dragon)
	if slug == kf_slug:
		return
	kf_slug = slug
	kf_action = ""
	kf_t = 0.0
	KeyframeLib.hide_visuals(self)
	# 新角色有关键帧库则整体换装（idle/run/技能全走 V6.1），否则保持旧图集
	sprite.visible = slug == ""

func _kf_act(action: String, one_shot := true) -> void:
	KeyframeLib.play_action(self, action, one_shot)

# ---- R3 · 完整技能释放编排：起手（蓄力光点跟锚点）→ 释放帧结算（伤害/主特效/位移）----
# _kf_cast 返回真实起手时长（秒），供落点预告等演出对齐；数据缺失时立即结算（旧手感兜底）。
func _kf_cast(action: String, cb: Callable) -> float:
	_kf_act(action)
	if kf_slug == "" or not KeyframeLib.has_action(kf_slug, action):
		if cb.is_valid():
			cb.call()
		return 0.0
	KeyframeLib.schedule_release(self, action, cb)
	return float(kf_release_t) / maxf(kf_speed, 0.01)

func kf_cancel_release() -> void:
	kf_release_t = -1.0
	kf_release_cb = Callable()
	kf_cast_action = ""
	if kf_orb != null:
		kf_orb.visible = false

func _kf_release_tick() -> void:
	if kf_release_t < 0.0:
		return
	if str(kf_action) != kf_cast_action:
		kf_cancel_release()   # 动作被打断/收招清空：未释放的判定作废
		return
	if kf_t >= kf_release_t:
		var cb: Callable = kf_release_cb
		kf_cancel_release()
		if cb.is_valid():
			cb.call()
	else:
		KeyframeLib.update_charge(self, kf_t / maxf(kf_release_t, 0.001))

# ---- R4 · 武器挥击弧：动作窗口内每物理帧把武器端点世界坐标喂给 main（弧=真实轨迹） ----
func _begin_swing(action: String, kind: String, color: Color, width := 8.0) -> void:
	if main == null or not main.has_method("swing_begin"):
		return
	if not KeyframeLib.has_body_track(String(kf_slug), action):
		return
	var w: Vector2 = KeyframeLib.swing_window(String(kf_slug), action)
	kf_swing_id = main.swing_begin(color, width)
	kf_swing_action = action
	kf_swing_kind = kind
	kf_swing_w0 = w.x
	kf_swing_w1 = w.y

func _kf_swing_tick() -> void:
	if kf_swing_id < 0:
		return
	if str(kf_action) != kf_swing_action or kf_t > kf_swing_w1 or kf_action == "":
		if main != null and main.has_method("swing_end"):
			main.swing_end(kf_swing_id)
		_end_swing()
		return
	if kf_t >= kf_swing_w0 and main != null and main.has_method("swing_point"):
		main.swing_point(kf_swing_id, KeyframeLib.body_anchor_world(self, kf_swing_kind))

func _end_swing() -> void:
	kf_swing_id = -1
	kf_swing_action = ""
	kf_swing_kind = ""

# ---- R3 · 演出反馈便捷口（老 main/桩主循环无新方法时自动退化） ----
func _fx_impact(pos: Vector2, r: float, color: Color) -> void:
	if main == null:
		return
	if main.has_method("spawn_impact"):
		main.spawn_impact(pos, r, color)
	else:
		main.spawn_fx(pos, r, color)

func _fx_shot(from: Vector2, to: Vector2, dur: float, color: Color, r := 9.0, on_arrive: Callable = Callable()) -> void:
	if main == null:
		return
	if main.has_method("spawn_skill_shot"):
		main.spawn_skill_shot(from, to, dur, color, r, on_arrive)
	else:
		_fx_impact(to, r * 2.0, color)
		if on_arrive.is_valid():
			on_arrive.call()

func _fx_mark(pos: Vector2, r: float, life: float, color: Color) -> void:
	if main != null and main.has_method("spawn_ground_mark"):
		main.spawn_ground_mark(pos, r, life, color)

func _fx_dust(pos: Vector2, r: float, n := 4) -> void:
	if main != null and main.has_method("spawn_dust"):
		main.spawn_dust(pos, r, n)

const HERO_FRAME := {"wukong": "wukong", "tang": "tang", "whiteDragon": "wolf", "bajie": "bone", "shaWujing": "tang", "nezha": "wolf", "erlang": "bone"}
const HERO_TONE := {"wukong": Color.WHITE, "tang": Color.WHITE, "whiteDragon": Color(0.75, 0.94, 1.0), "bajie": Color(1.0, 0.82, 0.62), "shaWujing": Color(1.0, 0.93, 0.72), "nezha": Color(1.0, 0.62, 0.5), "erlang": Color(0.8, 0.85, 0.95)}

func set_hero(h: String, silent := false) -> void:
	if hero == h:
		return
	hero = h
	dragon_left = 0.0
	sprite.modulate = Color.WHITE
	sprite.scale = (Vector2(1.16, 1.16) if in_form() else Vector2.ONE) * art_scale
	switch_count += 1
	rage = 0.0
	tone = HERO_TONE[h]
	var nt := SpriteLib.trial_tex("hero:" + h)
	if nt != null:
		art_scale = SpriteLib.fit_scale(nt)
		sprite.sprite_frames = SpriteLib._frames_single(nt)
	else:
		art_scale = 1.0
		sprite.sprite_frames = SpriteLib.build_frames(HERO_FRAME[h])
	sprite.play("idle")
	modulate = tone
	_kf_rebuild()
	main.toast("切换出战：" + Cards.HERO_STATS[h]["name"])

func _physics_process(delta: float) -> void:
	dash_cd_left = maxf(0.0, dash_cd_left - delta)
	atk_cd_left = maxf(0.0, atk_cd_left - delta)
	atk_anim_left = maxf(0.0, atk_anim_left - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	q_cd_left = maxf(0.0, q_cd_left - delta)
	e_cd_left = maxf(0.0, e_cd_left - delta)
	ult_cd_left = maxf(0.0, ult_cd_left - delta)
	ai_skill_cd = maxf(0.0, ai_skill_cd - delta)
	shield_left = maxf(0.0, shield_left - delta)
	wheels_left = maxf(0.0, wheels_left - delta)
	if hero == "tang" and shield_left > 0.0 and lvl("t_reflect") > 0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(global_position) < 90.0:
				e.take_hit(14.0 * lvl("t_reflect") * get_physics_process_delta_time() * 3.0, Vector2.ZERO)
	if lvl("regen") > 0 and hp < max_hp:
		hp = minf(max_hp, hp + 0.6 * lvl("regen") * delta)
	if in_form():
		form_left -= delta
		if form_left <= 0.0:
			_exit_form()

	var dir := Vector2.ZERO
	if auto_pilot:
		dir = _ai_drive(delta)
	else:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_just_pressed("dash") and dash_cd_left <= 0.0:
			_do_dash(dir)
		if Input.is_action_just_pressed("skill_q"):
			_cast_q()
		if Input.is_action_just_pressed("skill_e"):
			_cast_e()
		if Input.is_action_just_pressed("ult"):
			_cast_ult()
		if Input.is_action_just_pressed("gong") and g_cd_left <= 0.0:
			_cast_g()
		if Input.is_action_just_pressed("swap"):
			main.try_switch_hero()

	dragon_left = maxf(0.0, dragon_left - delta)
	g_cd_left = maxf(0.0, g_cd_left - delta)
	var dragon_on := dragon_left > 0.0
	if dragon_on != kf_dragon:
		kf_dragon = dragon_on
		_kf_rebuild()
	if dragon_left > 0.0:
		sprite.modulate = Color(0.62, 0.88, 1.0)
		sprite.scale = Vector2(1.22, 1.22) * art_scale
	else:
		sprite.modulate = Color.WHITE
		sprite.scale = (Vector2(1.16, 1.16) if in_form() else Vector2.ONE) * art_scale
	if dash_left > 0.0:
		dash_left -= delta
		velocity = dash_dir * DASH_SPEED
		modulate.a = 0.6
		if lvl("dashDmg") > 0:
			for e in get_tree().get_nodes_in_group("enemies"):
				if not e.has_method("take_hit"):
					continue
				if _seg_dist(e.global_position, dash_from, global_position) < 26.0 + e.hit_r:
					e.take_hit(dash_dmg(), dash_dir * 150.0)
	else:
		velocity = dir * move_speed()
		modulate.a = 1.0
	move_and_slide()
	global_position = global_position.clamp(WORLD.position, WORLD.end)
	queue_redraw()
	_update_anim(dir)
	_auto_attack()

## R3：脚下接地阴影（人物立于地图，冲刺时变淡拉长）
func _draw() -> void:
	var a := 0.30 if dash_left <= 0.0 else 0.15
	var rx := 17.0 if dash_left <= 0.0 else 24.0
	draw_set_transform(Vector2(0.0, 25.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, rx, Color(0.0, 0.0, 0.0, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---- 冒烟自动驾驶（含技能循环） ----
func _ai_drive(delta: float) -> Vector2:
	var target := _nearest_enemy()
	var dir := Vector2.ZERO
	if target:
		var to_t: Vector2 = target.global_position - global_position
		if hero == "tang":
			# R4：远程施法角色保持距离（唐僧远程平A 为负责人硬性要求）
			if to_t.length() > atk_range() * 0.72:
				dir = to_t.normalized()
			else:
				dir = to_t.normalized().orthogonal() * 0.35
		else:
			dir = to_t.normalized()
		if dash_cd_left <= 0.0 and ai_skill_cd <= 0.0:
			_do_dash(dir)
		if q_cd_left <= 0.0 and global_position.distance_to(target.global_position) < 195.0 * 0.9:
			_cast_q()
		if hero in ["tang", "whiteDragon"] and g_cd_left <= 0.0 and ai_skill_cd <= 0.0:
			_cast_g()
		if e_cd_left <= 0.0 and ai_skill_cd <= 0.0:
			var near := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(global_position) < 210.0:
					near += 1
			if near >= 3:
				_cast_e()
	if hero == "whiteDragon" and e_cd_left <= 0.0 and ai_skill_cd <= 0.0:
		_cast_e()
	if hero == "bajie" and e_cd_left <= 0.0 and rage >= 50.0 and ai_skill_cd <= 0.0:
		_cast_e()
	if hero == "shaWujing" and q_cd_left <= 0.0 and target and ai_skill_cd <= 0.0:
		_cast_q()
	if in_form() and ult >= 100.0 and ult_cd_left <= 0.0:
		_cast_ult()
	return dir

# ---- 冲刺 ----
func _do_dash(dir: Vector2) -> void:
	dash_left = DASH_TIME
	dash_cd_left = dash_cd()
	dash_dir = dir if dir != Vector2.ZERO else Vector2.RIGHT
	dash_from = global_position
	_kf_act("dodge")
	_fx_dust(global_position + Vector2(0, 20), 15.0, 4)   # 蹬地尘土（地图反馈）
	if hero == "wukong":
		# R4 · 筋斗闪（官方 pose_note：翻身入云→高速位移→落地滑步）：三段姿势残影
		main.spawn_phantom(global_position, sprite.flip_h)
		var tex: Texture2D = kf_sprite.texture if kf_sprite != null else null
		var scl: Vector2 = kf_sprite.scale if kf_sprite != null else Vector2.ONE
		var d := dash_dir
		for i in 2:
			get_tree().create_timer(0.06 * (i + 1)).timeout.connect(func() -> void:
				if main != null:
					main.spawn_phantom(global_position - d * 34.0 * (i + 1), sprite.flip_h, tex, scl, 0.30))

# ---- Q 乾坤一棒：周身环形横扫 ----
func _cast_q() -> void:
	if q_cd_left > 0.0:
		return
	if hero == "tang":
		_cast_q_tang()
		return
	if hero == "whiteDragon":
		_cast_q_dragon()
		return
	if hero == "bajie":
		_cast_q_bajie()
		return
	if hero == "shaWujing":
		_cast_q_sha()
		return
	if hero == "nezha":
		_cast_q_nezha()
		return
	if hero == "erlang":
		_cast_q_erlang()
		return
	q_cd_left = Q_CD_BASE * cd_mul()
	q_count += 1
	atk_anim_left = 0.25
	attacked.emit()
	var r := 195.0 * (1.0 + 0.16 * lvl("range"))
	var dmg := base_dmg() * 1.9
	var col := HeroIdentity.primary("wukong")
	# R4 · 毫毛分身阵（官方 pose_note：一化三→三化七→分身围攻→同步棍击）：
	# 释放帧分身从真身位置散开围击，伤害结算不变（半径内全部命中）
	_kf_cast("core_1", func() -> void:
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - global_position
			if off.length() <= r + e.hit_r:
				_hit_enemy(e, dmg, off.normalized() * 220.0)
		_fx_dust(global_position + Vector2(0, 22), r * 0.5, 6)
		# 分身围攻：5 个分身（当前姿势贴图）在真身周围散开，同步棍击闪光
		if main != null and main.has_method("spawn_phantom"):
			for i in 5:
				var ang := TAU * i / 5.0 + 0.5
				var cpos: Vector2 = global_position + Vector2(cos(ang), sin(ang) * 0.62) * (70.0 + 26.0 * (i % 2))
				var tex: Texture2D = kf_sprite.texture if kf_sprite != null else null
				var scl: Vector2 = kf_sprite.scale if kf_sprite != null else Vector2.ONE
				var life := 0.66 + 0.08 * (i % 3)
				get_tree().create_timer(0.05 * i).timeout.connect(func() -> void:
					if main != null:
						main.spawn_phantom(cpos, sprite.flip_h, tex, scl, life)
						main.spawn_fx(cpos, 44.0, col))
		_fx_impact(global_position, r * 0.8, col))

# ---- E 定地重击：落点 slamming ----
func _cast_e() -> void:
	if e_cd_left > 0.0:
		return
	if hero == "tang":
		_cast_e_tang()
		return
	if hero == "whiteDragon":
		_cast_e_dragon()
		return
	if hero == "bajie":
		_cast_e_bajie()
		return
	if hero == "shaWujing":
		_cast_e_sha()
		return
	if hero == "nezha":
		_cast_e_nezha()
		return
	if hero == "erlang":
		_cast_e_erlang()
		return
	e_cd_left = E_CD_BASE * cd_mul()
	e_count += 1
	atk_anim_left = 0.3
	attacked.emit()
	var target := _nearest_enemy_any()
	var center := global_position + Vector2(facing_x(), 0) * 190.0
	if target:
		center = target.global_position
	var r := E_RADIUS * (1.0 + 0.16 * lvl("range"))
	var dmg := base_dmg() * 2.4
	var col := HeroIdentity.primary("wukong")
	# R4 · 定海重棒（官方 pose_note：双手举棒→踏步下砸→地裂冲击→碎石落下）：
	# 起手期棍端轨迹弧 + 落点预告圈；释放帧砸在真实世界落点——地裂+碎石+尘土+震屏
	_begin_swing("heavy", "staff_tip", col, 9.0)
	var windup := _kf_cast("heavy", func() -> void:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(center) <= r + e.hit_r:
				_hit_enemy(e, dmg, (e.global_position - center).normalized() * 160.0)
		_fx_slam(center, r, col))
	_fx_mark(center, r, windup, col)

## R4 · 真实砸地组合：世界落点上 地裂 + 碎石 + 尘土 + 冲击环 + 震屏（地图参与战斗）
func _fx_slam(pos: Vector2, r: float, color: Color) -> void:
	if main == null:
		return
	if main.has_method("spawn_crack"):
		main.spawn_crack(pos, r * 0.85, color)
	if main.has_method("spawn_debris"):
		main.spawn_debris(pos + Vector2(0, 6), 9, Color("8a7458"))
	_fx_dust(pos, minf(r * 0.7, 90.0), 8)
	_fx_impact(pos, r * 1.05, color)
	if main.has_method("request_shake"):
		main.request_shake(10.0)

func facing_x() -> float:
	return -1.0 if sprite.flip_h else 1.0

func _nearest_enemy_any() -> Node2D:
	var best: Node2D = null
	var best_d := 460.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

# ---- 法相 / 终结技 ----
func add_form_charge(n: float) -> void:
	if in_form():
		return
	form_charge = minf(100.0, form_charge + n)
	if form_charge >= 100.0:
		form_charge = 0.0
		_enter_form()

func _enter_form() -> void:
	form_left = FORM_TIME_BASE + 1.6 * lvl("formDuration")
	form_count += 1
	_kf_act("form", false)
	sprite.scale = Vector2(1.16, 1.16) * art_scale
	modulate = Color(1.0, 0.9, 0.68)
	form_entered.emit()

func _exit_form() -> void:
	form_left = 0.0
	kf_action = ""
	KeyframeLib.hide_visuals(self)
	sprite.scale = Vector2.ONE * art_scale
	modulate = Color.WHITE

func _cast_ult() -> void:
	if not in_form() or ult < 100.0 or ult_cd_left > 0.0:
		return
	ult = 0.0
	ult_cd_left = ULT_CD
	ult_count += 1
	_kf_cast("finisher", func() -> void:
		var target := _nearest_enemy_any()
		var center := target.global_position if target else global_position
		for e in get_tree().get_nodes_in_group("enemies"):
			var d: float = e.global_position.distance_to(center)
			if d <= 260.0:
				e.take_hit(200.0, (e.global_position - center).normalized() * 260.0)
			elif d <= 520.0:
				e.take_hit(60.0, Vector2.ZERO)
		_fx_impact(center, 260.0, HeroIdentity.primary(hero))
		_fx_impact(center, 520.0, HeroIdentity.secondary(hero))
		ult_fired.emit(center))

# ---- 自动攻击 ----
func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _update_anim(dir: Vector2) -> void:
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0
	if kf_slug != "":
		KeyframeLib.tick(self, get_physics_process_delta_time(), velocity.length() > 5.0)
		_kf_release_tick()
		_kf_swing_tick()
		return
	if atk_anim_left > 0.0:
		sprite.play("atk")
	elif velocity.length() > 5.0:
		sprite.play("run")
	else:
		sprite.play("idle")

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := atk_range()
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _auto_attack() -> void:
	if atk_cd_left > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	atk_cd_left = atk_interval()
	atk_anim_left = 0.22
	atk_count += 1
	attacked.emit()
	var to_t: Vector2 = target.global_position - global_position
	sprite.flip_h = to_t.x < 0.0
	stance_step = (stance_step + 1) % 3
	var heavy := lvl("w_pose") > 0 and stance_step == 0
	var dmg := base_dmg() * (1.9 if heavy else 1.0)
	var rng := atk_range() * (1.35 if heavy else 1.0)
	var arc := atk_arc() * (1.2 if heavy else 1.0)
	# R4：唐僧=远程咒语弹幕（负责人硬性要求），其余英雄=近战（有锚点轨道者带真实武器弧）
	if hero == "tang":
		_auto_attack_tang(to_t, heavy, dmg, rng, arc, target)
		return
	var act := "heavy" if heavy else "atk_combo"
	_begin_swing(act, "staff_tip", HeroIdentity.primary(hero), 7.0)
	_kf_cast(act, func() -> void:
		var hit_any := false
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - global_position
			if off.length() <= (rng + e.hit_r) * 1.35 and absf(off.angle_to(to_t)) <= arc * 1.25:
				hit_any = true
				_hit_enemy(e, dmg, off.normalized() * 120.0)
		if hit_any:
			add_form_charge(2.0 * (1.0 + 0.45 * lvl("comboForm")))
			if in_form():
				ult = minf(100.0, ult + 1.6 * ult_gain_mul())
		_fx_impact(global_position + to_t.normalized() * minf(rng, maxf(to_t.length() - 8.0, 26.0)), 34.0, HeroIdentity.primary(hero)))

## R4 · 唐僧远程平A：九环锡杖环弹幕——释放帧从锡杖端逐敌发射追踪环弹，命中绑定到达。
## 每发伤害/受击弧资格与近战口径一致（伤害总量不变），弹体脱手后进入世界空间。
func _auto_attack_tang(to_t: Vector2, heavy: bool, dmg: float, rng: float, arc: float, primary_target: Node2D) -> void:
	var col := HeroIdentity.primary("tang")
	var col2 := HeroIdentity.secondary("tang")
	var fired := 0
	_kf_cast("atk_combo", func() -> void:
		# 杖尾点地（官方 pose_note）：短促地面脉冲
		if main != null and main.has_method("spawn_dust"):
			main.spawn_dust(KeyframeLib.body_anchor_world(self, "staff_tail") + Vector2(0, 8), 12.0, 2)
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - global_position
			if off.length() > (rng + e.hit_r) * 1.35 or absf(off.angle_to(to_t)) > arc * 1.25:
				continue
			fired += 1
			var vid := e.get_instance_id()
			var kn := off.normalized() * 120.0
			var delay := minf((fired - 1) * 0.035, 0.24)   # 弹幕依次脱手（首发立即）
			var from := KeyframeLib.body_anchor_world(self, "staff_tip")
			var shoot := func() -> void:
				var victim = instance_from_id(vid)
				if main == null or not main.has_method("spawn_ring_shot"):
					if victim is Node2D:
						_hit_enemy(victim, dmg, kn)   # 旧 main 兜底：直接结算
					return
				var to: Vector2 = victim.global_position if victim is Node2D else global_position + to_t.normalized() * rng
				main.spawn_ring_shot(from, to, maxf(0.10, from.distance_to(to) / 900.0), col, 9.0 + (3.0 if heavy else 0.0),
					func() -> void:
						var v2 = instance_from_id(vid)
						if v2 is Node2D:
							_hit_enemy(v2, dmg, kn)
							if main != null:
								main.spawn_fx(v2.global_position, 30.0, col2), victim)
			if delay <= 0.0:
				shoot.call()
			else:
				get_tree().create_timer(delay).timeout.connect(shoot)
		if fired > 0:   # 法相充能：每次攻击至多一次（与原近战口径一致）
			add_form_charge(2.0 * (1.0 + 0.45 * lvl("comboForm")))
			if in_form():
				ult = minf(100.0, ult + 1.6 * ult_gain_mul())
		elif main != null:
			main.spawn_fx(global_position + to_t.normalized() * 40.0, 18.0, col))

func _hit_enemy(e: Node2D, dmg: float, k: Vector2) -> void:
	var final_dmg := dmg
	if main.rng.randf() < crit_chance():
		final_dmg *= 2.0
	e.take_hit(final_dmg, k)
	main.on_hit_feedback(e.global_position, final_dmg, final_dmg >= 100.0)
	if lvl("burn") > 0:
		e.apply_burn(lvl("burn"), 3.0)
	if lvl("frost") > 0:
		e.apply_frost(1.5, 0.3 * lvl("frost"))

func take_damage(amount: float, knock: Vector2 = Vector2.ZERO, source: Node2D = null) -> void:
	if hurt_cd > 0.0 or dash_left > 0.0:
		return
	hurt_cd = 0.55
	var red := dr() + (0.35 if shield_left > 0.0 else 0.0)
	hp = maxf(0.0, hp - amount * (1.0 - minf(0.9, red)))
	modulate = Color(1.0, 0.5, 0.5)
	if hero == "bajie":
		rage = minf(100.0, rage + amount * 0.5 * (1.0 + 0.4 * lvl("b_fury")))
	get_tree().create_timer(0.12).timeout.connect(func(): modulate = tone * (Color(1.0, 0.9, 0.68) if in_form() else Color.WHITE))
	if source != null and source.has_method("take_hit") and lvl("thorns") > 0:
		source.take_hit(9.0 + 5.0 * lvl("thorns"), Vector2.ZERO)
	if knock != Vector2.ZERO:
		global_position += knock * 0.2
	if hp <= 0.0:
		died.emit()

func gain_exp(n: int) -> void:
	exp_pts += n
	while exp_pts >= exp_next:
		exp_pts -= exp_next
		level += 1
		# G10 修复：几何增长对齐 web 版（原线性 +3/级 在大规模击杀+双倍经验下产生升级/草稿风暴）
		exp_next = int(exp_next * 1.33)
		max_hp += 6.0
		hp = minf(max_hp, hp + 8.0)
		leveled.emit()

func on_kill_charge() -> void:
	kills += 1
	if lvl("lifesteal") > 0:
		hp = minf(max_hp, hp + 4.0 * lvl("lifesteal"))
	if in_form():
		ult = minf(100.0, ult + 5.0 * ult_gain_mul())
	else:
		add_form_charge(3.5 * (1.0 + 0.7 * lvl("killForm")))

func apply_card(id: String) -> void:
	upgrades[id] = lvl(id) + 1
	if id == "hp":
		max_hp += 28.0
		hp = max_hp

# ---- 唐僧：Q 净化梵环 / E 锦襕袈裟护体 ----

func _cast_g() -> void:
	if g_cd_left > 0.0:
		return
	if hero == "whiteDragon":
		if dragon_left > 0.0:
			return
		g_cd_left = 30.0
		g_count += 1
		dragon_left = 10.0
		return
	if hero != "tang":
		return
	g_cd_left = 25.0
	g_count += 1
	var dmg := 30.0 + 6.0 * lvl("t_nova")
	var col := HeroIdentity.primary("tang")
	var col2 := HeroIdentity.secondary("tang")
	# R4 · 诵经·定妖（官方 pose_note：诵经→经页浮空→梵文绕身→法圈扩大→妖怪迟滞→定身峰值）：
	# 起手期梵文星点绕身；释放帧从掌心锚点向每个敌人射出追踪念珠弹，命中绑定到达
	var windup := _kf_cast("unlock_1", func() -> void:
		var from := KeyframeLib.body_anchor_world(self, "palm")
		var any_hit := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_queued_for_deletion() or e.hp <= 0.0:
				continue
			any_hit = true
			var vid := e.get_instance_id()
			var victim = instance_from_id(vid)
			if main != null and main.has_method("spawn_bead") and victim is Node2D:
				main.spawn_bead(from, victim, 620.0, col, func() -> void:
					var v2 = instance_from_id(vid)
					if v2 is Node2D:
						v2.take_hit(dmg, (v2.global_position - global_position).normalized() * 40.0)
						if main != null:
							main.on_hit_feedback(v2.global_position, dmg, false)
							main.spawn_fx(v2.global_position, 26.0, col2))
			elif victim is Node2D:
				victim.take_hit(dmg, (victim.global_position - global_position).normalized() * 40.0)
		if not any_hit and main != null:
			main.spawn_fx(from, 20.0, col))
	if main != null and main.has_method("spawn_motes"):
		main.spawn_motes(self, windup, col, 9)


func _cast_q_tang() -> void:
	q_cd_left = Q_CD_BASE * cd_mul()
	q_count += 1
	atk_anim_left = 0.25
	attacked.emit()
	var r := 240.0 + 30.0 * lvl("t_nova")
	var dmg := base_dmg() * (1.7 + 0.08 * lvl("t_nova") * 4.0)
	var ring2 := lvl("t_ring")
	var col := HeroIdentity.primary("tang")
	var col2 := HeroIdentity.secondary("tang")
	# R4 · 禅音驱邪（官方 pose_note：合掌起咒→梵字浮现→音环扩散→第二层禅音→净化白闪）：
	# 起手期梵文星点绕身（跟锚点）；释放帧双环梵波从施法点扩散，
	# 波前抵达各敌人登记距离时结算（命中绑定到达，伤害值不变）
	var windup := _kf_cast("core_1", func() -> void:
		if main == null:
			for e in get_tree().get_nodes_in_group("enemies"):
				var off0: Vector2 = e.global_position - global_position
				if off0.length() <= r + e.hit_r:
					_hit_enemy(e, dmg, off0.normalized() * 140.0)
			return
		var hits := {}
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - global_position
			if off.length() <= r + e.hit_r:
				hits[e] = {"d": off.length(), "cb": func(e2: Node2D) -> void:
					if is_instance_valid(e2):
						_hit_enemy(e2, dmg, (e2.global_position - global_position).normalized() * 140.0)}
		if main.has_method("spawn_wave"):
			main.spawn_wave(global_position, r, 0.30, col, hits)
			# 第二层禅音（净化白闪）：0.12s 后第二道白闪波（视觉层，伤害已在首波登记）
			get_tree().create_timer(0.12).timeout.connect(func() -> void:
				if main != null and main.has_method("spawn_wave"):
					main.spawn_wave(global_position, r * 0.94, 0.26, col2, {}, true))
		else:
			for e in get_tree().get_nodes_in_group("enemies"):
				var off2: Vector2 = e.global_position - global_position
				if off2.length() <= r + e.hit_r:
					_hit_enemy(e, dmg, off2.normalized() * 140.0)
			_fx_impact(global_position, r, col))
	# 起手期梵文星点（跟锚点）
	if main != null and main.has_method("spawn_motes"):
		main.spawn_motes(self, windup, col, 7)
	# 九环余音：Q 命中后追加一道外环波（t_ring 卡牌，伤害口径不变）
	if ring2 > 0 and main != null:
		var r2 := r * 1.45
		var dmg2 := base_dmg() * 0.55
		get_tree().create_timer(windup + 0.30).timeout.connect(func() -> void:
			if main == null:
				return
			var hits2 := {}
			for e in get_tree().get_nodes_in_group("enemies"):
				var o2: Vector2 = e.global_position - global_position
				if o2.length() <= r2 + e.hit_r:
					hits2[e] = {"d": o2.length(), "cb": func(e3: Node2D) -> void:
						if is_instance_valid(e3):
							_hit_enemy(e3, dmg2, (e3.global_position - global_position).normalized() * 90.0)}
			if main.has_method("spawn_wave"):
				main.spawn_wave(global_position, r2, 0.30, col2, hits2)
			else:
				for e in get_tree().get_nodes_in_group("enemies"):
					var o3: Vector2 = e.global_position - global_position
					if o3.length() <= r2 + e.hit_r:
						_hit_enemy(e, dmg2, o3.normalized() * 90.0))

func _cast_e_tang() -> void:
	e_cd_left = E_CD_BASE * cd_mul()
	e_count += 1
	attacked.emit()
	shield_left = 2.8   # 护体即时生效（防御数值不延迟），演出在释放帧展开
	main.toast("锦襕袈裟：2.8 秒护体（减伤 35%，反噬需卡牌）")
	var col := HeroIdentity.primary("tang")
	# R4 · 锦襕袈裟（官方 pose_note：袈裟展开→金线成环→护盾闭合→受击光纹）：
	# 释放帧护体光环跟人展开（未脱手类技能跟随人物）
	_kf_cast("core_2", func() -> void:
		if main != null and main.has_method("spawn_aura"):
			main.spawn_aura(self, 2.8, col)
		_fx_impact(global_position, 120.0, col))

# ---- 小白龙：Q 龙牙穿浪（突进+路径伤害+刻龙痕） / E 引雷龙痕（按层数引爆） ----
func _cast_q_dragon() -> void:
	q_cd_left = Q_CD_BASE * 0.86 * cd_mul()
	q_count += 1
	atk_anim_left = 0.24
	attacked.emit()
	var glide_len := 340.0 + 70.0 * lvl("d_glide")
	var mark_ms := 4.0 + 2.0 * lvl("d_glide")
	var dmg := base_dmg() * 1.8
	# R3：起手蓄力（锚点光点）→ 释放帧蹬地尘土+突进+路径伤害（结算在位移后同帧）
	_kf_cast("core_1", func() -> void:
		var dir := Vector2(facing_x(), 0)
		var tgt := _nearest_enemy_any()
		if tgt:
			dir = (tgt.global_position - global_position).normalized()
			sprite.flip_h = dir.x < 0.0
		var to := (global_position + dir * glide_len).clamp(WORLD.position, WORLD.end)
		_fx_dust(global_position + Vector2(0, 20), 16.0, 5)
		for e in get_tree().get_nodes_in_group("enemies"):
			if _seg_dist(e.global_position, global_position, to) < 40.0 + e.hit_r:
				_hit_enemy(e, dmg, dir * 160.0)
				if e.has_method("apply_dragon"):
					e.apply_dragon(mark_ms)
		global_position = to
		main.spawn_phantom(global_position, sprite.flip_h)
		_fx_impact(to, 70.0, HeroIdentity.primary(hero)))

func _cast_e_dragon() -> void:
	e_cd_left = E_CD_BASE * cd_mul()
	e_count += 1
	attacked.emit()
	var r := 340.0 + 60.0 * lvl("d_call")
	# R3：起手聚雷 → 释放帧按当前龙痕分布引爆（雷束从锚点射向每个目标）
	_kf_cast("unlock_1", func() -> void:
		var boom := 0
		var tier3 := 0
		var marks: Array = []
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.has_method("has_dragon") or not e.has_dragon() or e.global_position.distance_to(global_position) > r:
				continue
			boom += 1
			var stk: int = e.dragon_stack
			e.dragon_stack = 0
			var dm := 62.0 + 18.0 * lvl("d_thunder")
			if stk >= 3:
				dm *= 2.2
				tier3 += 1
			elif stk == 2:
				dm *= 1.6
			marks.append([e, dm * dmg_mul()])
		for m in marks:
			var e: Node2D = m[0]
			if is_instance_valid(e):
				_fx_shot(KeyframeLib.anchor_world(self, "f"), e.global_position, 0.14, HeroIdentity.secondary(hero), 7.0, Callable())
		for m in marks:
			var e: Node2D = m[0]
			if is_instance_valid(e):
				_hit_enemy(e, float(m[1]), (e.global_position - global_position).normalized() * 120.0)
				_fx_impact(e.global_position, 60.0, HeroIdentity.secondary(hero))
		_fx_impact(global_position, r * 0.5, HeroIdentity.primary(hero))
		main.toast("引雷龙痕引爆 ×%d（三层天雷 ×%d）" % [boom, tier3]))

# ---- 八戒：Q 钉耙裂地（怒气满 50 强化） / E 倒卷天河（聚怪） ----
func _cast_q_bajie() -> void:
	var empowered := rage >= 50.0
	if empowered:
		rage -= 50.0
	q_cd_left = Q_CD_BASE * cd_mul()
	q_count += 1
	atk_anim_left = 0.28
	attacked.emit()
	var r := 195.0 * (1.0 + 0.18 * lvl("b_quake"))
	var dmg := base_dmg() * (1.7 * 1.15 * lvl("b_quake") if lvl("b_quake") > 0 else 1.7) * (1.6 if empowered else 1.0)
	_kf_cast("heavy" if empowered else "core_1", func() -> void:
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - global_position
			if off.length() <= r + e.hit_r:
				_hit_enemy(e, dmg, off.normalized() * (260.0 if empowered else 150.0))
		_fx_impact(global_position, r, HeroIdentity.primary(hero))
		_fx_dust(global_position + Vector2(0, 22), r * 0.6, 7)
		if empowered:
			shake_request(10.0))

func _cast_e_bajie() -> void:
	if rage < 50.0:
		main.toast("怒气不足 50：承伤积怒后再卷")
		return
	rage -= 50.0
	e_cd_left = E_CD_BASE * cd_mul()
	e_count += 1
	attacked.emit()
	var r := 300.0 + 60.0 * lvl("b_admiral")
	var pull := 190.0 + 40.0 * lvl("b_admiral")
	var dmg := base_dmg() * 0.8
	# R3：释放帧卷动——敌人被吸向当时的宝杖锚点方向
	_kf_cast("core_2", func() -> void:
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - global_position
			if off.length() <= r:
				var dir := -off.normalized()
				e.global_position += dir * pull
				_hit_enemy(e, dmg, Vector2.ZERO)
		_fx_impact(global_position, r, HeroIdentity.secondary(hero)))

# ---- 沙悟净：Q 宝杖去返（去+回两段） / E 流沙定域 ----
func _cast_q_sha() -> void:
	q_cd_left = Q_CD_BASE * cd_mul()
	q_count += 1
	atk_anim_left = 0.26
	attacked.emit()
	var spd_mul := 1.0 + 0.3 * lvl("s_speed")
	var dmg := base_dmg() * 1.7 * (1.0 + 0.1 * lvl("s_speed"))
	# R3：释放帧宝杖从锚点脱手飞出（弹体拖尾），落点命中后 0.3s 折返二段
	_kf_cast("core_1", func() -> void:
		var tgt := _nearest_enemy_any()
		var to := global_position + Vector2(facing_x(), 0) * 300.0
		if tgt:
			to = tgt.global_position
		var from := KeyframeLib.anchor_world(self, "f")
		_fx_shot(from, to, 0.18 / spd_mul, HeroIdentity.primary(hero), 11.0, Callable())
		for e in get_tree().get_nodes_in_group("enemies"):
			if _seg_dist(e.global_position, global_position, to) < 30.0 + e.hit_r:
				_hit_enemy(e, dmg, Vector2.ZERO)
		_fx_impact(to, 44.0, HeroIdentity.primary(hero))
		get_tree().create_timer(0.3 / spd_mul).timeout.connect(func():
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and _seg_dist(e.global_position, global_position, to) < 30.0 + e.hit_r:
					_hit_enemy(e, dmg * 1.3, Vector2.ZERO)
			_fx_impact(to, 52.0, HeroIdentity.secondary(hero))))

func _cast_e_sha() -> void:
	e_cd_left = E_CD_BASE * cd_mul()
	e_count += 1
	attacked.emit()
	var r := 260.0
	var slow_amt := 0.35 + 0.1 * lvl("s_erosion")
	var dmg := 24.0 + 12.0 * lvl("s_erosion")
	# R3：释放帧流沙铺场（地面焦痕=作用区域留驻）
	_kf_cast("core_2", func() -> void:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(global_position) <= r:
				e.apply_frost(2.0 + 0.5 * lvl("s_erosion"), slow_amt)
				e.take_hit(dmg, Vector2.ZERO)
		_fx_impact(global_position, r, HeroIdentity.primary(hero))
		if main.has_method("spawn_decal"):
			main.spawn_decal(global_position, r * 0.8, HeroIdentity.secondary(hero)))
	if lvl("s_guard") > 0:
		shield_left = maxf(shield_left, 1.0 + 0.5 * lvl("s_guard"))

func shake_request(s: float) -> void:
	main.request_shake(s)

# ---- 哪吒：Q 火尖枪突刺（直线穿刺+灼烧） / E 风火轮（加速+攻速+周身火环） ----
func _cast_q_nezha() -> void:
	q_cd_left = Q_CD_BASE * 0.8 * cd_mul()
	q_count += 1
	atk_anim_left = 0.22
	attacked.emit()
	var pierce_len := 360.0
	var dmg := base_dmg() * (2.0 + 0.2 * lvl("n_spear"))
	# R3：起手蓄力（枪尖锚点光点）→ 释放帧蹬地突进，路径灼烧，落点火尘
	_kf_cast("core_1", func() -> void:
		var dir := Vector2(facing_x(), 0)
		var tgt := _nearest_enemy_any()
		if tgt:
			dir = (tgt.global_position - global_position).normalized()
			sprite.flip_h = dir.x < 0.0
		var to := (global_position + dir * pierce_len).clamp(WORLD.position, WORLD.end)
		_fx_dust(global_position + Vector2(0, 20), 15.0, 5)
		for e in get_tree().get_nodes_in_group("enemies"):
			if _seg_dist(e.global_position, global_position, to) < 34.0 + e.hit_r:
				_hit_enemy(e, dmg, dir * 140.0)
				e.apply_burn(1 + lvl("n_spear"), 3.0)
		global_position = to
		_fx_impact(to, 56.0, HeroIdentity.primary(hero)))

func _cast_e_nezha() -> void:
	e_cd_left = E_CD_BASE * cd_mul()
	e_count += 1
	attacked.emit()
	wheels_left = 4.0 + 1.2 * lvl("n_wheels")   # 增益即时，火环演出在释放帧展开
	var r := 130.0
	var dmg := base_dmg() * 0.9
	_kf_cast("core_2", func() -> void:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(global_position) <= r:
				_hit_enemy(e, dmg, (e.global_position - global_position).normalized() * 130.0)
		_fx_impact(global_position, r, HeroIdentity.primary(hero)))
	main.toast("风火轮起：移速/攻速大增 %.1fs" % wheels_left)

# ---- 杨戬：Q 三尖两刃（宽弧重劈） / E 天眼射线（穿透直线） ----
func _cast_q_erlang() -> void:
	q_cd_left = Q_CD_BASE * cd_mul()
	q_count += 1
	atk_anim_left = 0.28
	attacked.emit()
	var reach := atk_range() * 2.0
	var dmg := base_dmg() * 2.3 * (1.0 + 0.18 * lvl("e_meishan"))
	# R3：释放帧在刀锋锚点甩出弧光（主特效从武器位置生成）
	_kf_cast("core_1", func() -> void:
		var to_t := Vector2(facing_x(), 0)
		var tgt := _nearest_enemy()
		if tgt == null:
			tgt = _nearest_enemy_any()
		if tgt:
			to_t = (tgt.global_position - global_position).normalized()
			sprite.flip_h = to_t.x < 0.0
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - global_position
			if off.length() <= reach + e.hit_r and absf(off.angle_to(to_t)) <= 0.85:
				_hit_enemy(e, dmg, off.normalized() * 200.0)
		_fx_shot(KeyframeLib.anchor_world(self, "f"), global_position + to_t * reach * 0.8, 0.12, HeroIdentity.primary(hero), 13.0, Callable())
		_fx_impact(global_position + to_t * reach * 0.5, 120.0, HeroIdentity.primary(hero)))

func _cast_e_erlang() -> void:
	e_cd_left = E_CD_BASE * cd_mul()
	e_count += 1
	attacked.emit()
	var beam_len := 700.0
	# R3：起手（额间锚点蓄光）→ 释放帧三尖两刃枪眼射出三束穿射弹体，
	# 中束抵达时结算穿透伤害（命中绑定轨迹到达）
	_kf_cast("core_2", func() -> void:
		var tgt := _nearest_enemy_any()
		var dir := Vector2(facing_x(), 0)
		if tgt:
			dir = (tgt.global_position - global_position).normalized()
			sprite.flip_h = dir.x < 0.0
		var dmg := base_dmg() * (2.6 * (1.0 + 0.25 * lvl("e_eye")))
		var from := KeyframeLib.anchor_world(self, "c")
		var end := (global_position + dir * beam_len).clamp(WORLD.position, WORLD.end)
		var perp := Vector2(-dir.y, dir.x) * 16.0
		_fx_shot(from + perp, end + perp, 0.15, HeroIdentity.primary(hero), 6.0, Callable())
		_fx_shot(from - perp, end - perp, 0.15, HeroIdentity.primary(hero), 6.0, Callable())
		_fx_shot(from, end, 0.15, HeroIdentity.secondary(hero), 9.0, func() -> void:
			var hits := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				var off: Vector2 = e.global_position - global_position
				if _seg_dist(e.global_position, global_position, global_position + dir * beam_len) < 26.0 + e.hit_r:
					_hit_enemy(e, dmg, Vector2.ZERO)
					hits += 1
			_fx_impact(end, 46.0, HeroIdentity.primary(hero))
			# 哮天犬：射线命中后咬残余
			if lvl("e_dog") > 0 and hits > 0:
				for e in get_tree().get_nodes_in_group("enemies"):
					if e.global_position.distance_to(global_position) < 200.0:
						e.take_hit(30.0 * lvl("e_dog"), (e.global_position - global_position).normalized() * 120.0)))
