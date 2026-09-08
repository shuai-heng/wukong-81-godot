class_name JourneyHUD
extends CanvasLayer

var game
var canvas: Control
var overlay: Control
var objective: Label
var font: Font
var toast_label: Label
var toast_left=0.0
var menu_kind=""
var picks=[]

func _ready() -> void:
	layer=50
	font=ThemeDB.fallback_font
	canvas=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_hud)
	objective=Label.new();objective.position=Vector2(675,52);objective.size=Vector2(258,65);objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_font_size_override("font_size",14);objective.add_theme_color_override("font_color",Color("c9d2c5"));canvas.add_child(objective)
	toast_label=Label.new();toast_label.position=Vector2(230,404);toast_label.size=Vector2(500,34);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size",15);toast_label.add_theme_color_override("font_color",Color("f2d89c"));canvas.add_child(toast_label)

func tick(dt: float) -> void:
	toast_left=maxf(0,toast_left-dt)
	toast_label.visible=toast_left>0 and game.mode=="battle"
	objective.visible=game.mode=="battle"
	if objective.visible:objective.text=game.objective_text()
	canvas.queue_redraw()

func toast(text: String) -> void:
	toast_label.text=text;toast_left=3.5

func _text(at: Vector2,text: String,size: int=14,c: Color=Color("e4e4ce")) -> void:
	canvas.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,c)

func _panel(rect: Rect2,accent: Color=Color("56635c")) -> void:
	canvas.draw_rect(rect,Color("121f2a"))
	canvas.draw_rect(rect.grow(-2),Color("192a33"))
	canvas.draw_rect(rect,accent,false,1)
	for p in [rect.position,rect.position+Vector2(rect.size.x-8,0),rect.end-Vector2(8,3),rect.position+Vector2(0,rect.size.y-3)]:canvas.draw_rect(Rect2(p,Vector2(8,3)),Color("bda773"))

func _bar(at: Vector2,size: Vector2,value: float,c: Color) -> void:
	canvas.draw_rect(Rect2(at,size),Color("0f1a24"));canvas.draw_rect(Rect2(at,Vector2(size.x*clampf(value,0,1),size.y)),c)
	canvas.draw_line(at,at+Vector2(size.x,0),Color(1,1,1,.13),1)

