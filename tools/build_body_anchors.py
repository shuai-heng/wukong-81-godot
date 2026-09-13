# -*- coding: utf-8 -*-
"""M2-R4 身体/武器锚点生成器：人工标注（视觉模型网格读数+抽查复核）→ data/v6_body_anchors.json
坐标=姿势图像素(0-256, 原点左上, y向下)；ground/body_center 由剪影程序化计算。
复核记录：sun_wukong/atk_combo/kf09 zoom[36,141] vs 拼图[34,140]；heavy/kf05 zoom[92,30] vs 拼图[92,30]。
"""
import json, os
from PIL import Image

LABELS = {
 "sun_wukong": {
  "atk_combo": {  # 如意棍·三连（棍端探出→横扫一式→反身二式→旋腰蓄力→突刺三式→收棍）
   1:{"staff_tip":[58,110],"staff_tail":[124,146],"hand_r":[110,136]},
   2:{"staff_tip":[58,110],"staff_tail":[126,148],"hand_r":[112,138]},
   3:{"staff_tip":[34,176],"staff_tail":[132,150],"hand_r":[118,142]},
   4:{"staff_tip":[34,176],"staff_tail":[130,148],"hand_r":[116,140]},
   5:{"staff_tip":[176,120],"staff_tail":[92,148],"hand_r":[112,138]},
   6:{"staff_tip":[176,120],"staff_tail":[94,146],"hand_r":[110,138]},
   7:{"staff_tip":[166,64],"staff_tail":[96,146],"hand_r":[108,140]},
   8:{"staff_tip":[166,64],"staff_tail":[100,144],"hand_r":[112,138]},
   9:{"staff_tip":[34,140],"staff_tail":[150,140],"hand_r":[112,142]},
   10:{"staff_tip":[34,140],"staff_tail":[148,142],"hand_r":[110,142]},
   11:{"staff_tip":[34,140],"staff_tail":[146,142],"hand_r":[110,140]},
   12:{"staff_tip":[64,124],"staff_tail":[140,150],"hand_r":[112,138]},
   13:{"staff_tip":[64,124],"staff_tail":[140,150],"hand_r":[112,138]},
   14:{"staff_tip":[64,124],"staff_tail":[140,150],"hand_r":[112,138]},
  },
  "heavy": {  # 定海重棒（压棍蓄力→双手举棒→增重→踏步下砸→地裂冲击→碎石落下→回收）
   1:{"staff_tip":[124,62],"staff_tail":[132,216],"hand_r":[128,180]},
   2:{"staff_tip":[124,60],"staff_tail":[132,218],"hand_r":[128,180]},
   3:{"staff_tip":[110,44],"staff_tail":[142,202],"hand_r":[130,178]},
   4:{"staff_tip":[100,36],"staff_tail":[150,196],"hand_r":[132,176]},
   5:{"staff_tip":[92,30],"staff_tail":[152,190],"hand_r":[136,160]},
   6:{"staff_tip":[128,28],"staff_tail":[154,188],"hand_r":[138,156]},
   7:{"staff_tip":[172,88],"staff_tail":[128,160],"hand_r":[134,148]},
   8:{"staff_tip":[196,140],"staff_tail":[120,150],"hand_r":[128,146]},
   9:{"staff_tip":[206,190],"staff_tail":[124,148],"hand_r":[126,146]},
   10:{"staff_tip":[208,210],"staff_tail":[124,146],"hand_r":[126,146]},
   11:{"staff_tip":[204,214],"staff_tail":[124,146],"hand_r":[126,146]},
   12:{"staff_tip":[204,214],"staff_tail":[124,146],"hand_r":[126,146]},
   13:{"staff_tip":[124,62],"staff_tail":[132,216],"hand_r":[128,180]},
   14:{"staff_tip":[124,62],"staff_tail":[132,216],"hand_r":[128,180]},
  },
  "core_1": {  # 毫毛分身阵（拔毫→吹毫→金光分裂→一化三→三化七→分身围攻→同步棍击→消散）
   1:{"staff_tip":[168,62],"staff_tail":[112,200],"hand_r":[124,178]},
   2:{"staff_tip":[168,62],"staff_tail":[112,200],"hand_r":[124,178]},
   3:{"staff_tip":[170,60],"staff_tail":[114,198],"hand_r":[124,178]},
   4:{"staff_tip":[170,60],"staff_tail":[114,198],"hand_r":[124,178]},
   5:{"staff_tip":[150,70],"staff_tail":[116,196],"hand_r":[124,178]},
   6:{"staff_tip":[148,68],"staff_tail":[116,194],"hand_r":[124,178]},
   7:{"staff_tip":[152,66],"staff_tail":[118,192],"hand_r":[124,178]},
   8:{"staff_tip":[152,66],"staff_tail":[118,192],"hand_r":[124,178]},
   9:{"staff_tip":[150,64],"staff_tail":[120,190],"hand_r":[124,178]},
   10:{"staff_tip":[150,64],"staff_tail":[120,190],"hand_r":[124,178]},
   11:{"staff_tip":[150,64],"staff_tail":[120,190],"hand_r":[124,178]},
   12:{"staff_tip":[150,64],"staff_tail":[120,190],"hand_r":[124,178]},
   13:{"staff_tip":[152,66],"staff_tail":[118,192],"hand_r":[124,178]},
   14:{"staff_tip":[152,66],"staff_tail":[118,192],"hand_r":[124,178]},
   15:{"staff_tip":[152,66],"staff_tail":[118,192],"hand_r":[124,178]},
   16:{"staff_tip":[152,66],"staff_tail":[118,198],"hand_r":[124,178]},
  },
  "dodge": {  # 筋斗闪（压身预备→蹬地→翻身入云→高速位移→落地滑步→回正）
   1:{"staff_tip":[168,100],"body_center":[128,140]},
   2:{"staff_tip":[168,100],"body_center":[128,142]},
   3:{"staff_tip":[150,120],"body_center":[128,148]},
   4:{"staff_tip":[162,84],"body_center":[128,132]},
   5:{"staff_tip":[172,80],"body_center":[128,130]},
   6:{"staff_tip":[180,76],"body_center":[128,128]},
   7:{"staff_tip":[184,72],"body_center":[128,138]},
   8:{"staff_tip":[184,72],"body_center":[128,140]},
   9:{"staff_tip":[176,88],"body_center":[128,142]},
   10:{"staff_tip":[176,92],"body_center":[128,140]},
  },
 },
 "tang_sanzang": {
  "atk_combo": {  # 九环锡杖·震退（竖杖→前扫→九环发亮→杖尾点地→短震波→收杖）
   1:{"staff_tip":[140,56],"staff_tail":[132,200],"palm":[100,140]},
   2:{"staff_tip":[140,56],"staff_tail":[132,200],"palm":[100,140]},
   3:{"staff_tip":[154,68],"staff_tail":[130,198],"palm":[104,138]},
   4:{"staff_tip":[154,68],"staff_tail":[132,198],"palm":[104,138]},
   5:{"staff_tip":[160,74],"staff_tail":[134,196],"palm":[106,136]},
   6:{"staff_tip":[160,74],"staff_tail":[134,196],"palm":[106,136]},
   7:{"staff_tip":[156,78],"staff_tail":[128,192],"palm":[106,136]},
   8:{"staff_tip":[156,78],"staff_tail":[128,192],"palm":[106,136]},
   9:{"staff_tip":[150,72],"staff_tail":[130,194],"palm":[104,138]},
   10:{"staff_tip":[150,72],"staff_tail":[130,194],"palm":[104,138]},
   11:{"staff_tip":[148,70],"staff_tail":[132,198],"palm":[102,140]},
   12:{"staff_tip":[148,70],"staff_tail":[132,198],"palm":[102,140]},
  },
  "core_1": {  # 禅音驱邪（合掌起咒→梵字浮现→音环扩散→妖气被压→第二层禅音→净化白闪→余音→收咒）
   1:{"staff_tip":[140,52],"palm":[124,148]},
   2:{"staff_tip":[140,52],"palm":[124,146]},
   3:{"staff_tip":[142,50],"palm":[126,142]},
   4:{"staff_tip":[142,50],"palm":[126,140]},
   5:{"staff_tip":[144,48],"palm":[128,138]},
   6:{"staff_tip":[144,48],"palm":[128,136]},
   7:{"staff_tip":[146,46],"palm":[128,134]},
   8:{"staff_tip":[146,46],"palm":[128,132]},
   9:{"staff_tip":[148,44],"palm":[128,130]},
   10:{"staff_tip":[148,44],"palm":[128,130]},
   11:{"staff_tip":[148,44],"palm":[128,130]},
   12:{"staff_tip":[148,44],"palm":[128,130]},
   13:{"staff_tip":[148,44],"palm":[128,128]},
   14:{"staff_tip":[148,44],"palm":[128,128]},
   15:{"staff_tip":[148,44],"palm":[128,124]},
   16:{"staff_tip":[148,44],"palm":[128,124]},
  },
  "core_2": {  # 锦襕袈裟（抬袖→袈裟展开→金线成环→护盾闭合→受击光纹→护盾反震→减弱→回收）
   1:{"staff_tip":[138,54],"shield_center":[128,150]},
   2:{"staff_tip":[138,54],"shield_center":[128,150]},
   3:{"staff_tip":[138,54],"shield_center":[128,146]},
   4:{"staff_tip":[140,52],"shield_center":[128,132]},
   5:{"staff_tip":[140,52],"shield_center":[128,126]},
   6:{"staff_tip":[140,52],"shield_center":[128,124]},
   7:{"staff_tip":[140,50],"shield_center":[128,122]},
   8:{"staff_tip":[140,50],"shield_center":[128,122]},
   9:{"staff_tip":[140,50],"shield_center":[128,122]},
   10:{"staff_tip":[140,50],"shield_center":[128,122]},
   11:{"staff_tip":[140,50],"shield_center":[128,122]},
   12:{"staff_tip":[140,50],"shield_center":[128,122]},
   13:{"staff_tip":[140,50],"shield_center":[128,122]},
   14:{"staff_tip":[140,50],"shield_center":[128,122]},
   15:{"staff_tip":[140,50],"shield_center":[128,122]},
   16:{"staff_tip":[140,50],"shield_center":[128,122]},
  },
  "unlock_1": {  # 诵经·定妖（诵经→经页浮空→梵文绕身→法圈扩大→妖怪迟滞→定身峰值→经页回收→余辉）
   1:{"palm":[124,148],"body_center":[128,156]},
   2:{"palm":[124,146],"body_center":[128,156]},
   3:{"palm":[126,144],"body_center":[128,154]},
   4:{"palm":[128,142],"body_center":[128,152]},
   5:{"palm":[128,140],"body_center":[128,150]},
   6:{"palm":[128,138],"body_center":[128,150]},
   7:{"palm":[128,136],"body_center":[128,146]},
   8:{"palm":[128,134],"body_center":[128,148]},
   9:{"palm":[128,132],"body_center":[128,146]},
   10:{"palm":[128,130],"body_center":[128,144]},
   11:{"palm":[128,130],"body_center":[128,144]},
   12:{"palm":[128,130],"body_center":[128,144]},
   13:{"palm":[128,128],"body_center":[128,144]},
   14:{"palm":[128,128],"body_center":[128,144]},
   15:{"palm":[124,124],"body_center":[128,144]},
   16:{"palm":[128,128],"body_center":[128,144]},
   17:{"palm":[128,126],"body_center":[128,144]},
   18:{"palm":[128,124],"body_center":[128,144]},
  },
 },
}

