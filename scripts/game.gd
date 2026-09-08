extends Node2D

var save={}
var mode="title"
var world: PixelWorld
var fx: BattleFX
var sound: SoundRack
var hud: JourneyHUD
var player: JourneyFighter
var camera: Camera2D
var foes: Array=[]
var boss: JourneyFoe
var attacks: Array=[]
var zones: Array=[]
var hazards: Array=[]
var projectiles: Array=[]
var orbs: Array=[]
var companions: Array=[]
var chapter={}
var phase=0
var elapsed=0.0
var chapter_elapsed=0.0
var phase_elapsed=0.0
var objective_at=Vector2(1200,860)
var objective_progress=0.0
var objective_kills=0
var objective_hold=0.0
var mechanic_solved=false
var preview_cd=4.0
var spawn_cd=1.0
var env_cd=3.0
var pending_upgrades=0
var hitstop=0.0
var feedback_gap=0.0
var shake=0.0
var hurt_flash=0.0
var cinematic_left=0.0
var cinematic_text=""
var cinematic_color=Color.WHITE
var result_text=""
var generation=0
var rng=RandomNumberGenerator.new()
var drawing_clock=0.0
var verification=false
var route_return=0
var finished=false
var won_last=false
var escort_distance=0.0
var objective_health=100.0
var objective_damage_cd=0.0
var fog: ColorRect
var fog_material: ShaderMaterial
var autosave_left=15.0

func _ready() -> void:
	get_tree().auto_accept_quit=false
	rng.seed=81092026
	verification="--verification" in OS.get_cmdline_user_args()
	if verification:JourneySave.override_dir=ProjectSettings.globalize_path("res://evidence/verification-data")
	save=JourneySave.load_game()
	world=PixelWorld.new();world.z_index=-20;add_child(world)
	fx=BattleFX.new();fx.z_index=250;add_child(fx)
	sound=SoundRack.new();add_child(sound);sound.settings(save.settings)
	player=JourneyFighter.new();player.game=self;add_child(player)
	camera=Camera2D.new();camera.position_smoothing_enabled=false;camera.limit_left=0;camera.limit_top=0;camera.limit_right=2400;camera.limit_bottom=1600;add_child(camera);camera.make_current()
	hud=JourneyHUD.new();hud.game=self;add_child(hud)
	_setup_fog()
	chapter=JourneyContent.chapter(0);world.build(chapter)
	player.position=world.spawn;camera.position=player.position
	sound.score(chapter.theme)
	hud.title()
	if bool(save.settings.get("fullscreen",false)) and not verification:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	queue_redraw()

func new_journey() -> void:
	var settings_old=save.settings.duplicate()
	save=JourneySave.fresh();save.settings=settings_old
	player.build={};player.level=1;player.xp=0;player.xp_next=8;player.kills=0;player.hp=150;player.max_hp=150
	player.set_hero("tang")
	enter_chapter(0)
	toast("WASD 移动 · 靠近金色佛印，在周围击退妖潮 · Q 净化")

func continue_journey() -> void:
	var run=save.get("run",{}).duplicate(true)
	player.build=run.get("build",{}).duplicate()
	player.level=maxi(1,int(run.get("level",1)));player.xp=int(run.get("xp",0));player.xp_next=maxi(8,int(run.get("xp_next",8)));player.kills=int(run.get("kills",0))
	var h=run.get("hero","tang")
	player.set_hero(h if save.unlocked.has(h) else "tang")
	if not run.get("finished",true):
		if bool(run.get("story",false)):enter_story(clampi(int(run.get("index",0)),0,JourneyContent.STORIES.size()-1))
		else:enter_chapter(clampi(int(run.get("index",0)),0,JourneyContent.ROUTE.size()-1))
	else:enter_chapter(int(save.chapter))
	if not run.get("finished",true) and not bool(run.get("dead",false)) and chapter.id==run.get("scene_id",""):
		var saved_phase=clampi(int(run.get("phase",0)),0,chapter.objectives.size()-1)
		for i in saved_phase:_advance_phase()
		objective_hold=float(run.get("hold",0));objective_kills=int(run.get("objective_kills",0));mechanic_solved=bool(run.get("solved",false))
		escort_distance=float(run.get("escort_distance",0));objective_health=float(run.get("objective_health",100))
		if chapter.mechanic=="escort":objective_at=Vector2(1120,1080).move_toward(Vector2(1250,660),escort_distance)
		player.hp=clampf(float(run.get("hp",player.max_hp)),1,player.max_hp)
		if boss!=null and run.has("boss"):
			boss.hp=clampf(float(run.boss.get("hp",boss.max_hp)),1,boss.max_hp);boss.phase=clampi(int(run.boss.get("phase",1)),1,3);boss.tame_ready=bool(run.boss.get("tame_ready",false))
		persist()