func _draw_hud() -> void:
	if game.player==null:return
	var p=game.player
	var color=JourneyContent.color(p.hero)
	if game.mode=="battle":
		_panel(Rect2(20,18,247,90))
		canvas.draw_texture_rect_region(load("res://assets/pixel/"+p.hero+".png"),Rect2(27,23,58,58),Rect2(0,0,64,64))
		_text(Vector2(89,40),JourneyContent.HEROES[p.hero].name,19,color)
		_text(Vector2(196,39),"Lv."+str(p.level),13,Color("98afa9"))
		_bar(Vector2(90,50),Vector2(159,9),p.hp/p.max_hp,Color("cb6d6b"))
		_text(Vector2(90,76),str(int(p.hp))+" / "+str(int(p.max_hp))+"  气血",12,Color("bfcac0"))
		_bar(Vector2(35,91),Vector2(213,3),float(p.xp)/p.xp_next,Color("82c5b3"))
		_panel(Rect2(660,18,280,116))
		_text(Vector2(675,41),game.chapter.name+"  ·  "+str(game.phase+1)+"/"+str(game.chapter.objectives.size()),16,Color("f0d29c"))
		_bar(Vector2(675,120),Vector2(248,3),game.objective_progress,Color("dab97c"))
		_text(Vector2(343,30),"西 行 录  /  "+str(int(game.elapsed/60)).pad_zeros(2)+":"+str(int(game.elapsed)%60).pad_zeros(2),13,Color("b7c1b1"))
		if game.boss!=null and is_instance_valid(game.boss) and not game.boss.dead:
			var b=game.boss
			_text(Vector2(337,58),game.chapter.boss+" · "+("力竭" if b.tame_ready else "第"+str(b.phase)+"相"),16,Color("edbc9b"))
			_bar(Vector2(305,69),Vector2(335,7),b.hp/b.max_hp,Color("b96b70"))
			for f in [.33,.66]:canvas.draw_line(Vector2(305+335*f,68),Vector2(305+335*f,77),Color("18222b"),2)
			if b.tame_ready:_text(Vector2(347,97),"靠近后按 F · 完成收服",14,Color("e8d897"))
		if p.combo>1:
			_text(Vector2(28,141),str(p.combo)+" 连击",22,color)
			_bar(Vector2(29,150),Vector2(78,3),p.combo_left/2.8,color)
		var resource="怒气 "+str(int(p.rage)) if p.hero=="bajie" else ("真龙 "+str(snappedf(p.dragon,.1))+"s" if p.dragon>0 else JourneyContent.HEROES[p.hero].identity)
		_text(Vector2(28,174),resource,12,Color("b9c7bb"))
		# Mini-map shows the actual objective and world bounds.
		_panel(Rect2(22,375,140,100))
		var origin=Vector2(27,380);var scale_map=Vector2(130.0/2400,90.0/1600)
		canvas.draw_line(origin+Vector2(65,0),origin+Vector2(65,90),Color("495a53"),8)
		var target=game.objective_at*scale_map+origin
		canvas.draw_rect(Rect2(target-Vector2(3,3),Vector2(6,6)),Color("ebc984"))
		canvas.draw_circle(p.position*scale_map+origin,3,Color("bce5d9"))
		if game.boss!=null:canvas.draw_circle(game.boss.position*scale_map+origin,3,Color("eb8f81"))
		_text(Vector2(26,493),"M 西行路线   Esc 暂停",11,Color("a3b5ad"))
		# Skill deck with readable cooldown and lock states.
		var keys=["q","e","g","r"]
		for i in 4:
			var x=277+i*116
			_panel(Rect2(x,463,108,57),color.darkened(.5))
			var locked=keys[i]=="g" and not game.has_ability(p.g_ability())
			var cd=float(p.cool[keys[i]])
			if cd>0 or locked:canvas.draw_rect(Rect2(x+2,465,104,53),Color(0,0,0,.35))
			_text(Vector2(x+9,482),keys[i].to_upper(),14,color)
			var name=JourneyContent.HEROES[p.hero][keys[i]] if i<3 else "终结技"
			if keys[i]=="g" and p.g_ability()=="seventyTwo":name="七十二变"
			_text(Vector2(x+9,504),name,12,Color("d0d7c9") if not locked else Color("7c928d"))
			if cd>0:_text(Vector2(x+76,483),str(snappedf(cd,.1)),12,Color("b2c4ba"))
			elif locked:_text(Vector2(x+74,483),"未习",11,Color("a68b72"))
		_bar(Vector2(279,447),Vector2(452,5),p.ultimate/100 if p.form_left>0 else p.form_charge/100,color)
		_text(Vector2(285,440),(JourneyContent.HEROES[p.hero].form+" · "+str(snappedf(p.form_left,.1))+"s · 终结 "+str(int(p.ultimate))+"%") if p.form_left>0 else "连续命中蓄法相  "+str(int(p.form_charge))+"%",12,color)
		_text(Vector2(765,485),"Space 冲刺",13,Color("dfd7b9"));_text(Vector2(765,507),"T 换人 · Tab 队伍",13,Color("dfd7b9"))
		if game.hurt_flash>0:canvas.draw_rect(Rect2(0,0,960,540),Color(.7,.08,.1,game.hurt_flash*.35))
	if game.cinematic_left>0:
		var alpha=minf(1,game.cinematic_left*3)
		canvas.draw_rect(Rect2(0,194,960,82),Color(.04,.08,.13,.78*alpha))
		canvas.draw_line(Vector2(280,194),Vector2(680,194),Color(game.cinematic_color,alpha),1)
		var w=font.get_string_size(game.cinematic_text,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
		_text(Vector2((960-w)/2,247),game.cinematic_text,28,Color(game.cinematic_color,alpha))

func clear_menu() -> void:
	if overlay!=null:overlay.queue_free();overlay=null
	menu_kind=""

func _base(title: String, subtitle: String="") -> VBoxContainer:
	clear_menu()
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(overlay)
	var shade=ColorRect.new();shade.color=Color(.035,.065,.09,.91);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(shade)
	var box=VBoxContainer.new();box.position=Vector2(110,35);box.size=Vector2(740,465);box.add_theme_constant_override("separation",12);overlay.add_child(box)
	label(box,title,29,Color("f2d6a0"))
	if not subtitle.is_empty():label(box,subtitle,14,Color("a9bcb3"))
	return box

func label(parent: Node, text: String, size: int=16, color: Color=Color("d4dbcc")) -> Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(l);return l

func button(parent: Node, text: String, action: Callable, disabled: bool=false) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(0,40);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.disabled=disabled
	b.add_theme_font_size_override("font_size",15)
	var style=StyleBoxFlat.new();style.bg_color=Color("24363f");style.border_color=Color("56665f");style.set_border_width_all(1);style.content_margin_left=14;style.content_margin_right=14
	b.add_theme_stylebox_override("normal",style)
	var hover=style.duplicate();hover.bg_color=Color("3b4c4b");hover.border_color=Color("d7bc84");b.add_theme_stylebox_override("hover",hover);b.add_theme_stylebox_override("focus",hover)
	var press=style.duplicate();press.bg_color=Color("516052");b.add_theme_stylebox_override("pressed",press)
	b.add_theme_color_override("font_color",Color("eee2c2"));b.add_theme_color_override("font_disabled_color",Color("71847f"))
	b.pressed.connect(func():game.sound.play("ui",.6);action.call())
	parent.add_child(b);return b

func title() -> void:
	var box=_base("大 圣 火 线","八十一难  /  像素西行录")
	menu_kind="title"
	label(box,"一人启程，五圣归真。",25,Color("eee5c8"))
	var portraits=HBoxContainer.new();portraits.alignment=BoxContainer.ALIGNMENT_CENTER;box.add_child(portraits)
	for h in JourneyContent.HERO_ORDER:
		var portrait=TextureRect.new();var atlas=AtlasTexture.new();atlas.atlas=load("res://assets/pixel/"+h+".png");atlas.region=Rect2(0,0,64,64);portrait.texture=atlas;portrait.custom_minimum_size=Vector2(64,64);portraits.add_child(portrait)
	label(box,"把每一次出手，炼成齐天的神通。\n唐僧启程 · 四章收徒 · 人物外传 · 西行破劫",16)
	var gap=Control.new();gap.custom_minimum_size.y=15;box.add_child(gap)
	button(box,"继续西行    →",func():game.continue_journey(),game.save.completed.is_empty() and not game.save.has("run"))
	button(box,"踏上取经路",func():confirm_new())
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);box.add_child(row)
	button(row,"操作与修行",func():help_screen())
	button(row,"声音与画面",func():settings())
	button(row,"离开游戏",func():game.get_tree().quit())
	label(box,"WASD / 方向键移动 · 自动普攻 · Q / E 招式 · G 神通 · R 终结\nSpace 冲刺 · F 收服 / 交互 · T 切换已收服人物 · Esc 暂停",13,Color("8fa79e"))

