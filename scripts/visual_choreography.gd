extends Node
## M2-R5 visual choreography bootstrap.
## Attaches a visual-only rig to the current runtime Player without changing combat numbers.
## The rig reads the existing V6.1 KeyframeLib clock/anchors and never owns a second skill clock.

const RIG_SCRIPT := preload("res://scripts/visual_choreography_rig.gd")

var _attached_player_id := 0

func _process(_delta: float) -> void:
	var main := get_tree().get_first_node_in_group("main_ctl")
	if main == null:
		return
	var player_v = main.get("player")
	if not (player_v is CharacterBody2D):
		return
	var player := player_v as CharacterBody2D
	if not is_instance_valid(player):
		return
	var pid := int(player.get_instance_id())
	if _attached_player_id == pid and player.get_node_or_null("VisualChoreoRig") != null:
		return
	if player.get_node_or_null("VisualChoreoRig") == null:
		var rig := RIG_SCRIPT.new() as Node2D
		if rig == null:
			return
		rig.name = "VisualChoreoRig"
		player.add_child(rig)
	_attached_player_id = pid