d = json.load(open('data/v6_1_full_keyframes_exact_pose.json', encoding='utf-8'))
kfs = d['keyframes']

def pose_path(cs, fname):
    for base in ['art/v6_pose_clean/%s/' % cs, 'art/v6_pose/%s/' % cs]:
        if os.path.exists(base + fname):
            return base + fname
    return None

out = {"_meta": {
    "desc": "M2-R4 身体/武器锚点：从姿势关键帧标注（视觉模型网格读数+抽查复核），随关键帧插值；flip 时 x 镜像。坐标=姿势图像素(0-256, 原点左上, y向下)。ground/body_center 为剪影程序化计算。",
    "verified": ["sun_wukong/atk_combo/kf09 zoom[36,141] vs sheet[34,140]",
                  "sun_wukong/heavy/kf05 zoom[92,30] vs sheet[92,30]"],
    "labeled_by": "M2-R4 anchor pass 2026-09-13",
}}
for cs, acts in LABELS.items():
    out[cs] = {}
    for act, kmap in acts.items():
        rows = sorted([k for k in kfs if k['character_slug'] == cs and k['action_slug'] == act],
                      key=lambda k: k['time_ms'])
        entry = {}
        for k in rows:
            idx = k['keyframe_index']
            if idx not in kmap:
                continue
            a = {kk: [round(v / 256.0, 4) for v in vv] for kk, vv in kmap[idx].items()}
            p = pose_path(cs, k['pose_file'].split('/')[-1])
            if p:
                img = Image.open(p).convert('RGBA')
                px = img.load()
                sx = sy = sw = 0.0
                maxy = -1
                xs = []
                for y in range(256):
                    for x in range(256):
                        r, g, b, al = px[x, y]
                        if al > 60 and not (r > 200 and g > 200 and b > 200 and al < 140):
                            w = al / 255.0
                            sx += x * w
                            sy += y * w
                            sw += w
                            if y > maxy:
                                maxy = y
                                xs = []
                            if y == maxy:
                                xs.append(x)
                if sw > 0 and maxy >= 0:
                    if 'body_center' not in a:
                        a['body_center'] = [round(sx / sw / 256.0, 4), round(sy / sw / 256.0, 4)]
                    a['ground'] = [round(sum(xs) / len(xs) / 256.0, 4), round(maxy / 256.0, 4)]
            entry[str(idx)] = a
        out[cs][act] = entry
json.dump(out, open('data/v6_body_anchors.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
n_actions = sum(len(acts) for c in out.values() if isinstance(c, dict) for acts in c.values())
print('written actions:', n_actions)
print('sample ground wk/atk kf1:', out['sun_wukong']['atk_combo']['1'].get('ground'))
print('sample ground tg/atk kf7:', out['tang_sanzang']['atk_combo']['7'].get('ground'))
