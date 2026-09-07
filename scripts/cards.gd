class_name Cards
## 三选一卡池（自 web 版 U-001/U-002 忠实移植：分类/结构保底/上限削峰）
## G02 法相系统落地：法相系 8 卡入库；pierce 仍延后（弹道系统未迁移）

const CAT := {
	"dmg": "generic", "atkSpeed": "generic", "range": "generic", "crit": "generic",
	"hp": "survival", "dr": "survival", "lifesteal": "survival", "regen": "survival",
	"orbHeal": "survival", "thorns": "survival",
	"dashCd": "mobility", "moveSpeed": "mobility", "magnet": "mobility",
	"burn": "element", "frost": "element", "thunder": "element",
	"dashDmg": "mutation", "cdr": "mutation", "comboForm": "mutation",
	"killForm": "mutation", "ultGain": "mutation", "formDuration": "mutation",
}

const POOL := [
	{"id": "dmg", "name": "修为精进", "desc": "伤害 +12%", "icon": "修", "tone": "ffca57", "maxLevel": 5},
	{"id": "atkSpeed", "name": "棍法如风", "desc": "攻击间隔 -12%", "icon": "风", "tone": "ffe27a", "maxLevel": 4},
	{"id": "range", "name": "棍势范围", "desc": "攻击范围 +16%", "icon": "围", "tone": "ffd46b", "maxLevel": 4},
	{"id": "crit", "name": "会心一击", "desc": "14% 概率暴击双倍伤害", "icon": "会", "tone": "ffe27a", "maxLevel": 4},
	{"id": "hp", "name": "金刚不坏", "desc": "最大气血 +28 并回满", "icon": "刚", "tone": "ffc9a0", "maxLevel": 5},
	{"id": "dr", "name": "袈裟护体", "desc": "受到伤害 -10%", "icon": "护", "tone": "ffe6a8", "maxLevel": 4},
	{"id": "lifesteal", "name": "梵音回血", "desc": "每次击杀回复 4 气血", "icon": "回", "tone": "a8ffc8", "maxLevel": 4},
	{"id": "regen", "name": "吐纳调息", "desc": "每秒回复 0.6 气血", "icon": "息", "tone": "a8ffc8", "maxLevel": 3},
	{"id": "orbHeal", "name": "饮露回春", "desc": "拾取光点回复 1.2 气血", "icon": "露", "tone": "bfeee0", "maxLevel": 3},
	{"id": "thorns", "name": "刺沙反甲", "desc": "攻击你的妖怪反受 9+ 伤害", "icon": "刺", "tone": "e0b45a", "maxLevel": 3},
	{"id": "dashCd", "name": "疾影身法", "desc": "冲刺冷却 -22%", "icon": "影", "tone": "9ae6ff", "maxLevel": 3},
	{"id": "moveSpeed", "name": "筋斗轻身", "desc": "移动速度 +7%", "icon": "轻", "tone": "bfefff", "maxLevel": 4},
	{"id": "magnet", "name": "引灵诀", "desc": "光点吸取范围 +45%", "icon": "引", "tone": "7ff0e0", "maxLevel": 3},
	{"id": "burn", "name": "业火缠身", "desc": "命中附加燃烧灼烧", "icon": "火", "tone": "ff8a5c", "maxLevel": 3},
	{"id": "frost", "name": "寒冰禁锢", "desc": "命中使敌人减速", "icon": "冰", "tone": "a8e8ff", "maxLevel": 3},
	{"id": "thunder", "name": "雷霆天罚", "desc": "击杀雷击附近敌人", "icon": "雷", "tone": "d8b0ff", "maxLevel": 3},
	{"id": "dashDmg", "name": "踏浪冲撞", "desc": "冲刺路径直接撞伤妖怪", "icon": "撞", "tone": "9ae6ff", "maxLevel": 3},
	{"id": "cdr", "name": "神通回风", "desc": "Q / E 冷却 -12%", "icon": "回", "tone": "ffd8a8", "maxLevel": 3},
	{"id": "comboForm", "name": "连击大师", "desc": "命中积攒法相 +45%", "icon": "连", "tone": "ffd479", "maxLevel": 4},
	{"id": "killForm", "name": "猎杀本能", "desc": "击杀积攒法相 +70%", "icon": "猎", "tone": "ff9e7a", "maxLevel": 4},
	{"id": "ultGain", "name": "终结共鸣", "desc": "法相内终结积攒 +40%", "icon": "终", "tone": "c9a8ff", "maxLevel": 4},
	{"id": "formDuration", "name": "法相长明", "desc": "法相持续 +1.6 秒", "icon": "明", "tone": "c9a8ff", "maxLevel": 3},
]

