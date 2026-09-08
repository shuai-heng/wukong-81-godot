"""Compose original pentatonic music and layered combat Foley, deterministically."""
from pathlib import Path
import wave
import numpy as np

OUT=Path(__file__).resolve().parents[1]/'assets'/'audio';OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
rng=np.random.default_rng(8109)
def write(name,a):
    a=np.clip(a,-.95,.95)
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:
        w.setnchannels(1 if a.ndim==1 else 2);w.setsampwidth(2);w.setframerate(RATE);w.writeframes((a*32767).astype('<i2').tobytes())
def tone(freq,dur,decay=5):
    t=np.arange(int(RATE*dur))/RATE
    return (np.sin(2*np.pi*freq*t)+.22*np.sin(2*np.pi*freq*2.01*t))*.7*np.exp(-t/dur*decay)*np.minimum(1,t*300)
for name,freq,dur in [('hit',150,.12),('heavy',68,.28),('hurt',105,.24),('dash',490,.15),('cast',630,.3),('kill',95,.22),('break',280,.38),('tang',760,.55),('wukong',110,.32),('whiteDragon',480,.48),('bajie',55,.48),('shaWujing',300,.48),('nezha',220,.4),('erlang',980,.48),('ultimate',55,1.35),('form',440,1.1),('pickup',1047,.1),('ui',880,.08),('level',660,.7),('victory',523,1.8),('defeat',110,1.8),('warning',330,.3)]:
    t=np.arange(int(RATE*dur))/RATE
    noise=rng.standard_normal(len(t))*.22*np.exp(-t/dur*8)
    if name in ('hit','heavy','hurt','kill','break','wukong','bajie','ultimate'):
        a=np.sin(2*np.pi*(freq*t+freq*.08*(1-np.exp(-t*40))))*np.exp(-t/dur*5)+noise
        a+=.2*np.sin(2*np.pi*freq*2.7*t)*np.exp(-t/dur*11)
    elif name in ('dash','nezha','whiteDragon','shaWujing'):
        a=.38*np.sin(2*np.pi*(freq*t+400*t*t))*np.exp(-t/dur*4)+noise*1.7
    elif name in ('level','victory','form','ultimate'):
        a=np.zeros(len(t))
        for j,m in enumerate([1,1.25,1.5,2]):
            offset=int(j*dur/7*RATE);n= tone(freq*m,dur-j*dur/7,3)
            a[offset:offset+len(n)]+=n[:len(a)-offset]*.4
    elif name=='defeat':a=tone(freq,dur,2)+tone(freq*1.19,dur,3)*.3
    else:a=tone(freq,dur,4)+.18*tone(freq*2,dur,5)
    a=a/max(1,np.max(np.abs(a)))*.7
    a*=np.minimum(1,(dur-t)*90)
    write(name,a)
# Soft guqin-like plucks, bamboo-flute lead, low temple drum. 16-bar loops.
for name,root,tempo,pattern in [('pilgrimage',146.83,92,[0,2,4,7,9,7,4,2,0,4,7,12,9,7,4,2]),('river',164.81,82,[0,4,7,9,12,9,7,4,2,4,7,4,2,0,2,4]),('battle',130.81,112,[0,0,7,4,2,2,9,7,4,7,12,9,7,4,2,0]),('temple',174.61,76,[0,7,4,2,0,9,7,4,2,7,9,12,7,4,2,0])]:
    beat=60/tempo;length=beat*32;audio=np.zeros((int(length*RATE),2))
    def add(start,sig,gain,pan=0):
        start=int(start*RATE);n=min(len(sig),len(audio)-start)
        audio[start:start+n,0]+=sig[:n]*gain*(.8-pan*.2);audio[start:start+n,1]+=sig[:n]*gain*(.8+pan*.2)
    for i in range(64):
        note=pattern[i%16];freq=root*2**(note/12)
        add(i*beat/2,tone(freq*2,beat*1.8,5),.15,(-1 if i%2 else 1))
        if i%2==0:
            t=np.arange(int(RATE*beat*1.5))/RATE
            flute=np.sin(2*np.pi*freq*t+.035*np.sin(t*32))*np.sin(np.minimum(t/(beat*1.5),1)*np.pi)**1.2
            add(i*beat/2,flute,.075,.2)
        if i%8==0:add(i*beat/2,tone(root/2,beat*4,3),.19,-.3)
        if i%4==0:
            t=np.arange(int(RATE*.23))/RATE;kick=np.sin(2*np.pi*(63*t+2*(1-np.exp(-t*40))))*np.exp(-t*22)
            add(i*beat/2,kick,.13)
    # Quiet wrap crossfade prevents clicks at loop boundaries.
    fade=int(RATE*.02);audio[:fade]*=np.linspace(0,1,fade)[:,None];audio[-fade:]*=np.linspace(1,0,fade)[:,None]
    write('music_'+name,audio)
print('Built 21 layered sounds and 4 original looping compositions')
