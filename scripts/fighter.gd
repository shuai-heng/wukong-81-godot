class_name JourneyFighter
extends Node2D

var game
var hero="tang"
var sprite: AnimatedSprite2D
var hp=150.0
var max_hp=150.0
var level=1
var xp=0
var xp_next=8
var kills=0
var build={}
var cool={"q":0.0,"e":0.0,"g":0.0,"r":0.0,"dash":0.0,"auto":0.0}
var anim_left=0.0
var invulnerable=0.0
var dash_left=0.0
var dash_direction=Vector2.RIGHT
var dash_speed=640.0
var facing=Vector2.RIGHT
var shield=0.0
var rage=0.0
var wheels=0.0
var dragon=0.0
var reveal=0.0
var transformed=0.0
var showing_transformation=false
var visual_kind="tang"
var combo=0
var combo_left=0.0
var form_charge=0.0
var form_left=0.0
var form_age=0.0
var ultimate=0.0
var auto_step=0
var attack_serial=0
var attack_hit=false
var move_vector=Vector2.ZERO
var trail_timer=0.0
var is_dead=false

func _ready() -> void:
	sprite=AnimatedSprite2D.new()
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position=Vector2(0,-24)
	add_child(sprite)
	set_hero(hero)

func set_hero(h: String) -> void:
	var ratio=hp/maxf(1,max_hp)
	hero=h
	max_hp=float(JourneyContent.HEROES[h].hp)+18*upgrade("hp")+(level-1)*4
	hp=clampf(max_hp*ratio,1,max_hp)
	sprite.sprite_frames=JourneyContent.frames(h)
	visual_kind=h
	sprite.play("idle")
	end_form()
	dragon=0;wheels=0;shield=0;rage=0;reveal=0;anim_left=0;transformed=0;showing_transformation=false
	queue_redraw()

func upgrade(id: String) -> int:
	return int(build.get(id,0))

func damage() -> float:
	return float(JourneyContent.HEROES[hero].damage)*(1+.10*upgrade("dmg"))*(1.45+.1*upgrade("w_giant") if form_left>0 else 1.0)*(1.2 if dragon>0 else 1.0)

func tick(dt: float, input_enabled: bool=true) -> void:
	if is_dead:return
	for k in cool:cool[k]=maxf(0,float(cool[k])-dt)
	for key in ["anim_left","invulnerable","shield","wheels","dragon","reveal","combo_left","transformed"]:set(key,maxf(0,float(get(key))-dt))
	if combo_left<=0:combo=0;form_charge=maxf(0,form_charge-dt*4)
	if form_left>0:
		form_left=maxf(0,form_left-dt);form_age+=dt
		if form_left<=0:end_form()
	else:ultimate=0
	if upgrade("regen")>0:hp=minf(max_hp,hp+dt*.5*upgrade("regen"))
	var dir=Vector2.ZERO
	if input_enabled:
		dir=Input.get_vector("move_left","move_right","move_up","move_down")
		if Input.is_action_just_pressed("dash"):dash(dir)
		if Input.is_action_just_pressed("skill_q"):cast("q")
		if Input.is_action_just_pressed("skill_e"):cast("e")
		if Input.is_action_just_pressed("gong"):cast("g")
		if Input.is_action_just_pressed("ult"):cast("r")
		if Input.is_action_just_pressed("swap"):game.cycle_hero()
	move_vector=dir
	var speed=float(JourneyContent.HEROES[hero].speed)*(1+.06*upgrade("moveSpeed"))
	if wheels>0:speed*=1.38
	if dragon>0:speed*=1.25
	if game.world.surface_at(position)=="water" and hero not in ["whiteDragon","shaWujing"]:speed*=.58
	if game.world.surface_at(position)=="ice":speed*=1.16
	if transformed>0:speed*=1.3
	if game.chapter.get("mechanic")=="wind" and game.phase==1 and hero!="bajie":speed*=.7
	if dash_left>0:
		dash_left-=dt
		position=game.world.resolve(position+dash_direction*dash_speed*dt,10)
		trail_timer-=dt
		if trail_timer<=0:
			trail_timer=.025;game.fx.emit("trail",position,JourneyContent.color(hero),17,Vector2.RIGHT,.25)
		for e in game.foes:
			if not e.dead and position.distance_to(e.position)<42 and not e.dash_hits.has(attack_serial):
				e.dash_hits[attack_serial]=true
				if upgrade("dashDmg")>0:e.hit(16+12*upgrade("dashDmg"),dash_direction*180,false)
				if form_left>0 and form_age>.8:ultimate=minf(100,ultimate+5)
	else:position=game.world.resolve(position+dir*speed*dt,10)
	if dir.length_squared()>0:facing=dir
	if cool.auto<=0 and anim_left<=.1 and transformed<=0:
		var target=game.nearest(position,190 if hero=="tang" else 105)
		if target!=null:
			facing=(target.position-position).normalized()
			_auto(target)
	if anim_left<=0:sprite.play("run" if dir.length_squared()>0 or dash_left>0 else "idle")
	var target_kind="wolf" if transformed>0 else ("dragon" if hero=="whiteDragon" and (dragon>0 or form_left>0) else hero)
	if visual_kind!=target_kind:sprite.sprite_frames=JourneyContent.frames(target_kind);sprite.play("run");visual_kind=target_kind
	sprite.flip_h=facing.x<0
	sprite.scale=Vector2.ONE*(1.4 if form_left>0 else (1.23 if dragon>0 else 1.0))
	sprite.modulate=Color(1.7,1.5,1.3) if invulnerable>.38 else Color.WHITE
	sprite.modulate.a=.5 if dash_left>0 else 1.0
	z_index=clampi(int(position.y/10),0,200)
	queue_redraw()