func confirm_new() -> void:
	if game.save.completed.is_empty() and not game.save.has("run"):game.new_journey();return
	var box=_base("重新启程？","当前旅程将由新的唐僧开局替换；最近一次有效存档会保留为备份。")
	button(box,"确认 · 开始新旅程",func():game.new_journey())
	button(box,"返回",func():title())

func pause() -> void:
	var box=_base("暂歇 · 篝火未冷",game.chapter.name+" / 西行仍在继续")
	menu_kind="pause"
	button(box,"继续战斗",func():game.resume())
	button(box,"西行路线与人物外传",func():route())
	button(box,"队伍与神通",func():roster())
	button(box,"声音与画面",func():settings())
	button(box,"保存并返回标题",func():game.return_title())

func _scroll(box: VBoxContainer) -> VBoxContainer:
	var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(740,335);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",8);scroll.add_child(list)
	return list

func route() -> void:
	game.mode="menu"
	var box=_base("西行路线", "已完成 "+str(game.save.completed.size())+" / 36 处山河 · "+str(game.save.events)+" / 81 段西行事件")
	menu_kind="route"
	var list=_scroll(box)
	label(list,"人物外传 · 带回主线的神通",19,Color("d9bf88"))
	for i in JourneyContent.STORIES.size():
		var s=JourneyContent.story(i)
		var unlocked=game.save.unlocked.has(s.hero)
		var done=game.save.stories.has(s.id)
		var reward=JourneyContent.ABILITIES.get(s.reward,{"name":"旧事传承"}).name
		button(list,("✓ " if done else "◇ ")+s.name+"  ·  "+reward+("  [需先收服"+JourneyContent.HEROES[s.hero].name+"]" if not unlocked else ""),func():game.enter_story(i),not unlocked)
	label(list,"正篇 · 从五行山到东土",19,Color("d9bf88"))
	for i in JourneyContent.ROUTE.size():
		var c=JourneyContent.chapter(i)
		var available=i<=game.save.chapter or game.save.completed.has(c.id)
		var missing=not c.gate.is_empty() and not game.has_ability(c.gate)
		var note=""
		if missing:note="  → 需"+JourneyContent.ABILITIES[c.gate].name+" / "+JourneyContent.ABILITIES[c.gate].source
		button(list,("✓ " if game.save.completed.has(c.id) else str(i+1).pad_zeros(2)+"  ")+c.name+note,func():game.enter_chapter(i),not available or missing)
	button(box,"返回",func():game.resume() if game.player!=null and game.chapter.size()>0 else title())