func has_ability(id: String) -> bool:
	return bool(save.abilities.get(id,false))

func enter_chapter(index: int) -> void:
	var c=JourneyContent.chapter(index)
	if index>int(save.chapter) and not save.completed.has(c.id):toast("前方旅途尚未开启");return
	if not c.gate.is_empty() and not has_ability(c.gate):
		toast("需先习得"+JourneyContent.ABILITIES[c.gate].name);hud.route();return
	chapter=c
	if not save.unlocked.has(player.hero):player.set_hero("tang")
	if not c.gate.is_empty():player.set_hero(c.hero)
	_start_chapter()

func enter_story(index: int) -> void:
	var c=JourneyContent.story(index)
	if not save.unlocked.has(c.hero):return
	route_return=int(save.chapter)
	chapter=c;player.set_hero(c.hero);_start_chapter()
	toast(c.source+" · "+c.subtitle)

func _start_chapter() -> void:
	generation+=1
	for e in foes:if is_instance_valid(e):e.queue_free()
	foes.clear();boss=null;attacks.clear();hazards.clear();projectiles.clear();zones.clear();orbs.clear()
	for c in companions:if is_instance_valid(c.node):c.node.queue_free()
	companions.clear();fx.items.clear();fx.sparks.clear();fx.numbers.clear()
	phase=0;chapter_elapsed=0;phase_elapsed=0;objective_kills=0;objective_hold=0;objective_progress=0;mechanic_solved=false;escort_distance=0;objective_health=100;finished=false
	spawn_cd=.6;env_cd=3;preview_cd=3;hitstop=0;pending_upgrades=0
	world.build(chapter);player.position=world.spawn;camera.position=player.position
	player.is_dead=false;player.hp=player.max_hp;player.end_form();player.combo=0;player.combo_left=0;player.form_charge=0
	for k in player.cool:player.cool[k]=0
	player.invulnerable=1;objective_at=Vector2(1200,860)
	if chapter.mechanic=="escort":objective_at=Vector2(1120,1080)
	if chapter.id=="wuxing":objective_at=world.landmark+Vector2(0,130);player.position=Vector2(1050,850);camera.position=player.position
	mode="battle";hud.clear_menu();sound.score(chapter.theme)
	cinematic(chapter.name+" · "+chapter.subtitle,Color("edd3a0"),1.5)
	if chapter.id=="wuxing":_prisoned_wukong()
	persist()

func _prisoned_wukong() -> void:
	var actor=AnimatedSprite2D.new();actor.sprite_frames=JourneyContent.frames("wukong");actor.position=world.landmark+Vector2(0,-8);actor.play("idle");actor.z_index=55;add_child(actor)
	companions.append({"node":actor,"hero":"wukong","life":99999.0,"cd":2.0,"preview":true,"showcase":0})

func _process(delta: float) -> void:
	var dt=minf(delta,.05)
	drawing_clock+=dt
	cinematic_left=maxf(0,cinematic_left-dt);hurt_flash=maxf(0,hurt_flash-dt)
	hud.tick(dt)
	_update_fog()
	if mode!="battle":
		_set_animation_speed(0 if mode!="title" else 1)
		if mode=="title":camera.position=camera.position.lerp(player.position+Vector2(100,-125),dt*.5)
		queue_redraw();return
	fx.tick(dt)
	shake=maxf(0,shake-dt*22)
	camera.position=camera.position.lerp(player.position,1-exp(-dt*9))
	camera.offset=Vector2(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake))*float(save.settings.get("shake",.7))
	if hitstop>0:
		hitstop=maxf(0,hitstop-dt);_set_animation_speed(0);return
	_set_animation_speed(1)
	feedback_gap=maxf(0,feedback_gap-dt)
	elapsed+=dt;chapter_elapsed+=dt;phase_elapsed+=dt
	autosave_left-=dt
	if autosave_left<=0 and not verification:autosave_left=15;persist()
	player.tick(dt,not verification)
	if mode!="battle":return
	for e in foes.duplicate():
		if is_instance_valid(e) and not e.dead:e.tick(dt)
	if mode!="battle":return
	_process_attacks(dt)
	_tick_world(dt)
	_tick_objective(dt)
	spawn_cd-=dt
	if spawn_cd<=0:
		spawn_cd=.85 if boss==null else 1.7
		if foes.size()<65:
			for i in (2 if boss==null else 1):spawn_enemy()
	if pending_upgrades>0 and cinematic_left<=0 and mode=="battle":
		var picks=Cards.roll(player.build,3,rng,player.hero)
		# Narration follows the implemented, capped effects.
		for i in picks.size():picks[i]=picks[i].duplicate()
		for c in picks:
			if c.id=="killForm":c.desc="保持连击时，每次击杀额外积攒 2 点法相 / 层"
			if c.id=="w_72" and not has_ability("seventyTwo"):c.desc="习得七十二变后，冲刺会留下作战分身"
		mode="menu";hud.upgrades(picks)
	queue_redraw()

