extends "res://scripts/game.gd"

# 旧完整游戏的章节/敌人/数值系统保持不动；只把 player 实例替换为 TangFighterV6R9。
# R9 = R8 Release 短窗口 + R7 干净右掌前推 Pose + R6 干净法相 + R5 Contact-only feedback
#      + R4 低污染人物 Pose + R3 world-space projectile/contact。
# R9 只提升人物读形、延长平A Release 的肉眼可读窗口，并让法相方向严格跟当前可见人物；
# 不改伤害、CD、碰撞、护盾、净化、章节与敌人逻辑。
# 切换其他英雄时仍逐级回退 JourneyFighter，不影响其他人物当前逻辑。
func _ready() -> void:
	super()
	call_deferred("_install_v6_player")

func _install_v6_player() -> void:
	if player is TangFighterV6R9:
		return
	var old := player
	var p := TangFighterV6R9.new()
	p.game = self
	add_child(p)
	p.position = old.position
	p.build = old.build.duplicate(true)
	p.level = old.level
	p.xp = old.xp
	p.xp_next = old.xp_next
	p.kills = old.kills
	p.set_hero(old.hero)
	p.max_hp = old.max_hp
	p.hp = old.hp
	player = p
	old.queue_free()
	camera.position = player.position
