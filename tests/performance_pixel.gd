extends SceneTree

var game
var frame_times=[]
var process_times=[]
var counts=[]
func _initialize() -> void:call_deferred("run")

func run() -> void:
	game=load("res://scripts/game.gd").new();root.add_child(game)
	game.save=JourneySave.fresh();game.new_journey()
	game.save.unlocked=JourneyContent.HERO_ORDER.duplicate()
	for ability in JourneyContent.ABILITIES:game.save.abilities[ability]=true
	game.save.chapter=35;game.enter_chapter(17)
	game.player.position=Vector2(1200,820)
	var start=Time.get_ticks_usec();var last=start;var switch_at=-1
	while Time.get_ticks_usec()-start<14000000:
		var now=Time.get_ticks_usec();var seconds=(now-start)/1000000.0
		var h=mini(6,int(seconds/2))
		if h!=switch_at:game.select_hero(JourneyContent.HERO_ORDER[h]);switch_at=h
		# Invulnerability only stabilizes this synthetic renderer load, not progression tests.
		game.player.invulnerable=2;game.pending_upgrades=0
		if game.mode!="battle":game.mode="battle";game.hud.clear_menu()
		while game.foes.size()<70:
			game.spawn_enemy(game.player.position+Vector2.from_angle(randf()*TAU)*randf_range(100,300))
		for key in ["q","e","g"]:
			if game.player.cool[key]<=0:game.player.cast(key)
		if game.player.ultimate>=100:game.player.cast("r")
		await process_frame
		if seconds>1:
			frame_times.append((Time.get_ticks_usec()-last)/1000.0)
			process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			counts.append(game.foes.size())
		last=Time.get_ticks_usec()
	frame_times.sort();process_times.sort()
	var report={"scope":"14 seconds real GPU rendering, 70-enemy replenished load, seven heroes, real sound and skill effects; synthetic invulnerability used only for stable load", "frames":frame_times.size(),"frame_ms_p50":frame_times[int(frame_times.size()*.5)],"frame_ms_p95":frame_times[int(frame_times.size()*.95)],"process_ms_p95":process_times[int(process_times.size()*.95)],"max_enemies":counts.max(),"renderer":RenderingServer.get_video_adapter_name()}
	var f=FileAccess.open("res://evidence/pixel-performance.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print("PERFORMANCE ",JSON.stringify(report))
	game.queue_free();await process_frame;await create_timer(.2).timeout;quit()
