class_name JourneyFoe
extends Node2D

var game
var sprite: AnimatedSprite2D
var kind="wolf"
var hp=45.0
var max_hp=45.0
var speed=75.0
var damage=10.0
var boss=false
var elite=false
var dead=false
var tame_ready=false
var pattern="charge"
var phase=1
var attack_cd=1.5
var windup=0.0
var attack_target=Vector2.ZERO
var stun=0.0
var flash=0.0
var knock=Vector2.ZERO
var burn=0.0
var burn_tick=0.0
var slow=0.0
var marks=0
var mark_left=0.0
var exposed=0.0
var charge=0.0
var charge_dir=Vector2.RIGHT
var dash_hits={}
var action_count=0
var scale_base=1.0

func configure(g, k: String, power: float, is_boss: bool=false, is_elite: bool=false) -> void:
	game=g;kind=k;boss=is_boss;elite=is_elite
	if boss and game.chapter.id=="eagle":kind="dragon"
	max_hp=(920 if boss else (135 if elite else 32))*power
	hp=max_hp
	speed=(60 if boss else (90 if elite else 65))+fmod(abs(hash(kind)),25)
	damage=(16 if boss else (14 if elite else 8))*(.85+power*.15)
	if kind in ["bone","monk"]:speed*=.72
	if kind in ["bat","raven","rabbit"]:speed*=1.3;max_hp*=.65;hp=max_hp
	scale_base=1.65 if boss else (1.15 if elite else .85)
	if boss:pattern=game.chapter.pattern
	attack_cd=1.2+randf()

func _ready() -> void:
	sprite=AnimatedSprite2D.new()
	sprite.sprite_frames=JourneyContent.frames(kind)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position=Vector2(0,-24*scale_base)
	sprite.scale=Vector2.ONE*scale_base
	add_child(sprite)
	sprite.play("run")

func tick(dt: float) -> void:
	if dead or tame_ready:return
	if boss and game.chapter.id=="heaven" and phase>=2 and kind!="erlang":
		kind="erlang";sprite.sprite_frames=JourneyContent.frames(kind);pattern="storm";game.cinematic("杨戬 · 天眼勘破万象",JourneyContent.color("erlang"),.8)
	flash=maxf(0,flash-dt);stun=maxf(0,stun-dt);slow=maxf(0,slow-dt);exposed=maxf(0,exposed-dt)
	mark_left=maxf(0,mark_left-dt)
	if mark_left<=0:marks=0
	if burn>0:
		burn-=dt;burn_tick-=dt
		if burn_tick<=0:
			burn_tick=.5;hit(6.0,Vector2.ZERO,false,true)
			if dead:return
	position=game.world.resolve(position+knock*dt,13*scale_base)
	knock=knock.move_toward(Vector2.ZERO,700*dt)
	var off: Vector2=game.player.position-position
	var dir=off.normalized()
	var dist=off.length()
	if game.player.transformed>0 and not boss:
		sprite.play("idle");return
	if charge>0:
		charge-=dt;position=game.world.resolve(position+charge_dir*350*dt,20)
		game.fx.emit("trail",position,Color("e28c6a"),12,charge_dir,.2)
		if dist<35:game.player.take_hit(damage*1.4,position)
	elif windup>0:
		windup-=dt
		if windup<=0:_strike()
	elif stun<=0:
		attack_cd-=dt
		if attack_cd<=0 and (dist<(400 if boss else (260 if kind in ["soldier","water","fire"] else 43))):
			_begin_attack()
		else:
			if dist>29*scale_base:
				var separation=Vector2.ZERO
				for other in game.foes:
					if other==self or other.dead:continue
					var away=position-other.position
					if away.length_squared()>1 and away.length_squared()<900:separation+=away.normalized()*(30-away.length())*2
				position=game.world.resolve(position+(dir*speed*(.45 if slow>0 else 1)+separation)*dt,13*scale_base)
			sprite.play("run" if dist>29*scale_base else "idle")
	sprite.flip_h=dir.x<0
	sprite.modulate=Color(3,2.8,2.4) if flash>0 else (Color(.75,.9,1) if slow>0 else Color.WHITE)
	z_index=clampi(int(position.y/10),0,200)
	queue_redraw()

func _begin_attack() -> void:
	action_count+=1
	attack_target=game.player.position
	windup=.70 if boss else .42
	attack_cd=(2.4 if boss else 1.25)*(1.0-.1*(phase-1))
	sprite.stop();sprite.play("atk")
	if boss:
		var rad=85.0 if pattern in ["dragon","charge","rage","triple"] else 115.0
		game.fx.emit("telegraph",attack_target,Color("e97470"),rad,Vector2.RIGHT,windup)
		game.sound.play("warning",.5)
	else:game.fx.emit("telegraph",position,Color("ec806d"),28,Vector2.RIGHT,windup)