func _set_animation_speed(rate: float) -> void:
	player.sprite.speed_scale=rate
	for e in foes:if is_instance_valid(e):e.sprite.speed_scale=rate
	for c in companions:if is_instance_valid(c.node):c.node.speed_scale=rate

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if mode=="battle":mode="menu";hud.pause()
				elif mode=="menu" and hud.menu_kind not in ["upgrade","results"]:resume()
			KEY_M:
				if mode=="battle":hud.route()
			KEY_TAB:
				if mode=="battle":hud.roster()
			KEY_F:
				if mode=="battle" and boss!=null and boss.tame_ready and player.position.distance_to(boss.position)<120:complete_chapter()
			KEY_1,KEY_2,KEY_3:
				if mode=="menu" and hud.menu_kind=="upgrade":hud.pick(event.physical_keycode-KEY_1)

func resume() -> void:
	if finished:mode="results";hud.results(won_last,bool(save.get("ending",false)) and chapter.id=="return");return
	if player.is_dead:return
	mode="battle";hud.clear_menu()

func return_title() -> void:
	persist();mode="title";hud.title();sound.score("mountain")

func select_hero(h: String) -> void:
	if not save.unlocked.has(h):return
	if chapter.get("story",false) and chapter.hero!=h:
		toast("人物外传由"+JourneyContent.HEROES[chapter.hero].name+"亲自完成");return
	player.set_hero(h);sound.play("cast",.5);fx.emit("rune",player.position,JourneyContent.color(h),55)

func cycle_hero() -> void:
	if chapter.story:toast("当前为"+JourneyContent.HEROES[chapter.hero].name+"的专属外传");return
	var i=save.unlocked.find(player.hero)
	select_hero(save.unlocked[(i+1)%save.unlocked.size()])

func spawn_enemy(at: Vector2=Vector2.INF, kind: String="", elite: bool=false) -> JourneyFoe:
	if foes.size()>=70:return null
	if at==Vector2.INF:at=player.position+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(420,580)
	at=world.resolve(at,14)
	if kind.is_empty():
		var ecology={"mountain":["wolf","bat","soldier"],"river":["water","snake","dragon"],"sand":["bone","snake","boar"],"village":["wolf","boar","soldier"],"temple":["monk","soldier","yellow"],"bone":["bone","bat","raven"],"fire":["fire","soldier","scorpion"],"forest":["wolf","mushroom","snake"],"palace":["soldier","fox","monk"],"poison":["spider","snake","centipede"],"snow":["water","rhino","wolf"],"heaven":["soldier","gold","raven"],"underworld":["bone","bat","rat"]}
		var pool=ecology[chapter.theme]
		kind=pool[rng.randi_range(0,pool.size()-1)]
	var foe=JourneyFoe.new();foe.configure(self,kind,1+minf(chapter.index,25)*.065,false,elite or rng.randf()<.10);foe.position=at;add_child(foe);foes.append(foe)
	fx.emit("rune",at,Color("6d8b79"),20,Vector2.RIGHT,.4)
	return foe

func nearest(at: Vector2, radius: float):
	var best=null;var dist=radius
	for e in foes:
		if not is_instance_valid(e) or e.dead or e.tame_ready:continue
		var d=at.distance_to(e.position)
		if d<dist:best=e;dist=d
	return best

func queue_attack(data: Dictionary, delay: float) -> void:
	data=data.duplicate();data.delay=delay;data.generation=generation
	attacks.append(data)

func _process_attacks(dt: float) -> void:
	var due=[]
	for a in attacks:a.delay-=dt
	for a in attacks:if a.delay<=0:due.append(a)
	attacks=attacks.filter(func(a):return a.delay>0)
	for a in due:
		if a.generation==generation:resolve_attack(a)

