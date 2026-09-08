extends SceneTree
var game
var checks={}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.save=JourneySave.fresh();game.hud.title()
	await create_timer(.4).timeout
	checks.title=game.hud.menu_kind=="title"
	# Send mouse events through the actual GUI input path.
	for b in game.hud.overlay.find_children("*","Button",true,false):
		if b.text=="踏上取经路":
			var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=b.get_global_rect().get_center();click.pressed=true;root.push_input(click,true)
			await process_frame
			click=click.duplicate();click.pressed=false;root.push_input(click,true);break
	await create_timer(.3).timeout
	checks.new_game_button=game.mode=="battle" and game.player.hero=="tang"
	var start=game.player.position
	var key=InputEventKey.new();key.physical_keycode=KEY_D;key.pressed=true;Input.parse_input_event(key)
	await create_timer(.35).timeout
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
	checks.keyboard_movement=game.player.position.x>start.x+20
	key=InputEventKey.new();key.physical_keycode=KEY_Q;key.pressed=true;Input.parse_input_event(key)
	await create_timer(.3).timeout
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
	checks.keyboard_skill=game.player.cool.q>0
	checks.audio_stream=game.sound.music.playing and game.sound.cache.has("tang")
	checks.pixel_frames=game.player.sprite.sprite_frames.get_frame_count("atk")==8
	game.persist()
	checks.save_on_F=FileAccess.file_exists(OS.get_environment("W81_DATA_DIR").path_join("journey.json"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("W81_QA_DIR").path_join("pixel-package.png"))
	var f=FileAccess.open(OS.get_environment("W81_QA_DIR").path_join("pixel-package.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"  "));f.close()
	print("PACKAGE_SMOKE ",JSON.stringify(checks))
	game.queue_free();await process_frame;await create_timer(.2).timeout
	quit(0 if checks.values().all(func(v):return v) else 1)
