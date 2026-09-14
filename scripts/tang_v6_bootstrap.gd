extends Node

# 自动把唐僧 V6.1 视觉代理挂到旧完整游戏的 JourneyFighter。
const ACTOR := preload("res://scripts/tang_v6_actor.gd")
var _attached_id := 0

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p = scene.get("player")
	if p == null or not is_instance_valid(p):
		return
	var pid := int(p.get_instance_id())
	if _attached_id == pid and p.get_node_or_null("TangV6Actor") != null:
		return
	if p.get_node_or_null("TangV6Actor") == null:
		var actor := ACTOR.new()
		actor.name = "TangV6Actor"
		p.add_child(actor)
		actor.setup(p)
	_attached_id = pid
