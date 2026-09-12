class_name ArtBackdrop
## G15 画廊/冒烟共用：透明检查底 + 中文字体探测（只读系统字体，不改任何美术资产）

static func checker_texture(cell := 16) -> ImageTexture:
	var w := cell * 8
	var h := cell * 8
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var dark := (int(float(x) / cell) + int(float(y) / cell)) % 2 == 0
			img.set_pixel(x, y, Color(0.14, 0.15, 0.18) if dark else Color(0.21, 0.23, 0.27))
	return ImageTexture.create_from_image(img)

static func cjk_font() -> FontFile:
	for p in ["C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/simhei.ttf", "C:/Windows/Fonts/simsun.ttc"]:
		if FileAccess.file_exists(p):
			var f := FontFile.new()
			if f.load_dynamic_font(p) == OK:
				return f
	return null