func animate(anim: String, duration: float) -> void:
	anim_left=duration
	sprite.stop();sprite.play(anim)

func dash(dir: Vector2) -> void:
	if cool.dash>0:return
	attack_serial+=1
	dash_direction=dir if dir.length_squared()>0 else facing
	dash_left=.16
	dash_speed=640.0
	cool.dash=maxf(.6,1.25-.15*upgrade("dashCd"))
	game.sound.play("dash",.65)
	if hero=="wukong" and game.has_ability("seventyTwo") and upgrade("w_72")>0:
		game.add_companion("wukong",position,2.8+upgrade("w_72"))

func _auto(target) -> void:
	auto_step+=1
	cool.auto=maxf(.23,.50*(1-.09*upgrade("atkSpeed")))*( .65 if wheels>0 else 1.0)
	animate("atk",.4)
	var dmg=damage()
	var radius=94.0*(1+.12*upgrade("range")+.06*upgrade("w_arc"))
	var kind="cone"
	var shape="slash"
	if hero=="tang":kind="circle";shape="lotus";radius=40*(1+.12*upgrade("range"))
	if hero=="wukong" and auto_step%3==0:dmg*=1.5+.12*upgrade("w_pose");radius*=1.2
	if hero=="shaWujing":kind="line";shape="staff";radius=145*(1+.12*upgrade("range"))
	if hero=="erlang" and auto_step%3==0:dmg*=1.5
	var at=target.position if hero=="tang" else position
	game.queue_attack({"at":at,"dir":facing,"radius":radius,"damage":dmg,"kind":kind,"vfx":shape,"color":JourneyContent.color(hero),"hero":hero,"auto":true,"knock":120.0,"heavy":auto_step%3==0},.12)