func roster() -> void:
	game.mode="menu"
	var box=_base("取经队伍","人物加入只获得基础招式，完整神通在人物外传中习得。")
	menu_kind="roster"
	var list=_scroll(box)
	for h in JourneyContent.HERO_ORDER:
		var data=JourneyContent.HEROES[h]
		var unlocked=game.save.unlocked.has(h)
		var have=game.has_ability(data.ability)
		var row=HBoxContainer.new();list.add_child(row)
		var icon=TextureRect.new();var at=AtlasTexture.new();at.atlas=load("res://assets/pixel/"+h+".png");at.region=Rect2(0,0,64,64);icon.texture=at;icon.custom_minimum_size=Vector2(64,64);row.add_child(icon)
		var col=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(col)
		button(col,data.name+" · "+data.identity+("  出战" if unlocked else "  未收服"),func():game.select_hero(h);game.resume(),not unlocked)
		label(col,("已习得 " if have else "待习得 ")+JourneyContent.ABILITIES[data.ability].name+" · "+JourneyContent.ABILITIES[data.ability].source,12)
	button(box,"返回",func():game.resume())

func settings() -> void:
	var prior=game.mode
	var box=_base("声音与画面","音效、音乐和震屏可独立调整。")
	menu_kind="settings"
	for key in ["sound","music","shake"]:
		label(box,{"sound":"打击与环境音效","music":"旅途音乐","shake":"镜头震动"}[key],16)
		var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=float(game.save.settings.get(key,.7));slider.custom_minimum_size.y=24;box.add_child(slider)
		slider.value_changed.connect(func(v):game.save.settings[key]=v;game.sound.settings(game.save.settings))
	var full=CheckButton.new();full.text="全屏显示";full.button_pressed=bool(game.save.settings.get("fullscreen",false));box.add_child(full)
	full.toggled.connect(func(on):game.save.settings.fullscreen=on;DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	var easy=CheckButton.new();easy.text="旅途模式 · 承伤降低 35%（不跳过关卡机制）";easy.button_pressed=float(game.save.settings.get("difficulty",1))<1;box.add_child(easy)
	easy.toggled.connect(func(on):game.save.settings.difficulty=.65 if on else 1.0)
	button(box,"保存并返回",func():game.persist();title() if prior=="title" else pause())

func help_screen() -> void:
	var box=_base("修行须知","主动走位与连续有效命中，才有法相与终结。")
	menu_kind="help"
	label(box,"WASD / 方向键：移动。普攻自动寻找近处妖怪。\nQ / E：专属招式；鼠标右键按住可指定出手方向。\nSpace：冲刺，有短暂无敌窗口，空冲不会白给终结资源。\nG：外传神通；入口会显示尚缺的神通与获取地点。\nR：法相中积满灵力，释放人物专属终结技。\nT：循环切换已收服人物；Tab：打开队伍。\nF：靠近力竭 Boss 收服、解除最后封印。\nM：打开西行路线和外传；Esc：暂停。",16)
	label(box,"每段只有一个当前目标：跟随地图上的金色标记，在目标周围持续战斗。\n红色预警圈即将落下攻击。Boss 三阶段不能靠大招跳过。\n升级三选一用鼠标或 1 / 2 / 3 选择。死亡可重试当前章，已收服人物与神通保留。",14,Color("b2c4b8"))
	button(box,"明白了",func():title() if game.mode=="title" else pause())

func upgrades(cards: Array) -> void:
	picks=cards
	var box=_base("灵光一现 · 选择修行","本次旅程的构筑 · 数字 1 / 2 / 3 或点击选择")
	menu_kind="upgrade"
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",16);box.add_child(row)
	for i in cards.size():
		var c=cards[i]
		var col=VBoxContainer.new();col.custom_minimum_size=Vector2(230,260);col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(col)
		label(col,"0"+str(i+1),36,Color(c.tone))
		button(col,c.name,func():pick(i))
		label(col,c.desc,16)
		label(col,"当前 "+str(game.player.upgrade(c.id))+" / "+str(c.maxLevel),12,Color("8fa99e"))

func pick(i: int) -> void:
	if menu_kind!="upgrade" or i>=picks.size():return
	game.player.add_card(picks[i].id);game.pending_upgrades=maxi(0,game.pending_upgrades-1);game.resume()

func results(won: bool, ending: bool=false) -> void:
	var box=_base("五圣成真 · 功德圆满" if ending else ("此难已渡" if won else "暂别此难，重整行装"),game.chapter.name)
	menu_kind="results"
	label(box,("从孤身的唐僧，到同行的伙伴。\n三十六处山河、八十一段西行，取回的不只是经卷。" if ending else (game.result_text if won else "本章修行未竟。已收服的人物与习得的神通仍在。")),20)
	label(box,"击破妖怪 "+str(game.player.kills)+"  ·  修行等级 "+str(game.player.level),15)
	if won:
		button(box,"西行路线 · 继续前行",func():route())
		button(box,"整装出发",func():game.next_chapter(),ending)
	else:button(box,"重试本章",func():game.retry())
	button(box,"队伍与外传",func():route())
	button(box,"保存并返回标题",func():game.return_title())
