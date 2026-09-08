extends SceneTree

var checks=[]
var game
func _initialize() -> void:call_deferred("run")
func check(name: String,ok: bool,detail: Variant="") -> void:
	checks.append({"name":name,"pass":ok,"detail":detail})
	if not ok:printerr("CHECK FAILED ",name," ",detail)

func run() -> void:
	JourneySave.override_dir=ProjectSettings.globalize_path("res://evidence/test-save")
	game=load("res://scripts/game.gd").new();root.add_child(game)
	game.set_process(false);game.new_journey()
	check("fresh_tang_only",game.save.unlocked==["tang"] and game.player.hero=="tang")
	var count=0
	for i in JourneyContent.ROUTE.size():
		var c=JourneyContent.chapter(i);count+=c.objectives.size()
		check("chapter_content_"+c.id,ResourceLoader.exists("res://assets/pixel/"+c.sprite+".png") and JourneyContent.THEMES.has(c.theme) and c.objectives.size()>=2)
	check("81_authored_event_sections",count==81,count)
	for i in JourneyContent.STORIES.size():
		var s=JourneyContent.story(i)
		check("story_content_"+s.id,JourneyContent.HEROES.has(s.hero) and not s.subtitle.is_empty())
	var p=game.player
	game.save.unlocked=JourneyContent.HERO_ORDER.duplicate()
	var seen=[]
	for i in 7:game.cycle_hero();seen.append(p.hero)
	check("seven_heroes_reachable",seen.size()==7 and JourneyContent.HERO_ORDER.all(func(h):return seen.has(h)),seen)
	for h in JourneyContent.HERO_ORDER:
		game.select_hero(h)
		check("sprite_animations_"+h,p.sprite.sprite_frames.get_frame_count("run")==8 and p.sprite.sprite_frames.get_frame_count("cast")==8)
	game.select_hero("tang")
	var e=game.spawn_enemy(p.position+Vector2(80,0),"wolf",false)
	e.elite=false;e.hp=1000;e.max_hp=1000
	game.sound.last.clear();var old_hp=e.hp
	e.hit(10,Vector2.ZERO)
	check("nonlethal_hit_requests_audio",game.sound.last.has("hit") and e.hp<old_hp)
	game.hitstop=.2
	var before=e.position
	var before_cd=float(p.cool.q)
	game._process(.05)
	check("hitstop_freezes_combat",e.position==before and float(p.cool.q)==before_cd)
	game.hitstop=0
	var old_kills=p.kills;e.hp=1;e.hit(5,Vector2.ZERO);e.hit(5,Vector2.ZERO)
	check("death_settles_once",p.kills-old_kills==1,p.kills-old_kills)
	p.form_left=1;p.ultimate=87;p.end_form()
	check("form_exit_clears_ultimate",p.ultimate==0)
	p.form_left=5;p.form_age=2;p.ultimate=100;p.cool.r=0;p.anim_left=0
	check("ultimate_casts",p.cast("r"))
	check("ultimate_ends_form",p.form_left==0 and p.ultimate==0 and p.cool.r>0)
	game.attacks.clear()
	game.save.abilities={}
	for h in JourneyContent.HERO_ORDER:
		game.select_hero(h);p.anim_left=0;p.cool.g=0
		check("locked_g_"+h,not p.cast("g"))
	for key in JourneyContent.ABILITIES:game.save.abilities[key]=true
	for h in JourneyContent.HERO_ORDER:
		game.select_hero(h)
		for key in ["q","e","g"]:
			p.anim_left=0;p.cool[key]=0
			check("skill_cast_"+h+"_"+key,p.cast(key))
			check("skill_cooldown_"+h+"_"+key,not p.cast(key))
	game.attacks.clear()
	# External ownership gates and chapter access use actual entry methods.
	game.save.chapter=4;game.save.abilities={};var id=game.chapter.id
	game.enter_chapter(4)
	check("missing_ability_blocks_route",game.chapter.id==id)
	game.save.abilities.fieryEyes=true;game.enter_chapter(4)
	check("owned_ability_opens_route",game.chapter.id=="huangfeng" and p.hero=="wukong")
	p.position=game.objective_at;p.anim_left=0;p.cool.g=0;p.cast("g")
	check("correct_g_solves_world_rule",game.mechanic_solved)
	game._advance_phase();game.mechanic_solved=false;p.position=game.objective_at
	game.select_hero("wukong");game.skill_used("wukong","g")
	check("wind_reversal_rejects_wukong",not game.mechanic_solved)
	game.select_hero("bajie");game.skill_used("bajie","e")
	check("wind_reversal_requires_bajie",game.mechanic_solved)
	# Boss damage cannot leap through phase boundaries or auto-complete without F.
	game._advance_phase()
	var b=game.boss
	var b_before=b.hp
	b.hit(99999,Vector2.ZERO,false,false,true)
	check("ultimate_boss_damage_capped",b_before-b.hp<=b.max_hp*.151 and not b.tame_ready)
	for i in 100:
		if b.tame_ready:break
		b.exposed=10;b.hit(200,Vector2.ZERO)
	check("boss_three_phases_before_tame",b.phase==3 and b.tame_ready)
	check("boss_does_not_auto_finish",game.mode=="battle")
	game.complete_chapter()
	check("chapter_completion_persists",game.save.completed.has("huangfeng"))
	game.enter_story(4)
	game._advance_phase();b=game.boss
	for i in 100:
		if b.tame_ready:break
		b.exposed=10;b.hit(250,Vector2.ZERO)
	game.complete_chapter()
	check("story_grants_ownership",game.save.stories.has("bagua") and game.has_ability("fieryEyes"))
	var loaded=JourneySave.load_game()
	check("save_roundtrip",loaded.abilities.get("fieryEyes",false) and loaded.stories.has("bagua"))
	check("snapshot_v2_validation",not JourneySave.valid({"version":2}))
	# Chapter snapshots preserve both an unfinished replay and an escort's physical progress.
	game.save.chapter=35
	for ability in JourneyContent.ABILITIES:game.save.abilities[ability]=true
	game.save.unlocked=JourneyContent.HERO_ORDER.duplicate()
	game.enter_chapter(35)
	check("return_has_escort",game.chapter.mechanic=="escort")
	game.escort_distance=156;game.objective_health=64;game.objective_kills=8;game.player.hp=72
	game.persist();game.continue_journey()
	check("checkpoint_escort_distance",is_equal_approx(game.escort_distance,156))
	check("checkpoint_escort_health",is_equal_approx(game.objective_health,64))
	check("checkpoint_escort_position",game.objective_at.distance_to(Vector2(1120,1080).move_toward(Vector2(1250,660),156))<.01)
	check("checkpoint_player_hp",is_equal_approx(game.player.hp,72))
	game.enter_chapter(0);game._advance_phase();game.objective_kills=7;game.persist();game.continue_journey()
	check("checkpoint_replay_keeps_chapter",game.chapter.id=="wuxing" and game.phase==1 and game.objective_kills==7)
	game.select_hero("wukong");game.save.abilities.erase("fieryEyes");p.cool.g=0;p.anim_left=0
	check("transformation_without_fire_eye",p.g_ability()=="seventyTwo" and p.cast("g") and p.transformed>0)
	game.select_hero("tang");p.hp=p.max_hp;p.invulnerable=0;p.dash_left=0;p.build={};game.save.settings.difficulty=.65
	var hp_before=p.hp;p.take_hit(20,p.position-Vector2.RIGHT)
	check("difficulty_applied_once",is_equal_approx(hp_before-p.hp,13))
	# Exercise every menu; this detects dynamically built UI errors.
	game.hud.roster();game.hud.route();game.hud.settings();game.hud.help_screen();game.hud.pause();game.hud.title()
	check("all_menus_construct",game.hud.menu_kind=="title")
	var failures=checks.filter(func(c):return not c.pass)
	var result={"checks":checks,"count":checks.size(),"failed":failures.size(),"engine":Engine.get_version_info().string,"scope":"targeted state, combat and content regression; not a full playthrough"}
	var f=FileAccess.open("res://evidence/pixel-regression.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("PIXEL_REGRESSION ",checks.size()," checks; failures=",failures.size())
	game.queue_free();await process_frame;await create_timer(.15).timeout
	quit(1 if not failures.is_empty() else 0)
