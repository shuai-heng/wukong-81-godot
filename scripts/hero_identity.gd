class_name HeroIdentity
## M2-R4 · 主角战斗身份证（负责人要求：一人一技能主色 + 独立战斗定位，禁止同模板换色）
## primary/secondary 主色贯穿 平A/弹道/拖尾/命中闪光/残影/蓄力/地面反馈/强化状态。
## 设计表全文见 F:\Zcode projects\西游\主角战斗身份证.md（含 forbidden_pattern）。

const IDENT := {
	"wukong": {
		"primary": Color("FF8A00"), "secondary": Color("FFD75E"),
		"combat_role": "近中距离高机动武器战士", "attack_range": "近/中",
		"source_anchor": "staff_tip", "trajectory_style": "棍端弧线（横扫/反身/突刺/劈砸）",
		"environment_style": "地裂+碎石+尘土（真实落点）",
	},
	"tang": {
		"primary": Color("F6C85F"), "secondary": Color("FFF7DC"),
		"combat_role": "远程法术/弹幕（施法念咒型）", "attack_range": "远",
		"source_anchor": "staff_tip(九环)/palm", "trajectory_style": "锡杖环弹/梵音环波/念珠弹幕（projectile 脱手）",
		"environment_style": "梵文光纹/经页余辉（法术着点）",
	},
	"whiteDragon": {
		"primary": Color("43D7FF"), "secondary": Color("E8F7FF"),
		"combat_role": "高速机动/中远程", "attack_range": "中/远",
		"source_anchor": "body_center", "trajectory_style": "龙牙突进/雷束（直线穿刺）",
		"environment_style": "龙痕刻印/雷爆",
	},
	"bajie": {
		"primary": Color("C9833D"), "secondary": Color("E8B96B"),
		"combat_role": "重型近战/冲撞/大范围地面压制", "attack_range": "近",
		"source_anchor": "staff_tip(钉耙)", "trajectory_style": "钉耙劈砸/怒吼波（扇形重压）",
		"environment_style": "地面震裂/聚怪涡流",
	},
	"shaWujing": {
		"primary": Color("1B6FE5"), "secondary": Color("9FD9E8"),
		"combat_role": "中距离稳定压制/控场", "attack_range": "中",
		"source_anchor": "staff_tip(宝杖)", "trajectory_style": "宝杖去返（脱手往返弹体）",
		"environment_style": "流沙域（地面减速场）",
	},
	"nezha": {
		"primary": Color("FF3B20"), "secondary": Color("FFC46B"),
		"combat_role": "近中距离突进连击", "attack_range": "近/中",
		"source_anchor": "staff_tip(火尖枪)", "trajectory_style": "枪突刺（直线穿刺+灼烧）",
		"environment_style": "火尘/灼痕",
	},
	"erlang": {
		"primary": Color("4EA1FF"), "secondary": Color("C9A8FF"),
		"combat_role": "中远程穿射/压制", "attack_range": "中/远",
		"source_anchor": "eye(额间)/staff_tip", "trajectory_style": "天眼三束穿射（直线光束）",
		"environment_style": "霜电落点",
	},
}

static func primary(hero: String) -> Color:
	var e: Dictionary = IDENT.get(hero, {})
	return e.get("primary", Color("FFD46B")) if not e.is_empty() else Color("FFD46B")

static func secondary(hero: String) -> Color:
	var e: Dictionary = IDENT.get(hero, {})
	return e.get("secondary", Color.WHITE) if not e.is_empty() else Color.WHITE

static func field(hero: String, key: String) -> String:
	var e: Dictionary = IDENT.get(hero, {})
	return String(e.get(key, ""))
