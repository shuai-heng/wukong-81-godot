class_name Save
## 存档：user://w81_save.json（章节/解锁英雄/卡牌/最佳记录/已击败 Boss）

const PATH := "user://w81_save.json"

static func load_save() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	return d if d is Dictionary else {}

static func write(data: Dictionary) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true

static func make(chapter: String, unlocked: Array, cards: Dictionary, best: Dictionary, bosses: Array) -> Dictionary:
	return {
		"version": 1,
		"chapter": chapter,
		"unlocked": unlocked,
		"cards": cards,
		"best": {"kills": best.get("kills", 0), "level": best.get("level", 1), "survived": best.get("survived", 0)},
		"bosses_defeated": bosses,
	}

## 往返自检（对齐 web 版 S-001 存档矩阵教训：写入→读取必须逐字段相等）
static func roundtrip_check() -> Dictionary:
	var probe := make("gao", ["wukong"], {"dmg": 3, "w_pose": 1}, {"kills": 42, "level": 7, "survived": 91.5}, ["wuxing_stone_ape"])
	var old := load_save()      # 保留原档，测完还原
	write(probe)
	var back := load_save()
	var mismatch := []
	for k in probe.keys():
		# JSON 回读把整数变 float：按数值规范化比较，避免把类型差异误判为丢数据
		if not back.has(k) or str(_norm(back[k])) != str(_norm(probe[k])):
			mismatch.append(k)
	if old.is_empty():
		var da := DirAccess.open("user://")
		if da:
			da.remove("w81_save.json")
	else:
		write(old)
	return {"ok": mismatch.is_empty(), "mismatch": mismatch}

## 数值规范化：int/float 统一为 float，字典/数组递归（JSON 往返比较用）
static func _norm(v):
	var t := typeof(v)
	if t == TYPE_INT or t == TYPE_FLOAT:
		return float(v)
	if t == TYPE_DICTIONARY:
		var d := {}
		for k in v.keys():
			d[str(k)] = _norm(v[k])
		return d
	if t == TYPE_ARRAY:
		var a := []
		for e in v:
			a.append(_norm(e))
		return a
	return v