func resolve_attack(a: Dictionary) -> int:
	var at: Vector2=a.at;var dir: Vector2=a.get("dir",Vector2.RIGHT);var r: float=a.radius
	var col: Color=a.color
	fx.emit(a.vfx,at,col,r,dir,.50 if a.get("heavy",false) else .24)
	if a.get("travel",false):
		player.dash_direction=dir;player.dash_speed=r/.17;player.dash_left=.17;player.invulnerable=maxf(player.invulnerable,.22)
	var hits=0
	for e in foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:continue
		var off: Vector2=e.position-at;var inside=false
		match a.kind:
			"circle":inside=off.length()<=r+20
			"cone":inside=off.length()<=r+20 and absf(off.angle_to(dir))<=1.12
			"line":inside=Geometry2D.get_closest_point_to_segment(e.position,at,at+dir*r).distance_to(e.position)<32+12*e.scale_base
		if not inside:continue
		var dmg: float=a.damage
		var crit=rng.randf()<minf(.4,.08*player.upgrade("crit"))
		if crit:dmg*=1.8
		if a.get("detonate",false):
			if e.marks<=0:dmg*=.28
			else:dmg*=1+.5*e.marks;e.marks=0;fx.emit("lightning",e.position-Vector2(0,140),col,140,Vector2.DOWN,.35)
		if a.get("mark",false):e.marks=mini(3,e.marks+1);e.mark_left=6
		if a.get("reveal",false):e.exposed=6
		if a.get("breaker",false):e.exposed=maxf(e.exposed,2.5)
		if a.get("slow",false) or player.upgrade("frost")>0:e.slow=2.5+player.upgrade("frost")
		if a.get("burn",false) or player.upgrade("burn")>0:e.burn=3.0+player.upgrade("burn")
		if a.get("pull",false):e.position=e.position.move_toward(at,minf(110,off.length()*.6))
		var k=off.normalized()*float(a.get("knock",100))
		if e.hit(dmg,k,crit,false,a.get("ultimate",false)):hits+=1
	if hits>0:
		player.on_hit()
		if a.get("auto",false) and a.hero=="nezha" and player.upgrade("n_ring")>0:
			var t=nearest(at,240)
			if t!=null:t.hit(float(a.damage)*.4*player.upgrade("n_ring"),dir*80,false);fx.emit("ring",t.position,col,30)
	if a.get("cleanse",false):
		clear_hazards(at,r)
		if at.distance_to(objective_at)<r+100 and chapter.mechanic in ["seal","cleanse","rain"]:mechanic_solved=true
	return hits

func hit_feedback(at: Vector2, damage: float, heavy: bool) -> void:
	sound.play("heavy" if heavy else "hit",.85)
	fx.emit("impact",at-Vector2(0,15),Color("fff2c7"),26 if heavy else 14,Vector2.RIGHT,.14)
	fx.burst(at-Vector2(0,13),JourneyContent.color(player.hero),6 if heavy else 3)
	fx.number(at,str(int(damage)),Color("ffd993") if heavy else Color("e0dec4"),heavy)
	if feedback_gap<=0:
		hitstop=.060 if heavy else .028;feedback_gap=.09
		shake=maxf(shake,3.0 if heavy else .8)

func enemy_died(e: JourneyFoe) -> void:
	player.on_kill();sound.play("kill",.4);fx.burst(e.position,Color("b5ae87"),12 if e.elite else 6)
	orbs.append({"at":e.position,"value":3 if e.elite else 1})
	if orbs.size()>180:
		var first=orbs.pop_front();player.gain_xp(int(first.value))
	if e.position.distance_to(objective_at)<260:objective_kills+=1
	foes.erase(e);e.queue_free()
	if player.upgrade("thunder")>0:
		var target=nearest(e.position,100)
		if target!=null:
			# Delayed chain uses the common queue, so a corpse cannot recurse.
			queue_attack({"at":target.position,"radius":25.0,"kind":"circle","damage":9.0*player.upgrade("thunder"),"vfx":"lightning","dir":Vector2.DOWN,"color":Color("acb6f2"),"hero":player.hero,"auto":false,"knock":0,"heavy":false},.1)