func cast(key: String) -> bool:
	if is_dead or float(cool[key])>0 or anim_left>.28:return false
	if key=="r":return _ultimate()
	if key=="g":
		var need=g_ability()
		if not game.has_ability(need):
			game.toast("尚未习得"+JourneyContent.ABILITIES[need].name+" · 前往"+JourneyContent.ABILITIES[need].source)
			game.sound.play("ui",.4)
			return false
	var target=game.nearest(position,600)
	if target!=null:facing=(target.position-position).normalized()
	var mouse=game.get_global_mouse_position()-position
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and mouse.length()>8:facing=mouse.normalized()
	cool[key]=(3.5 if key=="q" else (6.5 if key=="e" else 14.0))*maxf(.62,1-.1*upgrade("cdr"))
	animate("cast" if key in ["g","e"] else "atk",.4)
	game.sound.play(hero,.9)
	game.fx.emit("rune",position,JourneyContent.color(hero),34,facing,.18)
	var a={"at":position,"dir":facing,"radius":170.0,"damage":damage()*1.9,"kind":"circle","vfx":"ring","color":JourneyContent.color(hero),"hero":hero,"auto":false,"knock":200.0,"heavy":true}
	match hero:
		"tang":
			if key=="q":
				a.radius=185+22*upgrade("t_nova");a.vfx="lotus";a.cleanse=true
				if upgrade("t_ring")>0:
					var echo=a.duplicate();echo.radius*=1.3;echo.damage*=.5*upgrade("t_ring");game.queue_attack(echo,.42)
			elif key=="e":
				shield=3.0;game.add_zone(position,105,3.0,"ward",hero,4);a.damage=damage()*.4
			else:
				a.radius=390;a.damage=damage()*2.2;a.vfx="lotus";a.cleanse=true
				hp=minf(max_hp,hp+max_hp*.18);game.clear_hazards(position,420);reveal=6
		"wukong":
			if key=="q":a.radius=220;a.kind="cone";a.vfx="slash";a.damage*=1.35;a.breaker=true
			elif key=="e":
				a.at=target.position if target!=null else position+facing*130;a.radius=150;a.damage*=1.65;a.vfx="impact";a.breaker=true
			else:
				if g_ability()=="seventyTwo":transformed=7;a.damage=0;a.radius=70;a.vfx="rune"
				else:reveal=8;a.radius=440;a.vfx="ring";a.damage=damage()*.8;a.reveal=true
				if game.has_ability("seventyTwo"):
					for i in 3:game.add_companion("wukong",position+Vector2.from_angle(i*TAU/3)*35,6+upgrade("w_clone"))
		"whiteDragon":
			if key=="q":
				a.kind="line";a.radius=300+25*upgrade("d_glide");a.vfx="beam";a.mark=true
				a.travel=true
			elif key=="e":a.radius=360+20*upgrade("d_call");a.detonate=true;a.vfx="lightning";a.damage=damage()*(2.0+.25*upgrade("d_thunder"))
			else:
				dragon=9;invulnerable=.4;a.radius=230;a.damage*=1.4;a.mark=true;a.vfx="wave";game.clear_hazards(position,260)
		"bajie":
			if key=="q":
				a.vfx="impact";a.radius=165+20*upgrade("b_quake");a.damage*=1+.15*upgrade("b_quake");a.breaker=true
				if rage>=40:a.damage*=1.8;rage-=40;a.radius*=1.2
			elif key=="e":a.radius=255+20*upgrade("b_admiral");a.pull=true;a.damage*=.65;shield=1.8
			else:
				shield=5;rage=minf(100,rage+35);a.radius=230;a.pull=true;game.add_zone(position,160,6,"ward",hero,18)
		"shaWujing":
			if key=="q":
				a.kind="line";a.radius=340;a.vfx="staff"
				var back=a.duplicate();back.at=position+facing*340;back.dir=-facing;back.damage*=1.25+.12*upgrade("s_speed");game.queue_attack(back,.58)
			elif key=="e":
				a.radius=180;a.slow=true;game.add_zone(position,180,4+upgrade("s_erosion"),"water",hero,8+4*upgrade("s_erosion"))
				if upgrade("s_guard")>0:shield=maxf(shield,1+.5*upgrade("s_guard"))
			else:
				a.radius=320;a.slow=true;a.vfx="wave";game.add_zone(position,270,7,"water",hero,22);shield=3;game.clear_hazards(position,280)
		"nezha":
			if key=="q":
				a.kind="line";a.radius=230;a.vfx="beam";a.burn=true;a.damage*=1+.15*upgrade("n_spear")
				for i in 2:game.queue_attack(a.duplicate(),.28+i*.13)
			elif key=="e":wheels=5+upgrade("n_wheels");a.radius=210;a.pull=true;game.add_zone(position,100,4,"fire",hero,15)
			else:
				a.kind="line";a.radius=430;a.vfx="ring";a.breaker=true;a.burn=true
				var back=a.duplicate();back.at=position+facing*430;back.dir=-facing;game.queue_attack(back,.60)
		"erlang":
			if key=="q":a.kind="cone";a.radius=180;a.vfx="slash";a.damage*=1.4+.12*upgrade("e_meishan");a.breaker=true
			elif key=="e":a.kind="line";a.radius=660;a.vfx="beam";a.reveal=true;a.damage*=1.4+.2*upgrade("e_eye")
			else:reveal=8;game.add_companion("wolf",position,8);a.radius=320;a.reveal=true;a.damage=damage()*.7
	game.queue_attack(a,.16)
	game.skill_used(hero,key)
	return true

