# G13 重放：在真实磁盘上重新实现 G12+G13 全部改动
# （从会话记录精确重建——原实现被 F 盘虚拟化层丢失）
p='scripts/player.gd'
s=open(p,encoding='utf-8').read()
applied=[]

# 1) 变量：g_count/g_cd_left/dragon_left/dragon_cd_left（跟在 q_cd_left 后）
old='\tvar q_cd_left := 0.0'
if 'var g_count' not in s:
    assert old in s, 'P1 vars'
    new=old+'\n\tvar g_count := 0\n\tvar g_cd_left := 0.0\n\tvar dragon_left := 0.0\n\tvar dragon_cd_left := 0.0'
    s=s.replace(old,new,1); applied.append('P1-vars')

# 2) 输入分支：G 键（跟在 ult 后）
old='\t\tif Input.is_action_just_pressed("ult"):\n\t\t\t_cast_ult()'
if 'Input.is_action_just_pressed("gong")' not in s:
    assert old in s, 'P2 input'
    new=old+'\n\t\tif Input.is_action_just_pressed("gong") and g_cd_left <= 0.0:\n\t\t\t_cast_g()'
    s=s.replace(old,new,1); applied.append('P2-input')

# 3) _ai_drive：tang 度厄 + whiteDragon 化龙 触发（跟在 Q 触发后）
old='\t\tif hero == "tang" and g_cd_left <= 0.0 and ai_skill_cd <= 0.0:'
if 'hero == "whiteDragon" and g_cd_left' not in s:
    assert old in s, 'P3 ai-tang'
    new=old+'\n\t\tif hero == "whiteDragon" and g_cd_left <= 0.0 and ai_skill_cd <= 0.0:\n\t\t\t_cast_g()'
    s=s.replace(old,new,1); applied.append('P3-ai-wd')

# 4) _cast_g 实现（插在 _cast_q_tang 前面）
if 'func _cast_g()' not in s:
    impl='''func _cast_g() -> void:
\tif hero == "whiteDragon":
\t\tif dragon_left > 0.0:
\t\t\treturn
\t\tg_cd_left = 30.0
\t\tg_count += 1
\t\tdragon_left = 10.0
\t\tsprite.modulate = Color(0.62, 0.88, 1.0)
\t\tsprite.scale = Vector2(1.22, 1.22)
\t\treturn
\tif hero != "tang":
\t\treturn
\tg_cd_left = 25.0
\tg_count += 1
\tvar dmg := 30.0 + 6.0 * lvl("t_nova")
\tfor e in get_tree().get_nodes_in_group("enemies"):
\t\tif not e.dying:
\t\t\te.take_hit(dmg, (e.global_position - global_position).normalized() * 40.0)

func _cast_q_tang() -> void:'''
    old='func _cast_q_tang() -> void:'
    assert old in s, 'P4 castg'
    s=s.replace(old,impl,1); applied.append('P4-castg')

# 5) _physics_process：dragon 计时衰减+视觉维持（插在 if dash_left 前）
old='\tif dash_left > 0.0:'
if 'dragon_left = maxf' not in s:
    assert old in s, 'P5 tick'
    new='''\tdragon_left = maxf(0.0, dragon_left - delta)
\tdragon_cd_left = maxf(0.0, dragon_cd_left - delta)
\tif dragon_left > 0.0:
\t\tsprite.modulate = Color(0.62, 0.88, 1.0)
\t\tsprite.scale = Vector2(1.22, 1.22)
\tif dash_left > 0.0:'''
    s=s.replace(old,new,1); applied.append('P5-tick')

# 6) move_speed 化龙乘数
old='(1.06 if in_form() else 1.0)\n\tif wheels_left > 0.0:'
if 'dragon_left > 0.0 else 1.0' not in s:
    assert old in s, 'P6 speed'
    new='(1.38 if dragon_left > 0.0 else 1.0)\n\tif wheels_left > 0.0:'
    s=s.replace(old,new,1); applied.append('P6-speed')

# 7) base_dmg 化龙乘数
old='func base_dmg() -> float:\n\treturn Cards.hero_stat(hero, "dmg") * dmg_mul()'
if '(1.25 if dragon_left' not in s:
    assert old in s, 'P7 dmg'
    new='func base_dmg() -> float:\n\treturn Cards.hero_stat(hero, "dmg") * dmg_mul() * (1.25 if dragon_left > 0.0 else 1.0)'
    s=s.replace(old,new,1); applied.append('P7-dmg')

wr_path=p
with open(wr_path,'w',encoding='utf-8',newline='\n') as f:
    f.write(s)
print('player.gd replay:',applied)

# --- main.gd ---
p2='scripts/main.gd'
s2=open(p2,encoding='utf-8').read()
applied2=[]

# 冒烟断言：g_count >= 1（跟在 e_count 后）
old='\t\tand player.q_count >= 3 and player.e_count >= 2 \\'
if 'player.g_count >= 1' not in s2:
    assert old in s2, 'M1 assert'
    new=old+'\n\t\tand player.g_count >= 1 \\'
    s2=s2.replace(old,new,1); applied2.append('M1-g-assert')

# 结果 JSON：g_count
old='"q_count": player.q_count, "e_count": player.e_count,'
if '"g_count"' not in s2:
    assert old in s2, 'M2 json'
    new='"q_count": player.q_count, "e_count": player.e_count, "g_count": player.g_count,'
    s2=s2.replace(old,new,1); applied2.append('M2-g-json')

with open(p2,'w',encoding='utf-8',newline='\n') as f:
    f.write(s2)
print('main.gd replay:',applied2)
