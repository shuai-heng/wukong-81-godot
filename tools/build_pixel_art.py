"""Original, deterministic pixel sprites. No third-party art or image downloads."""
from pathlib import Path
from PIL import Image, ImageDraw
import math, random, json

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'pixel'
ROOT.mkdir(parents=True, exist_ok=True)
INK = '#141b2b'
SKIN = ['#b76c55', '#e3a276', '#ffcf91']
GOLD = ['#8b522e', '#d89b40', '#ffe29a']
HEROES = {
 'tang': ['#742b41','#bb4655','#ed8663'],
 'wukong': ['#7a472c','#cd8439','#f7c966'],
 'whiteDragon': ['#365975','#82b5c4','#dcf2df'],
 'bajie': ['#353445','#615366','#928083'],
 'shaWujing': ['#245c60','#418b7b','#91c9a4'],
 'nezha': ['#92344b','#e65b5c','#ffb17b'],
 'erlang': ['#364774','#6780af','#c4d6e1'],
}
ANIMS = ['idle','run','atk','hurt','cast']

def hero(kind, anim, frame):
    im = Image.new('RGBA',(64,64)); d = ImageDraw.Draw(im)
    cols=HEROES[kind]; swing = math.sin(frame/8*math.tau)
    bob=round(swing) if anim in ('idle','run') else 0
    ox = round(math.sin(frame/7*math.pi)*4) if anim=='atk' else (-2 if anim=='hurt' else 0)
    oy = bob - (3 if anim=='cast' and frame in (2,3,4) else 0)
    def poly(points, fill, outline=INK):
        p=[(round(x+ox),round(y+oy)) for x,y in points];d.polygon(p,fill=fill)
        if outline:d.line(p+[p[0]],fill=outline,width=1)
    def rect(box,c):d.rectangle(tuple(round(v+(ox if i%2==0 else oy)) for i,v in enumerate(box)),fill=c)
    def ellipse(box,c,outline=None):d.ellipse(tuple(round(v+(ox if i%2==0 else oy)) for i,v in enumerate(box)),fill=c,outline=outline)
    # Grounded feet and separately articulated knees.
    leg=round(swing*3) if anim=='run' else 0
    poly([(24,43),(31,44),(30-leg,55),(21-leg,55),(22-leg,52)],cols[0])
    poly([(32,44),(40,43),(42+leg,54),(33+leg,55)],cols[0])
    rect((21-leg,54,30-leg,56),INK);rect((33+leg,54,43+leg,56),INK)
    rect((22-leg,53,28-leg,54),GOLD[1]);rect((35+leg,53,40+leg,54),GOLD[1])
    # Flowing silhouette, lit left side and folded material.
    wide=4 if kind=='bajie' else 0
    poly([(23-wide,27),(39+wide,27),(44+wide,46),(36,50),(21-wide,48),(18-wide,43)],cols[0])
    poly([(24-wide,27),(36,27),(34,46),(22-wide,46),(19-wide,42)],cols[1],None)
    poly([(25-wide,29),(29,29),(27,45),(22-wide,44)],cols[2],None)
    rect((23-wide,39,39+wide,41),GOLD[0]);rect((25-wide,39,38+wide,39),GOLD[1])
    rect((30,39,33,42),GOLD[2])
    # Sleeves and hands. Strike anticipates, extends, recovers across 8 frames.
    attack = [0,-2,-4,8,12,9,4,0][frame] if anim=='atk' else 0
    raised = anim=='cast'
    hand_y=22 if raised else 35
    poly([(21-wide,29),(24,31),(20,hand_y+6),(15-wide,hand_y+4),(17-wide,31)],cols[1])
    ellipse((15-wide,hand_y+1,20-wide,hand_y+6),SKIN[1],INK)
    poly([(37,29),(42,30),(46+attack,hand_y+4),(42+attack,hand_y+8),(37,35)],cols[1])
    ellipse((41+attack,hand_y+3,46+attack,hand_y+8),SKIN[2],INK)
    # Heads have unique outlines and facial identity.
    if kind=='wukong':
        ellipse((19,11,42,31),'#714735',INK);ellipse((18,20,23,25),SKIN[1],INK);ellipse((39,20,44,25),SKIN[1],INK)
        poly([(23,13),(25,9),(29,12),(33,8),(38,12),(41,20),(37,30),(25,29),(21,22)],'#a66a3f')
        poly([(23,19),(28,17),(31,20),(34,17),(39,19),(37,27),(32,30),(25,27)],SKIN[2])
        rect((22,16,39,17),GOLD[1]);rect((28,15,34,16),GOLD[2])
        poly([(25,30),(20,33),(23,37),(27,32)],'#b83c45')
        poly([(22,33),(14,33),(9,29),(13,37),(22,36)],'#e96053')
        # Tail curls out of the coat.
        d.line([(20+ox,43+oy),(12+ox,44+oy),(10+ox,40+oy),(13+ox,38+oy)],fill=INK,width=4)
        d.line([(20+ox,43+oy),(12+ox,44+oy),(10+ox,40+oy),(13+ox,38+oy)],fill='#c28348',width=2)
    elif kind=='bajie':
        poly([(22,15),(16,14),(13,21),(20,27),(22,31),(39,31),(45,23),(48,15),(39,16)],'#d89287')
        ellipse((21,13,40,31),SKIN[1],INK);ellipse((26,23,39,30),'#efa9a0',INK)
        rect((29,25,30,27),'#7b4149');rect((35,25,36,27),'#7b4149')
        poly([(21,17),(22,11),(38,11),(41,17)],'#313448');rect((23,12,38,13),'#555569')
        ellipse((24,31,39,39),SKIN[1],INK);rect((30,35,32,36),SKIN[0])
    else:
        ellipse((22,12,40,30),SKIN[0],INK);ellipse((23,12,37,27),SKIN[2])
        if kind=='tang':
            poly([(21,18),(20,12),(23,10),(23,6),(28,9),(31,4),(34,9),(39,6),(39,12),(42,15),(40,19)],GOLD[1])
            rect((24,14,38,16),GOLD[2]);ellipse((29,11,33,15),'#cb4e52',INK)
            poly([(23,28),(20,30),(25,48),(35,48),(31,30)],'#e5ab55')
            for y in (32,38,44):rect((23,y,33,y),GOLD[0])
            rect((26,29,26,46),GOLD[2]);rect((31,31,31,47),GOLD[0])
            poly([(38,12),(43,16),(43,27),(39,24)],'#d55651')
        elif kind=='whiteDragon':
            poly([(21,21),(21,13),(26,8),(36,8),(42,15),(40,32),(36,24),(33,15),(25,19)],'#cfeced')
            poly([(23,12),(18,9),(18,3),(21,7),(26,9)],'#87c6ca')
            poly([(36,10),(40,3),(43,3),(41,10),(39,14)],'#e1f4de')
            for y in (30,34,38):
                for x in (26,31,36):poly([(x,y),(x+3,y),(x+2,y+2)],'#a3dde0',None)
            poly([(20,30),(14,35),(10,44),(19,40)],'#83bdbf')
        elif kind=='shaWujing':
            poly([(21,24),(20,16),(25,10),(38,11),(42,18),(40,25),(36,18),(26,17)],'#3b2732')
            poly([(23,25),(27,27),(37,25),(38,32),(32,37),(25,33)],'#643e33')
            rect((22,16,40,18),GOLD[1])
            for x,y in [(23,30),(23,34),(27,37),(32,38),(37,35),(40,31)]:
                ellipse((x-2,y-2,x+2,y+2),'#e4d4a4',INK);rect((x-1,y-1,x,y),'#514b47')
        elif kind=='nezha':
            ellipse((18,9,27,18),'#242331',INK);ellipse((36,9,45,18),'#242331',INK)
            poly([(23,19),(22,13),(27,10),(36,11),(41,17),(34,15),(30,19),(27,15)],'#303044')
            rect((19,14,26,16),'#eb585f');rect((37,14,43,16),'#eb585f')
            poly([(37,30),(47,25),(56,30),(51,34),(45,31),(41,39)],'#f36f71')
            poly([(23,29),(13,28),(6,35),(12,40),(16,34),(23,34)],'#ba3551')
            for x in (23-leg,37+leg):
                ellipse((x-5,51,x+5,59),'#b13c37',INK);ellipse((x-3,52,x+3,58),'#f89c45');ellipse((x-1,54,x+1,56),'#ffe5a0')
        elif kind=='erlang':
            poly([(21,21),(20,12),(25,8),(37,8),(43,16),(40,25),(36,15),(26,17)],'#293544')
            poly([(22,13),(25,7),(29,9),(32,5),(35,9),(39,7),(40,14)],'#91b4d1')
            ellipse((30,16,33,20),'#ffe8ad',INK)
            poly([(20,29),(14,32),(16,38),(23,36)],'#809ac6')
            poly([(38,28),(46,31),(46,36),(40,37)],'#acccdf')
            rect((27,31,35,33),'#bfd4e8');rect((28,35,34,36),'#92b4cc')
    # Faces: intentional 1px eye highlights, brow, mouth.
    if kind!='bajie':
        rect((26,21,28,22),INK);rect((35,21,37,22),INK)
        rect((26,21,26,21),'#ffffff');rect((35,21,35,21),'#ffffff')
        rect((30,26,33,26),SKIN[0])
    else:rect((24,20,26,21),INK);rect((35,20,37,21),INK)
    # Weapons are part of every pose, not a shared rectangle.
    wx=46+attack; wy=hand_y+5
    if kind=='wukong':
        if anim=='atk' and frame in (3,4,5):
            d.line([(25+ox,34+oy),(61,29+oy)],fill=INK,width=5);d.line([(26+ox,34+oy),(61,29+oy)],fill='#d89542',width=3)
            d.line([(54,30+oy),(61,29+oy)],fill='#ffe39a',width=3)
        else:rect((wx,9,wx+2,52),INK);rect((wx,10,wx+1,51),'#c9783c');rect((wx,10,wx+1,17),GOLD[2]);rect((wx,45,wx+1,51),GOLD[2])
    elif kind in ('tang','shaWujing'):
        rect((wx,14,wx+2,53),INK);rect((wx,15,wx,52),GOLD[1])
        if kind=='tang':
            ellipse((wx-4,7,wx+6,19),GOLD[1],INK);ellipse((wx-2,9,wx+4,16),INK)
            for dx in (-5,3):ellipse((wx+dx,14,wx+dx+4,21),GOLD[2],INK)
        else:
            poly([(wx-7,9),(wx-4,17),(wx+4,17),(wx+7,9),(wx+8,17),(wx+3,22),(wx-4,21),(wx-8,17)],'#bdd5cb')
    elif kind=='bajie':
        rect((wx,18,wx+2,54),'#7d604d');rect((wx-9,15,wx+7,18),'#94a1ad')
        for dx in range(-9,8,2):rect((wx+dx,10,wx+dx,17),'#d8d7c2')
    else:
        rect((wx,12,wx+2,53),INK);rect((wx,14,wx,51),GOLD[1])
        poly([(wx-3,14),(wx+1,3),(wx+5,14),(wx+1,19)],'#d6eef0')
        if kind=='erlang':
            poly([(wx-5,11),(wx-4,5),(wx-2,13),(wx+4,13),(wx+6,5),(wx+7,11),(wx+4,18),(wx-3,18)],'#96bacf')
        if kind=='nezha':
            poly([(wx-2,19),(wx+6,19),(wx+10,25),(wx+4,23)],'#e9534e')
    if anim=='hurt':
        # Maintain silhouette during hit flashes (runtime applies extra flash).
        overlay=Image.new('RGBA',im.size,(255,239,195,70));im=Image.alpha_composite(im,Image.composite(overlay,Image.new('RGBA',im.size),im.getchannel('A')))
    return im