func g_ability() -> String:
	if hero=="wukong" and game.has_ability("seventyTwo") and (game.chapter.get("gate","")=="seventyTwo" or not game.has_ability("fieryEyes") or Input.is_key_pressed(KEY_SHIFT)):return "seventyTwo"
	return JourneyContent.HEROES[hero].ability

func _ultimate() -> bool:
	if form_left<=0 or form_age<.8 or ultimate<100:
		game.toast("法相中积满终结灵力后，按 R 释放")
		return false
	var c=JourneyContent.color(hero)
	var shape={"tang":"lotus","wukong":"staff","whiteDragon":"lightning","bajie":"impact","shaWujing":"wave","nezha":"feather","erlang":"beam"}[hero]
	game.cinematic(JourneyContent.HEROES[hero].ult,c)
	game.sound.play("ultimate")
	game.queue_attack({"at":position,"dir":facing,"radius":630.0,"damage":damage()*8,"kind":"circle","vfx":shape,"color":c,"hero":hero,"auto":false,"knock":320.0,"heavy":true,"ultimate":true,"reveal":true},.65)
	for i in 6:
		var at=position+Vector2.from_angle(i*TAU/6)*180
		game.fx.emit(shape,at,c,200,Vector2.from_angle(i*TAU/6),1.05)
	end_form()
	cool.r=18
	invulnerable=maxf(invulnerable,.8)
	animate("cast",.7)
	return true

func on_hit() -> void:
	combo=combo+1 if combo_left>0 else 1
	combo_left=2.8
	if form_left<=0:
		form_charge=minf(100,form_charge+(5+.5*min(combo,12))*(1+.2*upgrade("comboForm")))
		if form_charge>=100:
			form_charge=0;form_left=10+upgrade("formDuration");form_age=0;ultimate=0
			game.cinematic(JourneyContent.HEROES[hero].form,JourneyContent.color(hero),.8)
			game.sound.play("form");game.fx.emit("lotus",position,JourneyContent.color(hero),155,facing,.8)
	elif form_age>=.8:ultimate=minf(100,ultimate+2*(1+.2*upgrade("ultGain")))

func end_form() -> void:
	form_left=0;form_age=0;ultimate=0

func on_kill() -> void:
	kills+=1
	if form_left>0 and form_age>=.8:ultimate=minf(100,ultimate+7*(1+.2*upgrade("ultGain")))
	if upgrade("lifesteal")>0:hp=minf(max_hp,hp+1.3*upgrade("lifesteal"))
	if combo_left>0 and form_left<=0:form_charge=minf(100,form_charge+2*upgrade("killForm"))

func take_hit(amount: float, from: Vector2) -> bool:
	if invulnerable>0 or dash_left>0 or is_dead:return false
	amount*=float(game.save.settings.get("difficulty",1.0))
	var reduction=minf(.65,.08*upgrade("dr")+(.4 if shield>0 else 0))
	var actual=amount*(1-reduction)
	hp=maxf(0,hp-actual);invulnerable=.55;combo=0;combo_left=0
	if anim_left<=0:animate("hurt",.2)
	if hero=="bajie":rage=minf(100,rage+amount*(1+.25*upgrade("b_fury")))
	game.sound.play("hurt");game.fx.number(position,"-"+str(int(actual)),Color("ff8d88"),true)
	game.shake=maxf(game.shake,4);game.hurt_flash=.22
	position=game.world.resolve(position+(position-from).normalized()*9,10)
	if upgrade("thorns")>0 or (hero=="tang" and shield>0 and upgrade("t_reflect")>0):
		game.queue_attack({"at":position,"radius":70.0,"kind":"circle","damage":8.0+5*upgrade("thorns")+8*upgrade("t_reflect"),"vfx":"ring","dir":Vector2.RIGHT,"color":JourneyContent.color(hero),"hero":hero,"auto":false,"knock":60.0,"heavy":false},.02)
	if hp<=0:is_dead=true;game.fail_run()
	return true

func gain_xp(n: int) -> void:
	xp+=n
	while xp>=xp_next:
		xp-=xp_next;level+=1;xp_next=int(ceil(xp_next*1.26))+1
		max_hp+=4;hp=minf(max_hp,hp+14)
		game.pending_upgrades=mini(3,game.pending_upgrades+1)
		game.sound.play("level",.75)