func _tick_world(dt: float) -> void:
	for orb in orbs.duplicate():
		var dist=player.position.distance_to(orb.at)
		if dist<95+30*player.upgrade("magnet"):orb.at=orb.at.move_toward(player.position,dt*320)
		if dist<18:
			player.gain_xp(int(orb.value)*(2 if chapter.id=="fangcun" else 1));sound.play("pickup",.55)
			if player.upgrade("orbHeal")>0:player.hp=minf(player.max_hp,player.hp+.8*player.upgrade("orbHeal"))
			orbs.erase(orb)
	for z in zones:
		z.life-=dt;z.cd-=dt
		if z.cd<=0:
			z.cd=.5
			fx.emit("ward" if z.kind=="ward" else "wave",z.at,JourneyContent.color(z.hero),z.r,Vector2.RIGHT,.65)
			for e in foes.duplicate():
				if e.dead or e.position.distance_to(z.at)>z.r:continue
				if z.kind=="water":e.slow=1
				e.hit(z.damage,Vector2.ZERO,false,true)
			if z.kind=="ward" and player.position.distance_to(z.at)<z.r:player.shield=maxf(player.shield,.7)
	zones=zones.filter(func(z):return z.life>0)
	for h in hazards:
		h.delay-=dt
		if h.delay>0:continue
		if not h.fired:
			h.fired=true;fx.emit("impact" if h.kind in ["slam","spike"] else "wave",h.at,Color("f0a37b"),h.r,Vector2.RIGHT,.4)
			if player.position.distance_to(h.at)<h.r:player.take_hit(_hazard_damage(h.kind,h.damage),h.at-Vector2(0,3))
		if h.kind in ["fire","poison","web","water"] and player.position.distance_to(h.at)<h.r:
			h.cd-=dt
			if h.cd<=0:h.cd=.8;player.take_hit(_hazard_damage(h.kind,h.damage*.4),h.at)
		if h.kind=="pull" and h.delay>-.8 and player.position.distance_to(h.at)<h.r and player.dash_left<=0:player.position=world.resolve(player.position.move_toward(h.at,dt*65),10)
		h.life-=dt
	hazards=hazards.filter(func(h):return h.life>0)
	for b in projectiles:
		b.at+=b.v*dt;b.life-=dt
		if b.at.distance_to(player.position)<16 and player.take_hit(b.damage,b.at-b.v*.1):b.life=0
	projectiles=projectiles.filter(func(b):return b.life>0)
	for c in companions.duplicate():
		c.life-=dt;c.cd-=dt
		if c.life<=0:c.node.queue_free();companions.erase(c);continue
		if not c.preview:
			c.node.position=c.node.position.move_toward(player.position+Vector2(sin(drawing_clock*2+c.life)*55,cos(drawing_clock*2)*45),dt*165)
		if c.cd<=0:
			c.cd=4 if c.preview else .8
			var target=nearest(c.node.position,650 if c.preview else 260)
			if target!=null:
				c.node.play("atk")
				fx.emit("staff" if c.hero=="wukong" else "slash",c.node.position,Color("e6c582"),c.node.position.distance_to(target.position),(target.position-c.node.position).normalized(),.45)
				target.hit(65 if c.preview else (24+6*player.upgrade("w_clone") if c.hero=="wukong" else 30+10*player.upgrade("e_dog")),(target.position-c.node.position).normalized()*100,false)
				if c.preview:
					var step=int(c.showcase)%4;c.showcase+=1
					toast(["悟空：看俺金箍棒，隔山扫妖！","悟空：这妖气，瞒不过俺的火眼！","悟空：毫毛变化，分身退敌！","悟空：法天象地！师父，快揭那山顶佛印！"][step])
					match step:
						0:fx.emit("staff",c.node.position,Color("f8cd78"),410,(target.position-c.node.position).normalized(),.8)
						1:
							fx.emit("beam",c.node.position-Vector2(0,22),Color("ffcd76"),440,(target.position-c.node.position).normalized(),.8);target.exposed=5
						2:
							for i in 3:add_companion("wukong",target.position+Vector2.from_angle(i*TAU/3)*55,2)
						3:
							fx.emit("staff",c.node.position,Color("eed393"),510,Vector2.DOWN,1);fx.emit("impact",target.position,Color("eed393"),150,Vector2.RIGHT,.8)
	env_cd-=dt
	if env_cd<=0:
		env_cd=5.0
		if chapter.mechanic in ["fire","water","storm","wind","poison","smoke","web"]:
			var kind="lightning" if chapter.mechanic=="storm" else chapter.mechanic
			add_danger(player.position+Vector2(rng.randf_range(-80,80),rng.randf_range(-80,80)),60,1.1,kind,12)

