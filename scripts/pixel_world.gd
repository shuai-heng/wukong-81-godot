class_name PixelWorld
extends Node2D

const SIZE=Vector2(2400,1600)
var chapter={}
var colors: Array[Color]=[]
var obstacles: Array[Vector3]=[]
var rng=RandomNumberGenerator.new()
var spawn=Vector2(1050,960)
var landmark=Vector2(1200,530)

func build(c: Dictionary) -> void:
	chapter=c
	colors.clear()
	for h in JourneyContent.THEMES[c.theme]:colors.append(Color(h))
	obstacles.clear()
	rng.seed=abs(hash(c.id))+81
	for i in 65:
		var at=Vector2(rng.randf_range(100,2300),rng.randf_range(120,1450))
		if absf(at.x-1200)<260 or at.distance_to(spawn)<240:continue
		obstacles.append(Vector3(at.x,at.y,16))
	queue_redraw()

func resolve(at: Vector2, radius: float) -> Vector2:
	at=at.clamp(Vector2(36,60),SIZE-Vector2(36,36))
	for o in obstacles:
		var p=Vector2(o.x,o.y)
		var off=at-p
		if off.length()<o.z+radius and off.length()>0.01:at=p+off.normalized()*(o.z+radius)
	return at

func _draw() -> void:
	if colors.is_empty():return
	rng.seed=abs(hash(chapter.id))+81
	draw_rect(Rect2(Vector2.ZERO,SIZE),colors[0])
	# Pixel stone mosaic with a winding road; large structures occupy clear silhouettes.
	for y in range(0,1600,32):
		for x in range(0,2400,32):
			var road=absf(x-(1200+sin(y*.004+chapter.index)*120))<110
			var c=colors[2] if road else colors[1]
			c=c.lightened(rng.randf_range(-.012,.012))
			draw_rect(Rect2(x,y,32,32),c)
			for grain in 4:
				var gp=Vector2(x+rng.randi_range(1,29),y+rng.randi_range(1,29))
				draw_rect(Rect2(gp,Vector2(2,1)),c.lightened(.035 if grain%2 else -.025))
			if rng.randf()<.53:
				var p=Vector2(x+rng.randi_range(3,25),y+rng.randi_range(3,25))
				draw_rect(Rect2(p,Vector2(3,2)),colors[3].darkened(.35))
			if road and rng.randf()<.35:draw_line(Vector2(x+3,y+30),Vector2(x+25,y+30),colors[0].lightened(.09),1)
			if not road and chapter.theme in ["mountain","forest","village"] and rng.randf()<.25:
				_grass(Vector2(x+15,y+16))
	if chapter.theme in ["river","snow"]:
		for y in range(660,815,8):
			draw_rect(Rect2(80,y,2240,8),Color("254d61") if y%16==0 else Color("2d5c6e"))
		for i in 150:
			var x=rng.randi_range(100,2300);var y=rng.randi_range(670,800)
			draw_rect(Rect2(x,y,rng.randi_range(7,26),2),Color("52808a"))
		for y in range(640,845,12):
			draw_rect(Rect2(1070,y,270,10),Color("8a8065"))
			draw_rect(Rect2(1070,y,270,2),Color("b5a68a"))
		for x in [1062,1340]:draw_rect(Rect2(x,630,6,220),colors[0])
	elif chapter.theme=="fire":
		for i in 18:
			var at=Vector2(rng.randi_range(120,2200),rng.randi_range(150,1450))
			if abs(at.x-1200)<170:continue
			draw_colored_polygon(PackedVector2Array([at,at+Vector2(80,-10),at+Vector2(112,24),at+Vector2(62,50),at+Vector2(-18,28)]),Color("8b3e35"))
			draw_polyline(PackedVector2Array([at+Vector2(5,15),at+Vector2(55,7),at+Vector2(90,25)]),Color("eb8951"),3)
	elif chapter.theme in ["sand","poison"]:
		for i in 60:
			var at=Vector2(rng.randi_range(100,2300),rng.randi_range(100,1500))
			draw_arc(at,32+rng.randf()*35,.1,2.5,9,colors[2],2)
	# Landmark and side architecture.
	match chapter.theme:
		"village","palace","temple":
			_building(Vector2(540,430),1.6)
			_building(Vector2(1630,420),1.5)
			_building(landmark-Vector2(160,160),2.0)
		"heaven":
			for x in [750,920,1470,1640]:_pillar(Vector2(x,440),140)
			_building(landmark-Vector2(160,180),2.0)
		"mountain":_mountain(landmark)
		"bone","underworld":
			for x in [760,880,1510,1630]:_pillar(Vector2(x,460),70)
			for i in 14:_rock(Vector2(900+i*40,390+sin(i)*30),24)
		_:_shrine(landmark)
	for o in obstacles:_rock(Vector2(o.x,o.y),o.z)
	for i in 155:
		var p=Vector2(rng.randi_range(60,2340),rng.randi_range(90,1520))
		if abs(p.x-1200)<230 or p.y>620 and p.y<850:continue
		if chapter.theme in ["forest","mountain","village"]:
			if i%5==0:_tree(p)
			else:_grass(p)
		elif chapter.theme=="sand":
			draw_line(p,p+Vector2(-5,-16),colors[3],2);draw_line(p,p+Vector2(5,-12),colors[3],2)
		elif i%4==0:_lantern(p,Color("94c8ba") if chapter.theme=="underworld" else Color("f1bb71"))
	for x in [920,1480]:_lantern(Vector2(x,880),Color("e8b470"))
	_objective_landmark()
	# Physical map border, not an exposed gray viewport.
	for x in range(0,2400,44):_rock(Vector2(x,30),22);_rock(Vector2(x,1580),20)
	for y in range(30,1580,44):_rock(Vector2(25,y),22);_rock(Vector2(2375,y),22)