func add_card(id: String) -> void:
	build[id]=upgrade(id)+1
	if id=="hp":max_hp+=18;hp=minf(max_hp,hp+35)

func _draw() -> void:
	draw_set_transform(Vector2(0,2),0,Vector2(1,.4));draw_circle(Vector2.ZERO,17,Color(0,0,0,.35));draw_set_transform(Vector2.ZERO)
	var c=JourneyContent.color(hero)
	draw_arc(Vector2(0,1),16,0,TAU,24,Color(c,.75),1)
	if shield>0:draw_arc(Vector2(0,-22),33,0,TAU,32,Color(c,.7),2)
	if form_left>0:
		_draw_form(c)
		for i in 5:
			var a=Time.get_ticks_msec()*.001+i*TAU/5
			draw_circle(Vector2(cos(a)*26,-20+sin(a)*12),2,c)
	if dragon>0:
		var pts=PackedVector2Array()
		for i in 16:pts.append(Vector2(-sin(i*.3+Time.get_ticks_msec()*.007)*17,-10+i*4))
		draw_polyline(pts,Color("4d9fae"),12);draw_polyline(pts,Color("bceeed"),5)
	if wheels>0:
		for x in [-12,12]:draw_arc(Vector2(x,1),10,0,TAU,12,Color("ffa568"),3)

func _draw_form(c: Color) -> void:
	# Character-specific sacred silhouette, visible behind the actual sprite.
	match hero:
		"tang":
			draw_arc(Vector2(0,-55),37,0,TAU,32,Color(c,.5),3)
			for i in 9:
				var d=Vector2.from_angle(i*TAU/9)
				draw_colored_polygon(PackedVector2Array([Vector2(0,-30)+d*26,Vector2(0,-30)+d.rotated(-.2)*43,Vector2(0,-30)+d*58,Vector2(0,-30)+d.rotated(.2)*43]),Color(c,.20))
		"wukong":
			draw_line(Vector2(-54,-75),Vector2(55,15),Color(c,.18),12);draw_line(Vector2(-54,-75),Vector2(55,15),Color(c,.6),4)
			for side in [-1,1]:draw_polyline(PackedVector2Array([Vector2(side*12,-78),Vector2(side*24,-100),Vector2(side*36,-105),Vector2(side*42,-92)]),Color(c,.7),3)
		"whiteDragon":
			var pts=PackedVector2Array()
			for i in 28:pts.append(Vector2(sin(i*.23+game.drawing_clock*3)*38,-70+i*4))
			draw_polyline(pts,Color(c,.18),20);draw_polyline(pts,Color(c,.65),4)
		"bajie":
			draw_arc(Vector2(0,-30),49,0,TAU,24,Color(c,.25),8)
			for x in range(-40,41,10):draw_line(Vector2(x,-82),Vector2(x,-61),Color(c,.6),3)
			draw_line(Vector2(-43,-65),Vector2(43,-65),Color(c,.7),4)
		"shaWujing":
			for i in 9:
				var p=Vector2.from_angle(i*TAU/9+game.drawing_clock*.4)*48+Vector2(0,-30)
				draw_circle(p,6,Color(c,.7));draw_rect(Rect2(p-Vector2(3,2),Vector2(2,2)),Color("234142"));draw_rect(Rect2(p+Vector2(1,-2),Vector2(2,2)),Color("234142"))
		"nezha":
			var tex=load("res://assets/pixel/nezha.png")
			for side in [-1,1]:
				draw_texture_rect_region(tex,Rect2(Vector2(side*23-23,-80),Vector2(46,46)),Rect2(9,2,46,32),Color(1,.7,.55,.65))
				for arm in 3:draw_line(Vector2(side*10,-40+arm*10),Vector2(side*(45-arm*5),-61+arm*24),Color(c,.6),4)
		"erlang":
			var at=Vector2(0,-90)
			draw_colored_polygon(PackedVector2Array([at+Vector2(-30,0),at+Vector2(0,-13),at+Vector2(30,0),at+Vector2(0,13)]),Color(c,.35))
			draw_circle(at,6,Color("fff2b7"));draw_line(at+Vector2(0,-22),at+Vector2(0,22),Color(c,.6),2)