func add_zone(at: Vector2,r: float,life: float,kind: String,hero: String,damage: float) -> void:
	if zones.size()>12:zones.pop_front()
	zones.append({"at":at,"r":r,"life":life,"kind":kind,"hero":hero,"damage":damage,"cd":0.0})

func add_danger(at: Vector2,r: float,delay: float,kind: String,damage: float) -> void:
	if hazards.size()>24:return
	hazards.append({"at":at,"r":r,"delay":delay,"total":delay,"kind":kind,"damage":damage,"fired":false,"life":delay+(2.4 if kind in ["fire","poison","water","web"] else .9),"cd":.8})

func add_projectile(at: Vector2,v: Vector2,damage: float,kind: String="orb") -> void:
	if projectiles.size()>65:return
	projectiles.append({"at":at,"v":v,"damage":damage,"kind":kind,"life":5.0})

func clear_hazards(at: Vector2,r: float) -> void:
	hazards=hazards.filter(func(h):return h.at.distance_to(at)>r)
	projectiles=projectiles.filter(func(b):return b.at.distance_to(at)>r)

func add_companion(hero: String,at: Vector2,life: float) -> void:
	if companions.size()>=5:return
	var s=AnimatedSprite2D.new();s.sprite_frames=JourneyContent.frames(hero);s.position=at;s.modulate=Color(1,1,1,.65);s.z_index=80;s.play("run");add_child(s)
	companions.append({"node":s,"hero":hero,"life":life,"cd":.1,"preview":false})

func _tick_objective(dt: float) -> void:
	if boss!=null:return
	var near=player.position.distance_to(objective_at)<145
	if chapter.mechanic=="escort":
		if near and objective_kills>0:
			var destination=Vector2(1250,660)
			var previous=objective_at
			objective_at=objective_at.move_toward(destination,dt*14)
			escort_distance+=previous.distance_to(objective_at)
		objective_damage_cd=maxf(0,objective_damage_cd-dt)
		for e in foes:
			if not e.dead and e.position.distance_to(objective_at)<42:
				objective_health=maxf(0,objective_health-dt*2.5)
				if objective_damage_cd<=0:objective_damage_cd=1;fx.number(objective_at,"护送受袭",Color("ed9b83"))
		if near and player.shield>0:objective_health=minf(100,objective_health+dt*3)
		if objective_health<=0:fail_run();return
	if near and objective_kills>0:objective_hold+=dt
	var need=12+phase*5+mini(chapter.index,12)
	var hold=12.0+phase*4
	objective_progress=minf(1,float(objective_kills)/need)*.65+minf(1,objective_hold/hold)*.35
	if chapter.mechanic=="escort":objective_progress=minf(1,float(objective_kills)/need)*.4+minf(1,escort_distance/420)*.6
	if _requires_mechanic() and not mechanic_solved:objective_progress=minf(.85,objective_progress)
	if objective_progress>=.999:_advance_phase()

func _requires_mechanic() -> bool:
	if chapter.story:return false
	return not chapter.gate.is_empty() or chapter.mechanic in ["seal","cleanse","rain"]

func skill_used(hero: String,key: String) -> void:
	if player.position.distance_to(objective_at)>220:return
	if chapter.story:return
	if chapter.id=="huangfeng" and phase==1:
		if hero=="bajie" and key in ["q","e","g"]:mechanic_solved=true;toast("天蓬守住风眼，队伍稳住了！")
		return
	if chapter.gate.is_empty():
		if hero=="tang" and key in ["q","g"]:mechanic_solved=true
	elif hero==chapter.hero and key=="g" and has_ability(chapter.gate):
		mechanic_solved=true;fx.emit("lotus",objective_at,JourneyContent.color(hero),160,Vector2.RIGHT,.8);toast("神通破局 · "+JourneyContent.ABILITIES[chapter.gate].name)

func objective_text() -> String:
	if boss!=null:
		return "靠近力竭首领按 F 收服" if boss.tame_ready else "避开红色预警，趁收势反击。三阶段后力竭收服。"
	var text=chapter.objectives[phase]
	if chapter.mechanic=="escort":text+="\n护送灵灯 "+str(int(objective_health))+"% · 靠近护送，护体可修复"
	if _requires_mechanic() and not mechanic_solved:
		if chapter.id=="huangfeng" and phase==1:text+="\n需要：八戒 Q / E 守住风眼"
		elif not chapter.gate.is_empty():text+="\n需要："+JourneyContent.HEROES[chapter.hero].name+" G"
		else:text+="\n需要：唐僧 Q 净化"
	return text

