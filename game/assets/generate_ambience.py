import math, random, struct, wave
from pathlib import Path
random.seed(1826)
rate=22050; seconds=24; output=Path(__file__).with_name('valley_ambience.wav')
low=0.0; samples=[]
notes=[130.8128, 164.8138, 195.9977, 261.6256]
for i in range(rate*seconds):
    t=i/rate
    low=low*.985+random.uniform(-1,1)*.015
    wind=low*.14
    pad=sum(math.sin(2*math.pi*f*t+0.5*math.sin(t*.19+j))*0.009 for j,f in enumerate(notes))
    bird=0.0
    for start in (3.2, 9.1, 18.4):
        dt=t-start
        if 0<dt<.43:
            bird+=math.sin(2*math.pi*(1650*dt+500*dt*dt))*math.sin(math.pi*dt/.43)**2*.025
    fade=min(t/1.5,(seconds-t)/1.5,1)
    samples.append(struct.pack('<h',int(max(-1,min(1,(wind+pad+bird)*fade))*32767)))
with wave.open(str(output),'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(b''.join(samples))
