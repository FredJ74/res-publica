#!/usr/bin/env python3
"""Retouche précise de la source WebP de la rue V7 de Novomirsk.

Ne modifie pas les bâtiments ni les autres textes. Supprime seulement le S
final du titre « RÉSIDENCES » pour afficher « RÉSIDENCE IMPÉRIALE ».
"""
import argparse
import base64
import hashlib
import io
from pathlib import Path

from PIL import Image, ImageDraw
import urllib.request

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT / 'images/rue-residences-eglise-novomirsk.webp'
EXPECTED_SHA256=''  # La sécurité de l'exécution utilise le SHA Git du blob.

def inspect():
    url='https://raw.githubusercontent.com/FredJ74/res-publica/d79b7ad0f7ec2b42e9d433bd2418553f894b3c67/images/rue-residences-eglise-novomirsk.webp'
    original=Image.open(io.BytesIO(urllib.request.urlopen(url,timeout=20).read())).convert('RGB')
    image=original
    import cv2
    import numpy as np
    raw=np.array(original)
    region=raw[376:416,1462:1491]
    rr,gg,bb=region[:,:,0],region[:,:,1],region[:,:,2]
    gold=((rr>95)&(gg>60)&(rr>gg*1.12)&(gg>bb*1.1)).astype('uint8')
    n,lbl,stats,centroids=cv2.connectedComponentsWithStats(gold,8)
    print('GOLD_COMPONENTS')
    for idx in range(1,n):
        x,y,w,h,area=map(int,stats[idx])
        if area>=2:
            print(f'COMP {idx}: x={x+1462}..{x+w+1461}, y={y+376}..{y+h+375}, pixels={area}, cx={centroids[idx][0]+1462:.1f}, cy={centroids[idx][1]+376:.1f}')
    print(f"ORIGINAL_SIZE={image.size[0]}x{image.size[1]}")
    crop=image.crop((1420,355,1515,435)).resize((760,640),Image.Resampling.NEAREST)
    draw=ImageDraw.Draw(crop)
    for x in range(1460,1501,2):
        px=(x-1420)*8
        draw.line([(px,0),(px,640)],fill=(60,255,80) if x%10==0 else (70,140,255),width=1)
        draw.text((px+1,5 if x%4==0 else 22),str(x),fill='white')
    for y in range(365,431,5):
        py=(y-355)*8
        draw.line([(0,py),(760,py)],fill=(255,100,60),width=1)
        draw.text((3,py+2),str(y),fill='white')
    buffer=io.BytesIO()
    crop.save(buffer,format='WEBP',quality=82)
    print('INSPECTION_WEBP_BASE64_BEGIN')
    print(base64.b64encode(buffer.getvalue()).decode('ascii'))
    print('INSPECTION_WEBP_BASE64_END')

def apply():
    import cv2
    import numpy as np
    # Toujours repartir de la source WebP exacte, sans réencoder la première
    # retouche insuffisante. Le SHA de commit est fixé pour empêcher un glissement.
    url='https://raw.githubusercontent.com/FredJ74/res-publica/d79b7ad0f7ec2b42e9d433bd2418553f894b3c67/images/rue-residences-eglise-novomirsk.webp'
    original=Image.open(io.BytesIO(urllib.request.urlopen(url,timeout=20).read())).convert('RGB')
    rgb=np.array(original)
    assert rgb.shape==(1024,1536,3),f'Taille modifiée : {rgb.shape}'
    region=rgb[376:416,1462:1491]
    rr,gg,bb=region[:,:,0],region[:,:,1],region[:,:,2]
    gold=((rr>95)&(gg>60)&(rr>gg*1.12)&(gg>bb*1.1)).astype('uint8')
    count,labels,stats,centroids=cv2.connectedComponentsWithStats(gold,8)
    candidates=[i for i in range(1,count) if stats[i,4]>=30 and centroids[i,0]+1462>=1479]
    assert len(candidates)==1,f'Le S final n\'est pas isolable : {candidates}'
    target=candidates[0]
    x,y,w,h,pixels=map(int,stats[target])
    assert (x+1462,y+376,w,h)==(1478,381,8,26),(x,y,w,h)
    print('S_ISOLE=',x+1462,y+376,w,h,'pixels=',pixels)
    glyph=(labels==target).astype('uint8')*255
    glyph=cv2.dilate(glyph,np.ones((3,3),dtype=np.uint8),iterations=1)
    # Les composants dorés voisins, notamment le E final, sont intouchables.
    glyph[(labels>0)&(labels!=target)]=0
    mask=np.zeros(rgb.shape[:2],dtype=np.uint8)
    mask[376:416,1462:1491]=glyph
    assert np.count_nonzero(mask)<200
    corrected=cv2.inpaint(cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR),mask,2,cv2.INPAINT_TELEA)
    assert np.all(corrected[mask==0]==cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR)[mask==0])
    output=Image.fromarray(cv2.cvtColor(corrected,cv2.COLOR_BGR2RGB))
    output.save(SOURCE,format='WEBP',quality=96,method=6)
    check=Image.open(SOURCE)
    assert check.size==(1536,1024) and check.format=='WEBP'
    print('CORRECTED_FILE=',SOURCE)
    print('WEBP_BYTES=',SOURCE.stat().st_size)
    print('FILE_SHA256=',hashlib.sha256(SOURCE.read_bytes()).hexdigest())

def main():
    parser=argparse.ArgumentParser()
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--inspect',action='store_true')
    mode.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    if args.inspect:inspect()
    else:apply()

if __name__=='__main__':main()
