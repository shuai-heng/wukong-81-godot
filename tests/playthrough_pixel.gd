extends SceneTree

var game
var results=[]
var target_sections=5
var frame=0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	JourneySave.override_dir=ProjectSettings.globalize_path("res://evidence/playthrough-save")
	game=load("res://scripts/game.gd").new();root.add_child(game);game.set_process(false)
	game.new_journey();game.verification=false
	var script_queue=[0,1,2,3]
	for s in JourneyContent.STORIES:script_queue.append(s[0])
	for i in range(4,JourneyContent.ROUTE.size()):script_queue.append(i)
	for entry in script_queue:
		if entry is String:
			var si=0
			for i in JourneyContent.STORIES.size():
				if JourneyContent.STORIES[i][0]==entry:si=i;break
			game.enter_story(si)
		else:game.enter_chapter(entry)
		var start_kills=game.player.kills
		var sim=0.0
		var retries=0
		while sim<350 and game.mode!="results":
			if game.mode=="menu" and game.hud.menu_kind=="upgrade":
				# Prefer actual damage/survival cards, but keep the real 3-card draw.
				var choice=0
				for j in game.hud.picks.size():
					if game.hud.picks[j].id in ["dmg","hp","lifesteal","regen","t_nova","atkSpeed"]:choice=j;break
				game.hud.pick(choice)
			var p=game.player
			if not game.chapter.story and game.chapter.gate.is_empty() and game.chapter.mechanic in ["seal","cleanse","rain"] and p.hero!="tang":game.select_hero("tang")
			var goal: Vector2=game.objective_at
			if game.boss!=null:
				if game.boss.tame_ready:
					goal=game.boss.position
					if p.position.distance_to(goal)<115:
						var event=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true;game._unhandled_input(event);break
				else:goal=game.boss.position+Vector2.from_angle(sim*.9)*95
			else:goal+=Vector2.from_angle(sim*.6)*65
			if game.chapter.id=="huangfeng" and game.phase==1 and p.hero!="bajie":game.select_hero("bajie")
			var move=(goal-p.position).normalized() if p.position.distance_to(goal)>16 else Vector2.ZERO
			for h in game.hazards:
				if h.delay<.4 and p.position.distance_to(h.at)<h.r+15:move=(p.position-h.at).normalized()
			Input.action_press("move_right",maxf(0,move.x));Input.action_press("move_left",maxf(0,-move.x));Input.action_press("move_down",maxf(0,move.y));Input.action_press("move_up",maxf(0,-move.y))
			if p.cool.q<=0:p.cast("q")
			if p.cool.e<=0 and (p.hero!="tang" or p.hp<p.max_hp*.9 or game.nearest(p.position,85)!=null):p.cast("e")
			if p.cool.g<=0 and game.has_ability(JourneyContent.HEROES[p.hero].ability):p.cast("g")
			if p.ultimate>=100:p.cast("r")
			if p.cool.dash<=0 and game.nearest(p.position,40)!=null:p.dash(move)
			game._process(1.0/60.0);sim+=1.0/60.0;frame+=1
			if frame%120==0:await process_frame
		var completed=game.save.stories.has(game.chapter.id) if game.chapter.story else game.save.completed.has(game.chapter.id)
		results.append({"chapter":game.chapter.id,"pass":completed,"seconds":sim,"hp":game.player.hp,"level":game.player.level,"kills":game.player.kills-start_kills,"phase":game.phase,"progress":game.objective_progress,"mechanic":game.mechanic_solved})
		print("PLAYTHROUGH ",JSON.stringify(results.back()))
		if not completed:break
	for action in ["move_right","move_left","move_down","move_up"]:Input.action_release(action)
	var f=FileAccess.open("res://evidence/pixel-playthrough.json",FileAccess.WRITE);f.store_string(JSON.stringify({"results":results,"scope":"normal stats, normal cooldowns, movement inputs, real objective progress, no boss kill injection","complete":results.size()==script_queue.size() and results.all(func(r):return r.pass)},"  "));f.close()
	game.queue_free();await process_frame;await create_timer(.15).timeout
	quit(0 if results.size()==script_queue.size() and results.all(func(r):return r.pass) else 1)