func _rock(p: Vector2, r: float) -> void:
	draw_circle(p+Vector2(2,5),r+3,Color(0,0,0,.18))
	var shape=PackedVector2Array([p+Vector2(-r,0),p+Vector2(-r*.7,-r*.7),p+Vector2(r*.4,-r),p+Vector2(r,-r*.2),p+Vector2(r*.8,r*.35),p+Vector2(-r*.5,r*.4)])
	draw_colored_polygon(shape,colors[0]);draw_colored_polygon(PackedVector2Array([shape[0]+Vector2(3,-1),shape[1],shape[2],shape[3]-Vector2(3,1),p+Vector2(0,1)]),colors[3].darkened(.1))
	draw_line(shape[1]+Vector2(2,1),shape[2]-Vector2(2,-1),colors[3].lightened(.18),2)

func _tree(p: Vector2) -> void:
	draw_ellipse_shadow(p+Vector2(7,8),Vector2(35,12))
	draw_set_transform(p)
	draw_rect(Rect2(-5,-48,10,52),Color("4d4238"));draw_rect(Rect2(-3,-45,3,47),Color("74604a"))
	for row in 3:
		var y=-20-row*21;var w=37-row*7
		var pts=PackedVector2Array([Vector2(-w,y),Vector2(-w+6,y-8),Vector2(-w+9,y-8),Vector2(-12,y-32),Vector2(0,y-49),Vector2(15,y-30),Vector2(w-5,y-9),Vector2(w,y)])
		draw_colored_polygon(pts,Color("142d2d"));draw_colored_polygon(PackedVector2Array([Vector2(-w+5,y-5),Vector2(0,y-45),Vector2(7,y-18),Vector2(-5,y-9)]),Color("315448"))
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow(at: Vector2, size: Vector2) -> void:
	draw_set_transform(at,0,Vector2(size.x/size.y,1))
	draw_circle(Vector2.ZERO,size.y,Color(0,0,0,.2))
	draw_set_transform(Vector2.ZERO)

func _grass(p: Vector2) -> void:
	for i in 4:
		var v=p+Vector2(i*3,0)
		draw_line(v,v+Vector2(i-2,-6-i%2*3),Color("54725a"),1)

func surface_at(at: Vector2) -> String:
	if chapter.theme in ["river","snow"] and at.y>660 and at.y<815 and (at.x<1070 or at.x>1340):return "ice" if chapter.theme=="snow" else "water"
	return "ground"

func _objective_landmark() -> void:
	var p=Vector2(1200,830)
	match chapter.mechanic:
		"seal","cleanse","rain":
			draw_rect(Rect2(p-Vector2(30,8),Vector2(60,20)),colors[0])
			draw_rect(Rect2(p-Vector2(26,12),Vector2(52,12)),colors[3])
			draw_rect(Rect2(p-Vector2(19,16),Vector2(38,5)),colors[4])
			for x in [-12,0,12]:draw_line(p+Vector2(x,-16),p+Vector2(x,-35),Color("bb8460"),2)
		"rescue","prison":
			for side in [-1,1]:
				var q=p+Vector2(side*185,0)
				draw_rect(Rect2(q-Vector2(22,40),Vector2(44,47)),Color("222e32"))
				draw_rect(Rect2(q-Vector2(20,38),Vector2(40,38)),Color("564b45"))
				for x in range(-18,21,9):draw_line(q+Vector2(x,-38),q+Vector2(x,3),Color("9b9273"),3)
		"harvest","relic":
			for side in [-1,1]:
				var q=p+Vector2(side*175,0)
				draw_rect(Rect2(q-Vector2(26,30),Vector2(52,32)),Color("584738"))
				draw_rect(Rect2(q-Vector2(24,29),Vector2(48,7)),Color("a18050"))
				for x in [-18,-6,6,18]:draw_line(q+Vector2(x,-20),q+Vector2(x,0),Color("876a43"),2)
		"vessel":
			for side in [-1,1]:
				var q=p+Vector2(side*165,-5)
				draw_circle(q,19,Color("8a6950"));draw_circle(q-Vector2(0,20),12,Color("ba9562"));draw_rect(Rect2(q-Vector2(5,35),Vector2(10,9)),Color("dfc991"))
		"thorns","web":
			for i in 8:
				var q=p+Vector2((i-4)*50,-135)
				draw_line(q+Vector2(-20,0),q+Vector2(20,-35),Color("64856c"),5)
				draw_line(q+Vector2(5,-28),q+Vector2(-10,-44),Color("93a87b"),3)
		"weakpoint","reveal":
			for side in [-1,1]:_pillar(p+Vector2(side*190,-12),68)
		_:
			for side in [-1,1]:_lantern(p+Vector2(side*150,0),colors[4])

