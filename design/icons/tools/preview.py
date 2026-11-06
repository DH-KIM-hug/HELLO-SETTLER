"""preview.py <group> <out.png> [size...] : grid of icons on alternating light/dark tiles"""
import sys,glob,os
from PIL import Image
R="/Users/house_of_4k2b/orca/HELLO-SETTLER"
g,out=sys.argv[1],sys.argv[2]; sizes=[int(x) for x in sys.argv[3:]] or [96,48]
fs=sorted(glob.glob(f"{R}/godot/art/icons/{g}/*.png"))
cols=8; pad=8; cw=sum(sizes)+pad*(len(sizes)+1); ch=max(sizes)+2*pad
rows=(len(fs)+cols-1)//cols
img=Image.new("RGB",(cols*cw,rows*ch*2),(0,0,0))
for i,f in enumerate(fs):
    ic=Image.open(f)
    for k,bg in enumerate([(244,236,216),(46,52,64)]):
        x0=(i%cols)*cw; y0=((i//cols)*2+k)*ch
        img.paste(Image.new("RGB",(cw,ch),bg),(x0,y0))
        x=x0+pad
        for s in sizes:
            t=ic.resize((s,s),Image.LANCZOS); img.paste(t,(x,y0+pad+(max(sizes)-s)//2),t); x+=s+pad
img.save(out); print(out,len(fs))
