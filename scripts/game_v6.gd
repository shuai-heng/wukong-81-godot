extends "res://scripts/game.gd"

# 旧完整游戏的章节/敌人/数值系统保持不动；只把 player 实例替换为 TangFighterV6R2。
# R2 是唐僧新动作/技能正式运行时；切换其他英雄时仍逐级回退 JourneyFighter。
func _ready() -> void:
	super()
	call_deferred("_install_v6_player")

func _install_v6_player() -> void:
	if player is TangFighterV6R2:
		return
	var old := player
	var p := TangFighterV6R2.new()
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
