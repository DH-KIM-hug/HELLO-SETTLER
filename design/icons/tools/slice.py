"""slice.py <sheet.png> <sheet_id> [only_ids,...] -> godot/art/icons/<group>/<id>.png
Key flat magenta to alpha, find blobs, assign to grid cell by centroid, crop, fit to 256x256."""
import json,sys,os
import numpy as np
from PIL import Image
from scipy import ndimage
R="/Users/house_of_4k2b/orca/HELLO-SETTLER"
d=json.load(open(f"{R}/design/icons/tools/sheets.json"))
src,sid=sys.argv[1],sys.argv[2]
only=set(sys.argv[3].split(",")) if len(sys.argv)>3 else None
s=[x for x in d["sheets"] if x["id"]==sid][0]
im=np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
H,W,_=im.shape
M=np.array([255,0,255],np.float32)
# magenta-ness: high R, high B, low G
mag=np.minimum(im[...,0],im[...,2])-im[...,1]   # 255 for pure magenta
t_full,t_none=200.0,90.0   # >=200 bg, <=90 opaque
a=np.clip((t_full-mag)/(t_full-t_none),0,1)
# despill
aa=np.maximum(a,1e-3)[...,None]
rgb=(im-(1-aa)*M)/aa
rgb=np.clip(rgb,0,255)
# edge pixels: take colour of nearest fully-opaque pixel (kills magenta fringe)
solid=a>=0.999
idx=ndimage.distance_transform_edt(~solid,return_distances=False,return_indices=True)
edge=(a>0)&~solid
rgb[edge]=rgb[idx[0][edge],idx[1][edge]]
rgba=np.dstack([rgb,a*255]).astype(np.uint8)
mask=a>0.5
lab,n=ndimage.label(ndimage.binary_dilation(mask,iterations=6))
c,r=s["cols"],s["rows"]
cells={}
for i,sl in enumerate(ndimage.find_objects(lab)):
    comp=(lab[sl]==i+1)&mask[sl]
    area=comp.sum()
    if area<150: continue
    ys,xs=np.nonzero(comp); cy=ys.mean()+sl[0].start; cx=xs.mean()+sl[1].start
    k=int(cy//(H/r))*c+int(cx//(W/c))
    cells.setdefault(k,[]).append((sl,i+1,area))
res=[]
for k,it in enumerate(s["items"]):
    rid,ko,desc=it[:3]; grp=it[3] if len(it)>3 else s["group"]
    if ko=="-" or (only and rid not in only): continue
    if k not in cells: res.append((rid,"MISSING")); continue
    m=np.zeros((H,W),bool)
    for sl,li,_ in cells[k]: m[sl]|=(lab[sl]==li)
    m=ndimage.binary_dilation(m,iterations=2)
    ys,xs=np.nonzero(m)
    y0,y1,x0,x1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
    crop=rgba[y0:y1,x0:x1].copy(); crop[...,3]=np.where(m[y0:y1,x0:x1],crop[...,3],0)
    ci=Image.fromarray(crop,"RGBA")
    box=232; sc=box/max(ci.size); ci=ci.resize((max(1,round(ci.size[0]*sc)),max(1,round(ci.size[1]*sc))),Image.LANCZOS)
    out=Image.new("RGBA",(256,256),(0,0,0,0)); out.paste(ci,((256-ci.size[0])//2,(256-ci.size[1])//2),ci)
    os.makedirs(f"{R}/godot/art/icons/{grp}",exist_ok=True); p=f"{R}/godot/art/icons/{grp}/{rid}.png"; out.save(p)
    touch = x0<=2 or y0<=2 or x1>=W-2 or y1>=H-2
    res.append((rid,f"ok blobs={len(cells[k])} {x1-x0}x{y1-y0}"+(" EDGE" if touch else "")))
extra=[k for k in cells if k>=len(s["items"])]
for x in res: print(*x)
if extra: print("extra cells",extra)
