extends "res://scripts/game.gd"

# 旧完整游戏的章节/敌人/数值系统保持不动；只把 player 实例替换为 TangFighterV6R6。
# R6 = R5 Contact-only feedback + R4 低污染人物 Pose + R3 world-space projectile/contact
#      + 法相/终结技彻底退出 POSE30–36 烘焙技能板，改用干净 POSE13 人物形成法身。
# 切换其他英雄时仍逐级回退 JourneyFighter，不影响其他人物当前逻辑。
func _ready() -> void:
	super()
	call_deferred("_install_v6_player")

func _install_v6_player() -> void:
	if player is TangFighterV6R6:
		return
	var old := player
	var p := TangFighterV6R6.new()
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