func _strike() -> void:
	if dead or tame_ready:return
	if not boss:
		if kind in ["soldier","water","fire"]:
			game.add_projectile(position,(attack_target-position).normalized()*180,damage)
		elif position.distance_to(game.player.position)<52:game.player.take_hit(damage,position)
		game.fx.emit("slash",position,Color("e8a780"),35,(attack_target-position).normalized(),.22)
		return
	exposed=1.4
	if boss and game.chapter.id=="heaven":
		if kind=="erlang":
			game.fx.emit("beam",position,JourneyContent.color("erlang"),position.distance_to(attack_target),(attack_target-position).normalized(),.4)
			game.add_projectile(position,(attack_target-position).normalized()*250,damage,"staff")
		else:
			game.fx.emit("feather",position,JourneyContent.color("nezha"),160,Vector2.RIGHT,.5)
			game.add_danger(attack_target,70,.7,"fire",damage)
	match pattern:
		"charge","dragon","rage":
			charge=.55;charge_dir=(attack_target-position).normalized()
			if pattern=="dragon":
				for i in 3:game.add_danger(attack_target+Vector2((i-1)*90,0),55,.8,"water",damage)
			if pattern=="rage" and phase>=2:game.add_danger(position,155,.7,"slam",damage*1.2)
		"return":
			var d=(attack_target-position).normalized()
			game.add_projectile(position,d*220,damage,"staff")
			game.add_danger(attack_target,70,.9,"water",damage)
		"wind","vessel":
			game.add_danger(position,190,1.2,"pull",damage)
			for i in 2+phase:game.add_projectile(position,Vector2.from_angle(i*TAU/(2+phase)+action_count)*130,damage*.6)
		"mirror":
			game.add_danger(attack_target,80,.55,"shadow",damage)
			for i in 2:game.fx.emit("rune",position+Vector2.from_angle(i*PI+action_count)*130,Color("b799d1"),28,Vector2.RIGHT,1.2)
			if exposed<3:exposed=.65
		"hydra","storm","moon":
			for i in 2+phase:
				var at=attack_target+Vector2.from_angle(i*TAU/(2+phase))*90
				game.add_danger(at,45,.8+i*.10,"lightning",damage)
		"fire","poison","ice","web":
			for i in 2+phase:
				game.add_danger(attack_target+Vector2.from_angle(i*TAU/(2+phase))*90,60,.75,pattern,damage)
		"roots","burrow":
			for i in 4:game.add_danger(attack_target+Vector2((i-2)*65,0),35,.5+i*.12,"spike",damage)
			if pattern=="burrow":position=game.world.resolve(attack_target+Vector2(120,0),20)
		"triple":
			match action_count%3:
				0:charge=.65;charge_dir=(attack_target-position).normalized()
				1:game.add_danger(position,190,.6,"slam",damage)
				2:
					for i in 5:game.add_danger(attack_target+Vector2((i-2)*60,0),45,.55+i*.08,"lightning",damage)
		_:game.add_danger(attack_target,120,.5,"slam",damage)
	game.fx.emit("impact",position,Color("dd9f7c"),55,Vector2.RIGHT,.3)

func hit(amount: float, force: Vector2, critical: bool=false, silent: bool=false, is_ultimate: bool=false) -> bool:
	if dead or tame_ready or amount<=0:return false
	var dmg=amount
	if boss:
		if pattern in ["mirror","hydra"] and exposed<=0:dmg*=.15
		if pattern in ["fire","vessel","rage"] and windup>0:dmg*=.25
		dmg=minf(dmg,max_hp*(.15 if is_ultimate else .08))
		var floor_hp=max_hp*(.66 if phase==1 else (.33 if phase==2 else 0))
		if hp-dmg<floor_hp and phase<3:
			dmg=hp-floor_hp;phase+=1;stun=.8
			game.sound.play("break");game.toast(game.chapter.boss+" · 第"+str(phase)+"阶段")
	hp=maxf(0,hp-dmg)
	if not silent:
		flash=.075;knock=force*(.32 if boss else 1.0)
		stun=maxf(stun,.07 if boss else .16)
		game.hit_feedback(position,dmg,critical or amount>=75)
	if hp<=0:
		if boss:
			tame_ready=true;hp=1;windup=0;charge=0
			sprite.play("hurt");game.boss_ready()
		else:
			dead=true
			game.enemy_died(self)
	return true

func _draw() -> void:
	draw_set_transform(Vector2(0,2),0,Vector2(1,.4));draw_circle(Vector2.ZERO,16*scale_base,Color(0,0,0,.28));draw_set_transform(Vector2.ZERO)
	if not boss and (hp<max_hp or elite):
		draw_rect(Rect2(-15,-57*scale_base,30,3),Color("182633"));draw_rect(Rect2(-15,-57*scale_base,30*hp/max_hp,3),Color("df9275") if not elite else Color("d8b577"))
	if windup>0:draw_arc(Vector2.ZERO,24*scale_base,0,TAU,24,Color("f69876"),2)
	if marks>0:
		for i in mini(3,marks):draw_rect(Rect2(-9+i*7,-66*scale_base,4,5),Color("8de9ef"))
	if exposed>2:draw_arc(Vector2(0,-28*scale_base),12,0,TAU,12,Color("f9dc94"),2)
	if tame_ready:draw_circle(Vector2(0,-65*scale_base),5,Color("f1da8b"))