ENEMIES=['wolf','bone','bat','snake','boar','mushroom','water','soldier','spider','fire','lion','ox','tiger','raven','monk','fox','rhino','deer','scorpion','rabbit','dragon','gold','silver','yellow','roc','centipede','rat','ape']
def enemy(kind,frame,anim):
    im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
    idx=ENEMIES.index(kind);rng=random.Random(180+idx)
    hues=[('#344a60','#608ba0','#a2c5c2'),('#766755','#bdb393','#efe4bc'),('#43334f','#7d5291','#b482b4'),('#2c5f52','#579b71','#acd299'),('#643945','#a5615c','#d69e7f'),('#553843','#b1535d','#f0937c'),('#235c6f','#42909d','#82d2ca'),('#3d435b','#777a96','#c1b1a0')]
    dark,mid,light=hues[idx%len(hues)];bob=int(math.sin(frame/8*math.tau)*2);leg=int(math.sin(frame/8*math.tau)*3) if anim=='run' else 0
    def p(points,c,outline=INK):
        ps=[(x,y+bob) for x,y in points];d.polygon(ps,fill=c);d.line(ps+[ps[0]],fill=outline,width=1)
    def e(b,c,o=INK):d.ellipse((b[0],b[1]+bob,b[2],b[3]+bob),fill=c,outline=o)
    def r(b,c):d.rectangle((b[0],b[1]+bob,b[2],b[3]+bob),fill=c)
    if kind in ('bat','raven','roc'):
        flap=int(math.sin(frame/8*math.tau)*8)
        p([(29,29),(13,17+flap),(4,25+flap),(9,42),(19,35),(27,43)],mid)
        p([(34,29),(51,17+flap),(61,25+flap),(55,42),(44,35),(35,43)],mid)
        e((25,23,39,46),dark);p([(28,27),(25,18),(32,22),(38,17),(38,29)],mid)
        r((28,28,30,30),'#ffe799');r((35,28,37,30),'#ffe799');p([(30,33),(35,33),(32,38)],light)
    elif kind in ('snake','dragon','centipede','scorpion'):
        pts=[(10,48),(19,52),(31,49),(42,42),(40,30)]
        d.line([(x,y+bob) for x,y in pts],fill=INK,width=12);d.line([(x,y+bob) for x,y in pts],fill=mid,width=9)
        e((29,20,46,35),mid);r((33,24,36,26),'#ffe49b');r((42,24,44,26),'#ffe49b')
        for x,y in pts:r((x,y-2,x+3,y),light)
        if kind=='dragon':
            p([(30,23),(25,10),(34,19)],light);p([(42,22),(49,11),(45,28)],light)
            p([(28,39),(20,34),(24,46)],mid)
        if kind=='centipede':
            for y in (37,43,49):p([(27,y),(17,y+3),(15,y+7),(24,y+4)],light)
        if kind=='scorpion':p([(42,36),(54,29),(58,33),(52,41),(44,42)],light)
    elif kind=='spider':
        for side in (-1,1):
            for n in range(3):d.line([(32,35+bob),(32+side*(16+n*2),23+n*9+bob),(32+side*24,34+n*7+bob)],fill=mid,width=3)
        e((20,25,46,48),dark);e((24,32,41,46),mid)
        for x in (27,32,37):e((x,35,x+2,38),'#f5bf85')
    else:
        w=6 if kind in ('boar','ox','rhino','ape') else 0
        p([(24,40),(30,41),(29-leg,54),(21-leg,54)],dark);p([(34,40),(40,39),(43+leg,53),(34+leg,54)],dark)
        p([(23-w,26),(39+w,26),(45+w,45),(35,48),(21-w,45)],mid)
        p([(23-w,29),(29,28),(27,44),(22-w,42)],light)
        p([(22-w,28),(14-w,35),(16-w,43),(23-w,36)],dark);p([(39+w,28),(48+w,35),(47+w,41),(40+w,38)],mid)
        e((21-w//2,12,42+w//2,32),mid);e((23-w//2,13,36,27),light,None)
        if kind in ('wolf','fox','tiger','lion','ape'):
            p([(22,18),(19,6),(28,12)],mid);p([(35,12),(43,6),(41,20)],mid)
            p([(26,25),(38,24),(43,30),(36,34),(25,31)],light)
            r((36,27,39,29),INK)
            if kind=='lion':
                for dx,dy in [(19,14),(18,21),(20,29),(41,17),(43,25)]:p([(dx,dy),(dx-4,dy-3),(dx-3,dy+8),(dx+3,dy+4)],'#9b673e')
        elif kind in ('boar','ox','rhino','deer'):
            p([(23,17),(16,7),(20,23)],light);p([(39,16),(46,7),(42,24)],light)
            e((25,23,42,34),dark);r((29,27,31,29),INK);r((37,27,39,29),INK)
            if kind=='rhino':p([(31,25),(34,12),(38,27)],'#e4d0a5')
        elif kind=='bone':
            e((22,12,42,32),light);e((24,20,29,26),INK);e((34,20,39,26),INK)
            for y in (35,39,43):r((26,y,39,y),light)
            r((31,31,33,45),light);r((28,28,36,30),dark)
        elif kind=='mushroom':
            p([(15,23),(20,12),(30,8),(43,13),(49,24)],'#bc555c')
            for x,y in [(24,13),(33,16),(41,21)]:e((x,y,x+3,y+2),'#ecd5a7',None)
        elif kind=='rabbit':p([(23,16),(23,1),(28,2),(30,16)],light);p([(33,16),(36,1),(40,3),(38,19)],light)
        elif kind in ('soldier','gold','silver','yellow','monk'):
            p([(19,20),(22,10),(31,6),(41,11),(44,21)],dark);r((22,17,40,19),light)
            p([(29,10),(31,1),(35,9)],'#e7975f')
            for y in (32,37,42):r((27,y,39,y),light)
            d.line([(47,18),(48,54)],fill='#d4b278',width=2);p([(44,20),(47,9),(51,20)],'#c4d3d8')
        else:p([(21,19),(24,9),(40,10),(43,25),(37,18)],dark)
        if kind!='bone':r((26,21,28,23),'#ffe4a2');r((36,21,38,23),'#ffe4a2')
    return im

manifest={'cell':64,'frames':8,'animations':ANIMS,'heroes':list(HEROES),'enemies':ENEMIES}
for kind in list(HEROES)+ENEMIES:
    sheet=Image.new('RGBA',(512,320))
    for row,anim in enumerate(ANIMS):
        for frame in range(8):sheet.paste(hero(kind,anim,frame) if kind in HEROES else enemy(kind,frame,anim),(frame*64,row*64))
    sheet.save(ROOT/f'{kind}.png')
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
# Review atlas: human-visible original frames, with labels.
contact=Image.new('RGB',(7*160,220),'#182536');draw=ImageDraw.Draw(contact)
for i,k in enumerate(HEROES):
    pic=hero(k,'idle',0).resize((128,128),Image.Resampling.NEAREST)
    contact.paste(pic,(i*160+16,36),pic);draw.text((i*160+20,181),k,fill='#d9d2b9')
contact.save(ROOT/'roster.png')
print(f'Built {len(HEROES)} heroes + {len(ENEMIES)} enemies: 8 frames x 5 animations')
