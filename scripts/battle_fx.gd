class_name BattleFX
extends Node2D

var items: Array=[]
var numbers: Array=[]
var sparks: Array=[]
var clock=0.0

func emit(kind: String, at: Vector2, color: Color, radius: float=80, dir: Vector2=Vector2.RIGHT, duration: float=.4) -> void:
	if items.size()>100:items.pop_front()
	items.append({"kind":kind,"at":at,"c":color,"r":radius,"dir":dir,"life":duration,"max":duration})

func burst(at: Vector2,c: Color,count: int=8) -> void:
	for i in count:
		if sparks.size()>240:break
		var d=Vector2.from_angle(randf()*TAU)
		sparks.append({"at":at,"v":d*randf_range(50,150),"c":c,"life":randf_range(.18,.42)})

func number(at: Vector2,n: String,c: Color,big: bool=false) -> void:
	if numbers.size()>45:numbers.pop_front()
	numbers.append({"at":at+Vector2(randf_range(-9,9),-35),"text":n,"life":.7,"c":c,"big":big})

func tick(delta: float) -> void:
	clock+=delta
	for a in items:a.life-=delta
	items=items.filter(func(a):return a.life>0)
	for a in numbers:a.life-=delta;a.at.y-=delta*26
	numbers=numbers.filter(func(a):return a.life>0)
	for a in sparks:a.life-=delta;a.at+=a.v*delta;a.v*=pow(.06,delta)
	sparks=sparks.filter(func(a):return a.life>0)
	queue_redraw()

func _draw() -> void:
	for f in items:
		var t=1-f.life/f.max
		var c: Color=f.c;c.a=clampf((1-t)*1.7,0,1)
		var at: Vector2=f.at
		var r: float=f.r
		var d: Vector2=f.dir
		match f.kind:
			"slash":
				var ang=d.angle();var s=ang-1.15+t*1.4
				draw_arc(at,r,s,s+.95,12,Color(c,.16*c.a),16)
				draw_arc(at,r,s,s+.95,12,c,5)
				draw_arc(at,r-3,s+.2,s+.93,10,Color("fff0c9")*Color(1,1,1,c.a),2)
			"beam","staff":
				var end=at+d*r
				draw_line(at,end,Color(c,.12*c.a),26*(1-t)+4)
				draw_line(at,end,c,8*(1-t)+2)
				draw_line(at,end,Color(1,.98,.84,c.a),3)
				for j in 5:draw_rect(Rect2(at+d*r*j/5.0+Vector2(-2,-2),Vector2(4,4)),Color(1,1,1,c.a))
			"lightning":
				var pts=PackedVector2Array([at])
				var ortho=Vector2(-d.y,d.x)
				for j in range(1,7):pts.append(at+d*r*j/7.0+ortho*(sin(j*27+int(t*8))*13))
				pts.append(at+d*r)
				draw_polyline(pts,Color(c,.2*c.a),12);draw_polyline(pts,c,4);draw_polyline(pts,Color(1,1,1,c.a),1)
			"ring","wave","lotus":
				var rad=maxf(3,r*sin(minf(1,t*1.8)*PI*.5))
				draw_arc(at,rad,0,TAU,48,Color(c,.16*c.a),10)
				draw_arc(at,rad,0,TAU,48,c,3)
				if f.kind=="lotus":
					for j in 8:
						var v=Vector2.from_angle(j*TAU/8+t*.3)
						draw_colored_polygon(PackedVector2Array([at+v*rad*.3,at+v.rotated(-.18)*rad*.65,at+v*rad,at+v.rotated(.18)*rad*.65]),Color(c,c.a*.35))
				else:
					for j in 10:
						var v=Vector2.from_angle(j*TAU/10)
						draw_line(at+v*rad*.75,at+v*(rad+8),c,2)
			"impact":
				for j in 6:
					var v=Vector2.from_angle(j*TAU/6)
					draw_line(at+v*(3+t*r*.3),at+v*(r*(.45+t*.5)),c,3*(1-t)+1)
			"rune","ward":
				draw_arc(at,r,clock*.4,TAU+clock*.4,32,Color(c,.65*c.a),2)
				for j in 8:
					var p=at+Vector2.from_angle(j*TAU/8+clock*.3)*r
					draw_rect(Rect2(p-Vector2(3,3),Vector2(6,6)),c)
			"telegraph":
				draw_circle(at,r,Color(.9,.25,.25,.08+.09*t))
				draw_arc(at,r,-PI*.5,-PI*.5+TAU*t,48,Color(1,.4,.32,.9),3)
			"trail":draw_circle(at,r*(1-t),Color(c,c.a*.25))
			"feather":
				draw_colored_polygon(PackedVector2Array([at-d*r,at+Vector2(-d.y,d.x)*r*.2,at+d*r,at-Vector2(-d.y,d.x)*r*.2]),c)
	for a in sparks:draw_rect(Rect2(a.at,Vector2(2,2)),Color(a.c,clampf(a.life*4,0,1)))
	var font=ThemeDB.fallback_font
	for n in numbers:
		var c: Color=n.c;c.a=minf(1,n.life*3)
		draw_string(font,n.at+Vector2(1,1),n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17 if n.big else 12,Color(0,0,0,c.a))
		draw_string(font,n.at,n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17 if n.big else 12,c)