const HERO_POOL := [
	{"id": "w_arc", "name": "棍影重重", "desc": "自动挥扫范围 +8%、弧度 +0.3", "icon": "影", "tone": "ffca57", "maxLevel": 3, "hero": "孙悟空", "hid": "wukong"},
	{"id": "w_pose", "name": "三棒重击", "desc": "每第三棒为重击：伤害 ×1.9、范围 ×1.35", "icon": "棒", "tone": "ffd45e", "maxLevel": 3, "hero": "孙悟空", "hid": "wukong"},
	{"id": "w_72", "name": "毫毛分身", "desc": "冲刺留下毫毛幻相，自动攻击附近妖怪", "icon": "变", "tone": "fff0a0", "maxLevel": 2, "hero": "孙悟空", "hid": "wukong"},
	{"id": "w_giant", "name": "法天象地", "desc": "法相伤害 +12%/层、身形更威", "icon": "天", "tone": "ffb84d", "maxLevel": 3, "hero": "孙悟空", "hid": "wukong"},
	{"id": "w_clone", "name": "毫毛感应", "desc": "幻相持续更久、攻击更强", "icon": "毫", "tone": "ffe08a", "maxLevel": 2, "hero": "孙悟空", "hid": "wukong"},
	{"id": "t_nova", "name": "净化蔓延", "desc": "Q 净化环范围 +30、伤害 +8/层", "icon": "净", "tone": "fff3c0", "maxLevel": 3, "hero": "唐僧", "hid": "tang"},
	{"id": "t_ring", "name": "九环余音", "desc": "Q 后追加一道外环冲击", "icon": "环", "tone": "ffd46b", "maxLevel": 2, "hero": "唐僧", "hid": "tang"},
	{"id": "t_reflect", "name": "锦襕反噬", "desc": "护体期间反弹 14×层 伤害", "icon": "襕", "tone": "ffe9a8", "maxLevel": 3, "hero": "唐僧", "hid": "tang"},
]

const CAPS := {
	"atkCdMin": 0.62, "dashCdMin": 0.55, "critMax": 0.45, "drMax": 0.55, "dmgPerLevel": 0.12,
}

static func cat_of(u: Dictionary) -> String:
	return "hero" if u.has("hero") else CAT.get(u["id"], "generic")

static func find(id: String) -> Dictionary:
	for u in POOL:
		if u["id"] == id:
			return u
	for u in HERO_POOL:
		if u["id"] == id:
			return u
	return {}

## 结构保底抽取（web pickUpgrades 同构）：≥1 hero + ≥1 mutation，池尽按序降级
static func roll(owned: Dictionary, n: int, rng: RandomNumberGenerator, hero: String = "wukong") -> Array:
	var generic := POOL.filter(func(u): return owned.get(u["id"], 0) < u["maxLevel"])
	var hero_pool := HERO_POOL.filter(func(u): return u["hid"] == hero and owned.get(u["id"], 0) < u["maxLevel"])
	var buckets := {
		"hero": _shuffled(hero_pool, rng),
		"mutation": [], "other": [],
	}
	for u in _shuffled(generic, rng):
		var c := cat_of(u)
		if c == "mutation":
			buckets["mutation"].append(u)
		else:
			buckets["other"].append(u)
	var out: Array = []
	var take := func(b: String):
		if not buckets[b].is_empty():
			out.append(buckets[b].pop_front())
	var order := ["hero", "mutation", "other"] if (not buckets["hero"].is_empty() and (rng.randf() < 0.55 or buckets["mutation"].is_empty())) else ["mutation", "hero", "other"]
	for b in order:
		if out.size() < n:
			take.call(b)
	var rest: Array = buckets["hero"] + buckets["mutation"] + buckets["other"]
	rest = _shuffled(rest, rng)
	for u in rest:
		if out.size() >= n:
			break
		if not out.has(u):
			out.append(u)
	return out.slice(0, n)

static func _shuffled(a: Array, rng: RandomNumberGenerator) -> Array:
	var arr := a.duplicate()
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
	return arr

## 结构自检（对齐 web P10 的 50 抽完整率口径）：200 抽全部满足保底结构
static func structure_check(rng: RandomNumberGenerator) -> Dictionary:
	var fails := []
	for trial in 200:
		var owned := {}
		for draw in 12:
			var picks := roll(owned, 3, rng, "wukong")
			var cats := picks.map(cat_of)
			var has_hero := cats.has("hero")
			var has_mut := cats.has("mutation")
			var hero_avail := HERO_POOL.any(func(u): return owned.get(u["id"], 0) < u["maxLevel"])
			var mut_avail := POOL.any(func(u): return cat_of(u) == "mutation" and owned.get(u["id"], 0) < u["maxLevel"])
			if hero_avail and mut_avail and not (has_hero and has_mut):
				fails.append("%d/%d: %s" % [trial, draw, ",".join(cats)])
			for u in picks:
				owned[u["id"]] = owned.get(u["id"], 0) + 1
	return {"trials": 200, "fails": fails.size(), "detail": "; ".join(fails.slice(0, 3))}

## 英雄基础参数（移植自 web HERO 表）
const HERO_STATS := {
	"wukong": {"name": "孙悟空", "dmg": 34.0, "speed": 130.0, "auto_range": 95.0, "q": "乾坤一棒", "e": "定地重击"},
	"tang": {"name": "唐三藏", "dmg": 26.0, "speed": 118.0, "auto_range": 100.0, "q": "净化梵环", "e": "锦襕袈裟"},
}

static func hero_stat(hero: String, key: String) -> float:
	return float(HERO_STATS.get(hero, HERO_STATS["wukong"]).get(key, 0.0))