func _building(p: Vector2,s: float) -> void:
	draw_set_transform(p,0,Vector2(s,s))
	draw_rect(Rect2(-8,84,182,12),Color("182a2d"));draw_rect(Rect2(4,14,150,70),colors[3].darkened(.15))
	draw_rect(Rect2(55,32,42,52),colors[0]);draw_rect(Rect2(62,39,28,43),Color("513d35"))
	for x in [15,115]:
		draw_rect(Rect2(x,33,25,24),Color("d2a566"));draw_rect(Rect2(x+3,36,19,18),Color("84643f"))
		for n in range(0,20,6):draw_rect(Rect2(x+3+n,36,2,18),colors[0])
	var roof=PackedVector2Array([Vector2(-16,24),Vector2(0,13),Vector2(18,-9),Vector2(135,-9),Vector2(154,13),Vector2(176,24),Vector2(160,28),Vector2(0,28)])
	draw_colored_polygon(roof,Color("263c43"));draw_polyline(roof,colors[0],3)
	for y in [-4,3,10,17]:draw_line(Vector2(18-(y+4)*.7,y),Vector2(135+(y+4)*.7,y),Color("49606a"),2)
	draw_rect(Rect2(13,-12,128,4),Color("9b9270"))
	draw_set_transform(Vector2.ZERO)

func _mountain(p: Vector2) -> void:
	for i in 5:
		var x=p.x-200+i*87;var h=[160,260,325,265,170][i]
		var pts=PackedVector2Array([Vector2(x-14,p.y),Vector2(x-9,p.y-h+24),Vector2(x+8,p.y-h),Vector2(x+48,p.y-h-7),Vector2(x+69,p.y-h+18),Vector2(x+82,p.y)])
		draw_colored_polygon(pts,Color("293d42"));draw_polyline(pts,Color("14282e"),4)
		draw_colored_polygon(PackedVector2Array([pts[1],pts[2],pts[3],Vector2(x+30,p.y-12),Vector2(x+2,p.y-4)]),Color("4c6060"))
		for j in 7:draw_rect(Rect2(x+5+j%3*11,p.y-j*23-22,3,12),Color("73807a"))
	draw_rect(Rect2(p.x-13,p.y-155,28,111),Color("e8cb86"));draw_rect(Rect2(p.x-9,p.y-149,20,99),Color("c35e46"))
	for y in range(0,70,12):draw_line(p+Vector2(-5,-140+y),p+Vector2(7,-136+y),Color("f6db98"),2)

func _pillar(p: Vector2,h: float) -> void:
	draw_rect(Rect2(p.x-14,p.y-h,28,h),colors[0]);draw_rect(Rect2(p.x-11,p.y-h+5,18,h-8),colors[3]);draw_rect(Rect2(p.x-8,p.y-h+7,4,h-14),colors[4].darkened(.2))
	draw_rect(Rect2(p.x-22,p.y-3,44,8),colors[2]);draw_rect(Rect2(p.x-20,p.y-h-6,40,10),colors[4].darkened(.3))

func _shrine(p: Vector2) -> void:
	for i in 3:draw_rect(Rect2(p.x-95+i*12,p.y-5-i*8,190-i*24,10),colors[3])
	_pillar(p+Vector2(-65,-20),65);_pillar(p+Vector2(65,-20),65)
	draw_rect(Rect2(p.x-82,p.y-95,164,14),colors[0]);draw_rect(Rect2(p.x-80,p.y-98,160,7),colors[4].darkened(.25))

func _lantern(p: Vector2,c: Color) -> void:
	draw_circle(p,22,Color(c,.035));draw_circle(p,12,Color(c,.08))
	draw_rect(Rect2(p.x-2,p.y-24,4,25),Color("5a483a"));draw_rect(Rect2(p.x-7,p.y-33,14,14),Color("3f3433"));draw_rect(Rect2(p.x-5,p.y-31,10,10),c);draw_rect(Rect2(p.x-2,p.y-30,3,8),c.lightened(.4))
