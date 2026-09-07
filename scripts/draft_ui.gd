extends CanvasLayer
## 三选一升级弹层（树暂停期仍运行：process_mode ALWAYS）

signal card_picked(id: String)

var picks: Array = []
var auto_timer := -1.0
var panels: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false

func open(p: Array) -> void:
	picks = p
	visible = true
	auto_timer = 0.5
	for c in get_children():
		c.queue_free()
	panels.clear()
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title := Label.new()
	title.text = "· 修 为 精 进 · 择 一 而 取 ·"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("f6c660"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(240, 42)
	add_child(title)
	for i in p.size():
		var u: Dictionary = p[i]
		var panel := Panel.new()
		panel.position = Vector2(92 + i * 160, 120)
		panel.size = Vector2(140, 150)
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		var tone := Color(u["tone"])
		panel.add_theme_stylebox_override("panel", _mk_style(tone))
		add_child(panel)
		var icon := Label.new()
		icon.text = u["icon"]
		icon.add_theme_font_size_override("font_size", 34)
		icon.add_theme_color_override("font_color", tone)
		icon.position = Vector2(56, 10)
		panel.add_child(icon)
		var name_l := Label.new()
		name_l.text = "%s %s" % [u["name"], "·" if not u.has("hero") else String(u["hero"])]
		name_l.add_theme_font_size_override("font_size", 10)
		name_l.add_theme_color_override("font_color", Color("e8ddc8"))
		name_l.position = Vector2(10, 58)
		name_l.size = Vector2(120, 14)
		panel.add_child(name_l)
		var desc := Label.new()
		desc.text = u["desc"]
		desc.add_theme_font_size_override("font_size", 9)
		desc.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		desc.position = Vector2(10, 76)
		desc.size = Vector2(122, 50)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(desc)
		var key_l := Label.new()
		key_l.text = "[%d] 选择" % (i + 1)
		key_l.add_theme_font_size_override("font_size", 9)
		key_l.add_theme_color_override("font_color", tone)
		key_l.position = Vector2(44, 128)
		panel.add_child(key_l)
		panel.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				_pick(i))
		panels.append(panel)

func _mk_style(tone: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.06, 0.97)
	sb.border_color = tone
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	return sb

func _process(delta: float) -> void:
	if not visible or auto_timer < 0.0:
		return
	auto_timer -= delta
	if auto_timer <= 0.0:
		_pick(0)  # 冒烟/挂机：取第一张（结构保底由 Cards.roll 保证）

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_3:
			idx = event.physical_keycode - KEY_1
		elif event.physical_keycode >= KEY_KP_1 and event.physical_keycode <= KEY_KP_3:
			idx = event.physical_keycode - KEY_KP_1
		if idx >= 0 and idx < picks.size():
			_pick(idx)

func _pick(i: int) -> void:
	if picks.is_empty() or i >= picks.size():
		return
	var id: String = picks[i]["id"]
	picks = []
	visible = false
	auto_timer = -1.0
	card_picked.emit(id)
