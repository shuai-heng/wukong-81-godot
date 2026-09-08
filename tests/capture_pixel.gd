extends SceneTree

var game
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image()
	img.save_png("res://evidence/"+name+".png")

func run() -> void:
	JourneySave.override_dir=ProjectSettings.globalize_path("res://evidence/capture-save")
	game=load("res://scripts/game.gd").new();root.add_child(game)
	root.size=Vector2i(1440,810)
	await create_timer(.5).timeout
	await shot("pixel-title")
	game.new_journey()
	game.player.position=Vector2(1200,750);game.camera.position=game.player.position
	game.player.invulnerable=20
	for i in 15:game.spawn_enemy(game.player.position+Vector2.from_angle(i*TAU/15)*(110+10*(i%4)),"wolf" if i%3 else "bone")
	await create_timer(1.7).timeout
	game.player.cast("q")
	await create_timer(.28).timeout
	game.cinematic_left=0
	if game.hud.menu_kind=="upgrade":game.hud.pick(0)
	game.pending_upgrades=0
	await shot("pixel-wuxing")
	game.mode="menu";game.hud.roster();await shot("pixel-roster")
	game.save.unlocked=JourneyContent.HERO_ORDER.duplicate()
	for a in JourneyContent.ABILITIES:game.save.abilities[a]=true
	game.save.chapter=17;game.enter_chapter(17)
	game.player.position=Vector2(1200,860);game.camera.position=game.player.position
	game._advance_phase()
	game.player.invulnerable=15
	for i in 12:game.spawn_enemy(game.player.position+Vector2.from_angle(i*TAU/12)*165)
	await create_timer(1.7).timeout
	game.player.cast("q");await create_timer(.25).timeout;game.cinematic_left=0
	await shot("pixel-flaming")
	game.hud.route();await shot("pixel-route")
	game.queue_free();await process_frame;await process_frame
	quit(0)