func _advance_phase() -> void:
	phase+=1;phase_elapsed=0;objective_hold=0;objective_kills=0;mechanic_solved=false;objective_progress=0
	if chapter.mechanic=="escort":escort_distance=0;objective_health=100
	player.hp=minf(player.max_hp,player.hp+30);sound.play("level",.6)
	objective_at=Vector2(1200+(120 if phase%2==1 else -120),phase*90+670)
	if chapter.mechanic=="escort":objective_at=Vector2(1120,1080)
	if phase>=chapter.objectives.size()-1:
		objective_at=Vector2(1200,820)
		boss=JourneyFoe.new();boss.configure(self,chapter.sprite,1+chapter.index*.07,true);boss.position=world.resolve(player.position+Vector2(230,-120),30);add_child(boss);foes.append(boss)
		sound.score(chapter.theme,true);cinematic(chapter.boss+" · 现身",Color("f3bc94"),1.2)
	else:toast(chapter.objectives[phase])

func boss_ready() -> void:
	toast("首领力竭 · 靠近后按 F "+("揭印解封" if chapter.id=="wuxing" else "收服 / 破阵"))
	sound.play("break",.8);clear_hazards(player.position,300)

func complete_chapter() -> void:
	if boss==null or not boss.tame_ready:return
	mode="results";finished=true;won_last=true
	result_text=chapter.subtitle+"\n"
	if chapter.story:
		if not save.stories.has(chapter.id):save.stories.append(chapter.id)
		save.abilities[chapter.reward]=true
		result_text+="习得："+JourneyContent.ABILITIES.get(chapter.reward,{"name":"旧事传承"}).name
		if chapter.id=="heaven":
			for h in ["nezha","erlang"]:if not save.unlocked.has(h):save.unlocked.append(h)
			result_text+="\n哪吒与杨戬加入队伍，各自人物外传已开放。"
	else:
		if not save.completed.has(chapter.id):save.completed.append(chapter.id);save.events+=chapter.objectives.size()
		save.chapter=maxi(int(save.chapter),mini(chapter.index+1,JourneyContent.ROUTE.size()-1))
		if not chapter.unlock.is_empty() and not save.unlocked.has(chapter.unlock):
			save.unlocked.append(chapter.unlock);result_text+="同伴归队："+JourneyContent.HEROES[chapter.unlock].name+"\n基础招式已获得，完整神通在人物外传中习得。"
		if chapter.id=="wuxing":save.abilities.mercy=true;result_text+="\n唐僧领悟度厄真言。悟空方寸山与八卦炉外传已开放。"
		if chapter.id=="liusha":result_text+="\n师徒集结。前路黄风，需要先让悟空在八卦炉炼成火眼。"
	if chapter.index==JourneyContent.ROUTE.size()-1 and not chapter.story:save.ending=true
	player.hp=player.max_hp
	sound.play("victory");persist();hud.results(true,bool(save.get("ending",false)) and chapter.id=="return")

func next_chapter() -> void:
	var idx=int(save.chapter) if chapter.story else mini(chapter.index+1,JourneyContent.ROUTE.size()-1)
	enter_chapter(idx)

func retry() -> void:
	player.is_dead=false;player.hp=player.max_hp
	_start_chapter()

func fail_run() -> void:
	mode="results";finished=true;won_last=false;sound.play("defeat");persist();hud.results(false)

func persist() -> void:
	if player!=null:
		save.run={"level":player.level,"xp":player.xp,"xp_next":player.xp_next,"build":player.build,"hero":player.hero,"kills":player.kills,"scene_id":chapter.get("id",""),"index":chapter.get("index",0),"story":chapter.get("story",false),"finished":finished,"dead":player.is_dead,"phase":phase,"hold":objective_hold,"objective_kills":objective_kills,"solved":mechanic_solved,"hp":player.hp,"escort_distance":escort_distance,"objective_health":objective_health}
		if boss!=null:save.run.boss={"hp":boss.hp,"phase":boss.phase,"tame_ready":boss.tame_ready}
	if not JourneySave.write(save):toast("存档未能写入，请检查游戏 userdata 文件夹权限")

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if mode!="title" and player!=null:persist()
		get_tree().quit()

func toast(text: String) -> void:
	if hud!=null:hud.toast(text)

