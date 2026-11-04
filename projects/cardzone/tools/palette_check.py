#!/usr/bin/env python3
"""CardZone palette check (cz15): CIE L* and Machado 2009 colour-blind simulation (full severity).
Usage: python3 tools/palette_check.py @rarity C=#3F4552 U=#0F7A70 R=#4C8AF2 E=#FFB070 L=#FFEE80
Prints L* per colour per mode, the closest pair (dE76) and the closest pair in lightness."""
import numpy as np, itertools, sys
# Machado et al. 2009, severity 1.0, linear RGB
M={'protan':[[0.152286,1.052583,-0.204868],[0.114503,0.786281,0.099216],[-0.003882,-0.048116,1.051998]],
   'deutan':[[0.367322,0.860646,-0.227968],[0.280085,0.672501,0.047413],[-0.011820,0.042940,0.968881]],
   'tritan':[[1.255528,-0.076749,-0.178779],[-0.078411,0.930809,0.147602],[0.004733,0.691367,0.303900]]}
def lin(c): c=np.array(c)/255; return np.where(c<=0.04045,c/12.92,((c+0.055)/1.055)**2.4)
def lab(l):
    X=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])@l
    X=X/np.array([0.95047,1,1.08883]); f=np.where(X>0.008856,np.cbrt(X),7.787*X+16/116)
    return np.array([116*f[1]-16,500*(f[0]-f[1]),200*(f[1]-f[2])])
def hx(h): h=h.lstrip('#'); return [int(h[i:i+2],16) for i in (0,2,4)]
sets={}
cur=None
for a in sys.argv[1:]:
    if a.startswith('@'): cur=a[1:]; sets[cur]={}; continue
    k,v=a.split('='); sets[cur][k]=v
for name,cols in sets.items():
    print('==',name)
    for mode in ['normal','protan','deutan','tritan']:
        labs={}
        for k,v in cols.items():
            l=np.clip(lin(hx(v)),0,1)
            if mode!='normal': l=np.clip(np.array(M[mode])@l,0,1)
            labs[k]=lab(l)
        Ls=' '.join(f'{k}:{labs[k][0]:.0f}' for k in cols)
        mind=min((np.linalg.norm(labs[a]-labs[b]),a,b) for a,b in itertools.combinations(cols,2))
        minL=min((abs(labs[a][0]-labs[b][0]),a,b) for a,b in itertools.combinations(cols,2))
        print(f'{mode:7s} L* {Ls} | min dE76 {mind[0]:.0f} ({mind[1]}-{mind[2]}) | min dL {minL[0]:.0f} ({minL[1]}-{minL[2]})')
