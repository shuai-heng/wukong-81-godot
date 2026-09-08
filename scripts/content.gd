class_name JourneyContent
extends RefCounted

const HERO_ORDER = ["tang", "wukong", "whiteDragon", "bajie", "shaWujing", "nezha", "erlang"]
const HEROES = {
	"tang": {"name":"唐三藏", "title":"一念渡苍生", "color":"f3ce88", "hp":150.0, "speed":158.0, "damage":19.0, "q":"九环净世", "e":"锦襕护体", "g":"度厄真言", "form":"佛光金身", "ult":"大乘梵音 · 万邪寂灭", "identity":"净化连锁 · 护体反击", "ability":"mercy"},
	"wukong": {"name":"孙悟空", "title":"一棒定乾坤", "color":"ffd16e", "hp":125.0, "speed":183.0, "damage":28.0, "q":"乾坤一棒", "e":"定海破式", "g":"火眼 · 七十二变", "form":"齐天法相", "ult":"如意千钧 · 大闹天宫", "identity":"三棒破甲 · 毫毛分身", "ability":"fieryEyes"},
	"whiteDragon": {"name":"小白龙", "title":"龙吟破沧浪", "color":"8ee9ec", "hp":115.0, "speed":203.0, "damage":24.0, "q":"龙牙穿浪", "e":"引雷龙痕", "g":"真龙化形", "form":"玉龙腾渊", "ult":"四海归一 · 万雷入渊", "identity":"穿妖刻痕 · 三层雷爆", "ability":"trueDragon"},
	"bajie": {"name":"猪八戒", "title":"九齿镇天河", "color":"f4a879", "hp":195.0, "speed":145.0, "damage":33.0, "q":"九齿裂地", "e":"倒卷天河", "g":"天蓬战阵", "form":"天蓬法相", "ult":"天河倒悬 · 镇岳九击", "identity":"承伤积怒 · 聚怪重耙", "ability":"heavenRiver"},
	"shaWujing": {"name":"沙悟净", "title":"一杖锁流沙", "color":"91d4b8", "hp":160.0, "speed":165.0, "damage":26.0, "q":"宝杖去返", "e":"流沙定域", "g":"卷帘锁河", "form":"卷帘法相", "ult":"九骷归位 · 流沙葬海", "identity":"去返切割 · 水域控场", "ability":"fullWater"},
	"nezha": {"name":"哪吒", "title":"红莲踏风火", "color":"ff907b", "hp":115.0, "speed":197.0, "damage":27.0, "q":"火尖三叠", "e":"混天绫 · 风火轮", "g":"乾坤圈", "form":"三头六臂", "ult":"灵珠降世 · 万兵诛邪", "identity":"灼烧连刺 · 火轮机动", "ability":"lotus"},
	"erlang": {"name":"杨戬", "title":"天眼照山河", "color":"b1c7ff", "hp":140.0, "speed":178.0, "damage":30.0, "q":"三尖断岳", "e":"天眼照彻", "g":"哮天逐魂", "form":"显圣真君", "ult":"灌江猎神 · 梅山诛邪", "identity":"弱点破甲 · 灵犬追猎", "ability":"thirdEye"},
}
const ABILITIES = {
	"mercy": {"name":"度厄真言", "hero":"tang", "source":"五行山 · 解封", "use":"净化妖气，解除封印，为队伍回复"},
	"seventyTwo": {"name":"七十二变", "hero":"wukong", "source":"方寸山 · 变化试炼", "use":"变化潜入，破除禁制，召出毫毛分身"},
	"fieryEyes": {"name":"火眼金睛", "hero":"wukong", "source":"八卦炉 · 炼心", "use":"驱散迷雾，识破伪装，揭露真假身"},
	"trueDragon": {"name":"真龙化形", "hero":"whiteDragon", "source":"龙族旧事", "use":"化龙穿流，破水障，救师与龙痕引雷"},
	"heavenRiver": {"name":"天河战法", "hero":"bajie", "source":"天蓬旧事", "use":"架起天河护阵，破除风障和荆棘"},
	"fullWater": {"name":"完整水域", "hero":"shaWujing", "source":"卷帘旧事", "use":"稳住激流，镇压流沙与水域妖阵"},
	"lotus": {"name":"红莲神通", "hero":"nezha", "source":"哪吒 · 莲花化身", "use":"火轮开路，克制火域，以乾坤圈破甲"},
	"thirdEye": {"name":"天眼照彻", "hero":"erlang", "source":"杨戬 · 劈桃山", "use":"看见弱点、锁定真身，以哮天犬追猎"},
}
const THEMES = {
	"mountain": ["182b2e","213b3a","355149","52635a","c6ba82"],
	"river": ["132b3c","1e3949","2e5260","496a72","8dc6c5"],
	"village": ["282a2b","3b3c32","525144","77715a","d1b078"],
	"sand": ["342c32","494038","655544","8c7253","e4bc7d"],
	"temple": ["202d32","303c40","4c5151","68645b","d9c994"],
	"bone": ["252632","353644","4c4755","716977","c7b9ac"],
	"forest": ["172b2a","243c33","355347","57725a","9dc095"],
	"fire": ["28242e","3b3035","533d3c","865041","ed9867"],
	"snow": ["202e3e","354958","54707c","7e9b9f","c9e1d6"],
	"palace": ["242a3e","353d51","4c5468","757883","d5ba7e"],
	"poison": ["222d31","333d39","4c5547","737157","bfc28a"],
	"heaven": ["29364d","404c60","606f7b","9eaaa7","f6dc99"],
	"underworld": ["202330","2d3041","414557","646579","b299b2"],
}