func cinematic(text: String,color: Color,duration: float=1.2) -> void:
	cinematic_text=text;cinematic_color=color;cinematic_left=duration

func _draw() -> void:
	if world==null:return
	for z in zones:
		draw_circle(z.at,z.r,Color(JourneyContent.color(z.hero),.055));draw_arc(z.at,z.r,0,TAU,40,Color(JourneyContent.color(z.hero),.4),2)
	for h in hazards:
		var c=Color("e6a26d") if h.kind in ["fire","slam","spike"] else Color("d77b93")
		if h.delay>0:
			draw_circle(h.at,h.r,Color(c,.08));draw_arc(h.at,h.r,0,TAU,40,Color(c,.75),2)
			draw_arc(h.at,h.r*.9,-PI*.5,-PI*.5+TAU*(1-h.delay/h.total),36,Color("f6c297"),3)
		else:draw_circle(h.at,h.r,Color(c,.12));draw_arc(h.at,h.r,0,TAU,28,Color(c,.35),2)
	for b in projectiles:
		draw_line(b.at-b.v.normalized()*11,b.at,Color("db8a80"),5);draw_rect(Rect2(b.at-Vector2(2,2),Vector2(4,4)),Color("ffe0b0"))
	for o in orbs:
		draw_colored_polygon(PackedVector2Array([o.at+Vector2(0,-4),o.at+Vector2(3,0),o.at+Vector2(0,4),o.at+Vector2(-3,0)]),Color("87d9cc"));draw_rect(Rect2(o.at-Vector2(1,2),Vector2(2,2)),Color("d0eee2"))
	if mode=="battle" and boss==null:
		var c=Color("e9cc8c")
		draw_circle(objective_at,145,Color(c,.035));draw_arc(objective_at,145,0,TAU,56,Color(c,.25),1)
		draw_arc(objective_at,36,-PI*.5,-PI*.5+TAU*objective_progress,32,c,4)
		for i in 4:
			var d=Vector2.from_angle(i*PI*.5+PI*.25)
			draw_line(objective_at+d*21,objective_at+d*31,c,3)
		draw_string(ThemeDB.fallback_font,objective_at+Vector2(-31,-46),"当前目标",HORIZONTAL_ALIGNMENT_LEFT,-1,14,c)
		var off=objective_at-player.position
		if off.length()>260:
			var d=off.normalized();var p=player.position+d*180
			draw_colored_polygon(PackedVector2Array([p+d*13,p+d.rotated(2.5)*10,p+d.rotated(-2.5)*10]),c)
		if chapter.mechanic=="escort":
			draw_rect(Rect2(objective_at-Vector2(11,25),Vector2(22,32)),Color("7c624e"));draw_rect(Rect2(objective_at-Vector2(8,22),Vector2(16,23)),Color("e6c384"))
			draw_rect(Rect2(objective_at-Vector2(18,36),Vector2(36,4)),Color("283936"));draw_rect(Rect2(objective_at-Vector2(18,36),Vector2(36*objective_health/100,4)),Color("b8dbb0"))

func _hazard_damage(kind: String,amount: float) -> float:
	if kind=="fire" and player.hero=="nezha" and has_ability("lotus"):return amount*.25
	if kind=="water" and player.hero=="shaWujing" and has_ability("fullWater"):return amount*.25
	return amount

func _setup_fog() -> void:
	var layer=CanvasLayer.new();layer.layer=20;add_child(layer)
	fog=ColorRect.new();fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fog.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(fog)
	var shader=Shader.new()
	shader.code="shader_type canvas_item; uniform float strength=0.0; uniform vec2 center=vec2(0.5); uniform float radius=0.24; void fragment(){vec2 d=UV-center;d.x*=1.7778;float mask=smoothstep(radius,radius+0.22,length(d));COLOR=vec4(0.055,0.075,0.09,mask*strength);}"
	fog_material=ShaderMaterial.new();fog_material.shader=shader;fog.material=fog_material

func _update_fog() -> void:
	if fog==null:return
	var active=chapter.get("mechanic","") in ["smoke","reveal","wind","stealth"] or chapter.get("id","")=="bagua"
	fog.visible=active and mode=="battle"
	if not fog.visible:return
	var seeing=player.reveal>0 or player.transformed>0 or (chapter.id=="huangfeng" and phase==1 and player.hero=="bajie")
	fog_material.set_shader_parameter("strength",.1 if seeing else .82)
	fog_material.set_shader_parameter("center",Vector2(.5,.5)+(player.position-camera.position)/Vector2(960,540))