# Each chapter owns authored narrative objectives, environment and a Boss rule.
# The 36 places form 81 playable event sections. This is a game adaptation of
# the pilgrimage, not a claim to reproduce the novel's retrospective ordeal list.
const ROUTE = [
	["wuxing","五行山","山下五百年，一念揭金封","mountain","山门妖将","ape","slam","wukong","","tang","seal",["清除山脚妖潮，靠近佛印镇住妖气","守住主封条，让山下悟空助你破阵","破妖阵，揭佛印，迎悟空归队"]],
	["eagle","鹰愁涧","白马失踪，涧底龙吟","river","小白龙 · 敖烈","whiteDragon","dragon","whiteDragon","","wukong","water",["沿石桥击退水妖，寻回白马踪迹","抵住三道龙息，逼出涧底真龙","龙痕交错，力竭后按 F 收服"]],
	["gao","高老庄","月照云栈，九齿惊雷","village","猪刚鬣","bajie","rage","bajie","","whiteDragon","harvest",["护住庄院粮仓，清扫入夜妖群","避开耙印，打断猪刚鬣的蓄怒","化解天蓬重击，力竭后按 F 收服"]],
	["liusha","流沙河","九骷沉浮，卷帘归心","sand","卷帘大将","shaWujing","return","shaWujing","","bajie","water",["清扫流沙河岸，守住渡口","避开回旋宝杖，镇住九骷妖阵","破流沙领域，力竭后按 F 收服"]],
	["huangfeng","黄风岭","三昧神风里，谁为你挡风","sand","黄风大圣","yellow","wind","","fieryEyes","wukong","wind",["用悟空 G 火眼金睛辨认迷雾妖阵","神风伤眼：换八戒在风眼内护住队伍","击破风势，趁妖王喘息重击"]],
	["wuzhuang","五庄观","树倒心未倒，甘霖换新枝","temple","地脉镇元阵","monk","roots","","","tang","cleanse",["清除地脉妖气，守住人参果树根","唐僧 Q 净化树根，迎回三处生机","破阵不伤树，甘霖归根"]],
	["baigu","白虎岭","一眼识妖，三变皆为骨","bone","白骨夫人","bone","mirror","","fieryEyes","wukong","reveal",["火眼照路，击破伪装的白骨妖群","清扫三处幻身，守住唐僧的去路","按 G 揭出白骨真身后击败她"]],
	["baoxiang","宝象国","师父落难，白龙独行","palace","黄袍怪","wolf","charge","","trueDragon","whiteDragon","rescue",["化龙突破宫门水障，逼退黄袍妖兵","小白龙独守救援点，化形带回师父","破奎星妖阵，为师徒打开归路"]],
	["pingding","平顶山","金角银角，一声莫应","mountain","金角与银角","gold","vessel","","seventyTwo","wukong","vessel",["变化破禁，清扫莲花洞外妖兵","躲开葫芦吸力，夺回三处法器灵气","躲过收摄后反击，破金银双阵"]],
	["wuji","乌鸡国","井中冤魂，王城有真假","palace","青毛狮子","lion","mirror","","fieryEyes","wukong","reveal",["清除古井怨气，火眼识假王","护住还魂灯，破狮王真身"]],
	["huoyun","火云洞","三昧真火，莫逞一时强","fire","红孩儿","nezha","fire","","","tang","fire",["守住净水法坛，避开三昧火柱","火息方能破防，借净水收伏圣婴"]],
	["heishui","黑水河","黑水翻涌，鼍鼓催舟","river","鼍龙","dragon","dragon","","fullWater","shaWujing","water",["悟净 G 镇住黑水，护渡船过妖潮","躲开水面突袭，打断鼍龙蓄潮"]],
	["chesi","车迟国","求雨斗法，雷起见真形","temple","虎鹿羊三仙","tiger","storm","","","tang","rain",["守三清祭台，妖潮中引动雨符","避雷斗法，逐一破三仙法阵"]],
	["tongtian","通天河","冰下鱼影，风雪护童","snow","灵感大王","water","ice","","fullWater","shaWujing","escort",["护住河岸孩童，悟净镇流破冰","避开寒潮回击，待鱼王现身收伏"]],
	["jindou","金兜山","金刚琢起，兵刃暂藏","mountain","独角兕大王","ox","vessel","","","wukong","vessel",["守住求援香火，金刚琢吸摄时躲避","待金刚琢回收，破兕王的防御窗口"]],
	["nver","女儿国","子母河畔，毒尾藏春","village","蝎子精","scorpion","poison","","","tang","cleanse",["唐僧净化河畔毒雾，取回落胎泉水","避开倒马毒桩，护住净水破妖毒"]],
	["sixear","真假美猴王","同一根铁棒，两道影子","bone","六耳猕猴","ape","mirror","","fieryEyes","wukong","reveal",["火眼辨假身，别让幻影击碎信念灯","照出本体后破式，辨清真假猴王"]],
	["flaming","火焰山","三借芭蕉，一扇息火","fire","牛魔王","ox","rage","","lotus","nezha","fire",["哪吒以红莲神通穿火，守住芭蕉扇阵","闪开牛王重冲，火息时击破巨甲"]],
	["bibo","碧波潭","九首遮月，天眼照真","river","九头虫","dragon","hydra","","thirdEye","erlang","weakpoint",["杨戬 G 锁定妖气，天眼击破三处假首","看清亮起的真弱点再重击九头虫"]],
	["jingji","荆棘岭","荆棘封路，九齿开山","forest","木仙妖阵","mushroom","roots","","heavenRiver","bajie","thorns",["八戒 G 破荆棘，在妖潮中打通古道","避开根刺，连耙击破木仙阵心"]],
	["xiaoleiyin","小雷音寺","金铙不是佛，布袋亦藏妖","temple","黄眉老怪","yellow","vessel","","","wukong","prison",["击退伪佛妖兵，守住弥勒求援香","躲避人种袋收摄，脱困后破黄眉金身"]],
	["qijue","七绝山","稀柿堵古道，长蟒隐林间","poison","红鳞巨蟒","snake","poison","","heavenRiver","bajie","thorns",["天蓬耙阵清障，守住古道的通风口","避蟒尾与毒池，正面重击破红鳞"]],
	["zhuzi","朱紫国","金铃三响，紫烟遮王城","palace","赛太岁","lion","storm","","","wukong","smoke",["妖潮中守住药炉，躲开三色金铃烟","趁金铃收势破甲，为金圣宫开路"]],
	["pansi","盘丝洞","蛛网织月，百眼夺光","poison","百眼魔君","centipede","web","","fieryEyes","wukong","web",["火眼辨出主蛛网，击碎丝结开路","避开百眼金光，破毒阵后的真身"]],
	["shituo","狮驼岭","三魔吞云，一路向生","bone","狮驼三魔","roc","triple","","thirdEye","erlang","rescue",["杨戬照破暗影，守住狮驼城救援旗","狮吼、象踏、鹏掠轮替，抓住落地破绽"]],
	["biqiu","比丘国","千笼童心，不作药引","village","白鹿国丈","deer","roots","","","tang","rescue",["唐僧在妖潮中守护童笼，净化血符","避鹿角突袭，破妖道的长生阵"]],
	["wudi","无底洞","红烛尽处，地涌迷踪","underworld","地涌夫人","rat","burrow","","seventyTwo","wukong","rescue",["变化潜入洞底，击退妖群保护救援灯","识别地裂预兆，在鼠妖现身时反击"]],
	["miefa","灭法国","不以杀止杀，巧变换人心","palace","迷心妖阵","soldier","mirror","","seventyTwo","wukong","stealth",["七十二变化解禁制，守住不杀生法阵","破除迷心幻影，护城民安全离场"]],
	["yinwu","隐雾山","人头是幻，妖雾是真","mountain","南山大王","tiger","mirror","","fieryEyes","wukong","reveal",["火眼辨假首，妖潮中守住信念灯","照散烟幕，击破折岳洞主的幻身"]],
	["fengxian","凤仙郡","一念向善，久旱逢甘霖","sand","旱魇妖阵","fire","storm","","","tang","rain",["守护求雨祭台，净化三道旱魇","避开燥雷，守到甘霖驱散旱魇"]],
	["yuhua","玉华州","神兵失落，九灵啸山河","village","九灵元圣","lion","triple","","thirdEye","erlang","relic",["杨戬天眼寻回神兵灵光，守住授艺台","躲九道狮吼，九灵收势时协力破阵"]],
	["jinping","金平府","灯火藏犀，三妖盗香油","snow","三犀大王","rhino","charge","","fullWater","shaWujing","storm",["水域神通守住灯阵，击退偷油妖兵","三犀轮番冲阵，趁撞空打破寒甲"]],
	["tianzhu","天竺国","月下玉兔，公主有真假","palace","玉兔精","rabbit","moon","","fieryEyes","wukong","reveal",["火眼照见真公主，护住宫门月灯","避玉杵连击，逐月追踪玉兔真身"]],
	["tongtai","铜台府","善人蒙冤，一灯引魂归","underworld","冤魂妖阵","bone","burrow","","","tang","escort",["唐僧护送还魂灯，在怨灵潮中引魂","净化地府阴阵，让寇员外还魂"]],
	["leiyin","凌云渡","无底之舟，彼岸有真经","heaven","执念化身","monk","storm","","","tang","escort",["护住经卷灵光，渡过凌云劫浪","放下执念，守住雷音最后的试炼"]],
	["return","通天河 · 归途","经卷有缺，功德有成","river","归途劫浪","water","hydra","","fullWater","shaWujing","escort",["悟净镇浪，全队护住落水经卷","抵住最后妖潮，晒经归东土 · 五圣成真"]],
]
const STORIES = [
	["fangcun","方寸山 · 变化试炼","wukong","seventyTwo","forest","须菩提木人阵","monk","mirror","stealth","A · 原著前传：第二回","方寸一念，万物皆可变化。击破木人阵，学会七十二变。"],
	["dragonPalace","东海龙宫 · 定海神针","wukong","staffMemory","river","龙宫试武阵","water","dragon","relic","A · 原著前传：第三回","定海神针认主，金箍棒从此随心。"],
	["underworld","幽冥地府 · 勾销生死","wukong","deathMemory","underworld","生死簿守卫","bone","burrow","relic","A · 原著前传：第三回","守住生死簿，破去阴兵封锁。"],
	["heaven","大闹天宫 · 神将初会","wukong","heavenMemory","heaven","哪吒与杨戬","nezha","triple","storm","A · 原著前传：第四至七回","见识风火轮与天眼，赢得两位神将的认可。"],
	["bagua","八卦炉 · 炼心","wukong","fieryEyes","fire","八卦炉火灵","fire","fire","smoke","A · 原著前传：第七回","浓烟遮眼，火中炼心。撑过炼化，火眼金睛照破妖氛。"],
	["dragonStory","龙族旧事 · 玉龙归心","whiteDragon","trueDragon","river","龙宫水阵","dragon","dragon","water","A · 原著背景改编：第十五回","从白马到真龙，守护取经人的誓言不变。"],
	["tianpeng","天蓬旧事 · 守天河","bajie","heavenRiver","heaven","天河战阵","soldier","rage","escort","B · 人物背景扩写","不退半步守天河，以九齿耙阵护住河军旗。"],
	["juanlian","卷帘旧事 · 锁河试炼","shaWujing","fullWater","sand","九骷水阵","water","return","water","B · 人物背景扩写","宝杖定流，九骷归位，卷帘重新担起守护。"],
	["nezhaStory","哪吒 · 莲花化身","nezha","lotus","fire","莲台试炼","dragon","fire","fire","B · 古典神话人物外传","红莲重生，三头六臂。收回混天绫、乾坤圈与完整风火轮。"],
	["erlangStory","杨戬 · 劈桃山","erlang","thirdEye","mountain","桃山禁制","gold","storm","weakpoint","B · 古典神话人物外传","天眼看破禁制，三尖两刃开山，哮天犬逐魂归来。"],
]

static func chapter(index: int) -> Dictionary:
	var r = ROUTE[clampi(index,0,ROUTE.size()-1)]
	return {"id":r[0],"name":r[1],"subtitle":r[2],"theme":r[3],"boss":r[4],"sprite":r[5],"pattern":r[6],"unlock":r[7],"gate":r[8],"hero":r[9],"mechanic":r[10],"objectives":r[11],"index":index,"story":false}

static func story(index: int) -> Dictionary:
	var r=STORIES[index]
	return {"id":r[0],"name":r[1],"subtitle":r[10],"theme":r[4],"boss":r[5],"sprite":r[6],"pattern":r[7],"unlock":"", "gate":"", "hero":r[2],"mechanic":r[8],"reward":r[3],"source":r[9],"objectives":["清扫妖潮，在试炼阵内磨炼本领", "看清招式，完成最后试炼"],"index":index,"story":true}

static func color(hero: String) -> Color:
	return Color(HEROES[hero].color)

static var frame_cache={}
static func frames(kind: String) -> SpriteFrames:
	if frame_cache.has(kind):return frame_cache[kind]
	var sf=SpriteFrames.new()
	var path="res://assets/pixel/"+kind+".png"
	if not ResourceLoader.exists(path): path="res://assets/pixel/wolf.png"
	var texture=load(path)
	var anims=["idle","run","atk","hurt","cast"]
	for row in anims.size():
		var an=anims[row]
		sf.add_animation(an)
		sf.set_animation_speed(an, 10.0 if an=="idle" else (16.0 if an=="run" else 20.0))
		sf.set_animation_loop(an,an in ["idle","run"])
		for col in 8:
			var tex=AtlasTexture.new()
			tex.atlas=texture
			tex.region=Rect2(col*64,row*64,64,64)
			sf.add_frame(an,tex)
	frame_cache[kind]=sf
	return sf
