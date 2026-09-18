"""Reproducible metre-based course geometry. Edit route/regions here or exported JSON.
Run from any directory; generated runtime JSON is reviewed and versioned.
"""
from pathlib import Path
import json, math
ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT/'_OffsideGolf-frontend-iOS'/'App'
manifest=json.loads((APP_ROOT/'Resources/Courses/whispering-coast.json').read_text())
shapes=[[(0,0),(0,1)],[(0,0),(12,.50),(-24,.78),(-30,1)],
[(-14,0),(-24,.4),(0,.75),(16,1)],[(0,0),(0,1)],
[(0,0),(18,.30),(-22,.6),(8,.82),(0,1)],[(0,0),(-12,.4),(0,.8),(0,1)],
[(0,0),(0,1)],[(0,0),(-24,.32),(20,.65),(-12,1)],
[(-20,0),(-30,.3),(-6,.68),(18,1)]]
widths=[37,31,32,29,36,33,28,24,29]
winds=[(0,0),(2,90),(4,90),(2,180),(3,0),(4,225),(3,270),(4.5,135),(5,90)]
assets=['windmill','shed','lookout','arch','farmhouse','hide','pavilion','cabin','lighthouse']
def point(x,y): return {'x':round(x,6),'y':round(y,6)}
def rect(x1,y1,x2,y2): return [point(x1,y1),point(x2,y1),point(x2,y2),point(x1,y2)]
def ellipse(x,y,rx,ry): return [point(x+rx*math.cos(i*math.tau/20),y+ry*math.sin(i*math.tau/20)) for i in range(20)]
def length(route):return sum(math.hypot(b[0]-a[0],b[1]-a[1]) for a,b in zip(route,route[1:]))
for index,h in enumerate(manifest['holes']):
    spec=shapes[index]; distance=h['distanceYards']*.9144
    lo,hi=0,distance
    for _ in range(60):
        scale=(lo+hi)/2
        candidate=[(75+x,30+y*scale) for x,y in spec]
        if length(candidate)>distance:hi=scale
        else:lo=scale
    route=[(75+x,30+y*(lo+hi)/2) for x,y in spec]
    px,py=route[-1]; height=math.ceil(py+35)
    # Densify the authored centreline. Organic edge widths do not change route length.
    dense=[]
    for a,b in zip(route,route[1:]):
        steps=max(3,int(math.hypot(b[0]-a[0],b[1]-a[1])/12))
        dense += [(a[0]+(b[0]-a[0])*j/steps,a[1]+(b[1]-a[1])*j/steps) for j in range(steps)]
    dense += [route[-1]]
    left=[];right=[]
    for j,(x,y) in enumerate(dense):
        a=dense[max(0,j-1)];b=dense[min(len(dense)-1,j+1)]
        dx,dy=b[0]-a[0],b[1]-a[1];mag=math.hypot(dx,dy)
        w=widths[index]/2*(1+.08*math.sin(j*1.7))
        left.append(point(x-dy/mag*w,y+dx/mag*w));right.append(point(x+dy/mag*w,y-dx/mag*w))
    fairway=left+right[::-1]
    regions=[];trees=[];drops=[]
    def region(identifier,material,polygon,priority=40):
        regions.append(dict(id=identifier,terrain=material,priority=priority,polygon=polygon))
    region('tee','tee',ellipse(75,30,5,5))
    if index in [2,3,4,6,7,8]:
        sides=[-1,1] if index in [3,8] else [1]
        for side in sides:
            region('sand-left' if side<0 else 'sand-right','bunker',ellipse(px+side*17,py-5,5.5,9))
    if index in [1,4,7]:
        region('deep-pocket','deepRough',ellipse(35,py*.5,12,20),10)
    if index in [2,8]:
        region('sea','water',rect(118,0,150,height),80)
        drops.append(dict(id='inland-drop',position=point(90,45),hazardID='sea'))
    if index==8:
        region('inlet','water',[point(104,py*.46),point(118,py*.42),point(118,py*.59),point(106,py*.56)],80)
    if index==5:
        riverY=30+distance*.69
        region('river-west','water',rect(0,riverY,94,riverY+18),80)
        region('river-east','water',rect(110,riverY,150,riverY+18),80)
        region('bridge-route','fairway',rect(90,riverY-25,114,riverY+35),30)
        drops.append(dict(id='near-bank',position=point(75,riverY-10),hazardID='river-west'))
    if index in [1,7]:
        for j,(x,y) in enumerate(dense[2:-2:3]):
            for side in [-1,1]:
                tx=x+side*(widths[index]/2+7)
                trees.append(dict(id=f'tree-{j}-{side}',position=point(tx,y),trunkRadius=.8,trunkHeight=5,canopyRadius=4.5,canopyBottom=3,canopyTop=11 if index==7 else 8))
    decorations=[dict(asset=assets[index],position=point(25 if px>55 else 105,py-8),scale=1.0)]
    if index==5: decorations.append(dict(asset='bridge',position=point(102,riverY+9),scale=1.0))
    for j in range(10):
        decorations.append(dict(asset='pine' if index==7 else 'tree',position=point(10 if j%2==0 else 139,18+j*(height-36)/10),scale=.8+(j%3)*.1))
    slope=[0,.005,.006,.008,.010,0,.015,.008,.012][index]
    gradient=point(0,6/(py-30)) if index==6 else point(0,0)
    doc=dict(schemaVersion=1,physicsVersion=2,contentVersion=1,id=h['id'],par=h['par'],
             bounds=dict(width=150,height=height),tee=point(*route[0]),pin=point(px,py),
             safeTarget=point(*route[min(1,len(route)-1)]),route=[point(x,y) for x,y in route],
             green=dict(center=point(px,py),radiusX=13 if index<6 else 11,radiusY=11 if index<6 else 9),
             fairway=fairway,wind=dict(speedMPH=winds[index][0],towardDegrees=winds[index][1]),
             greenSlope=point(slope*.4,-slope*.6),elevation=dict(origin=point(75,30),baseHeight=0,gradient=gradient),
             regions=regions,trees=trees,drops=drops,decorations=decorations,
             elevationPatches=[dict(center=point(75,py*.52),radius=60,height=-3),dict(center=point(75,py*.82),radius=45,height=2)] if index==4 else [])
    (APP_ROOT/f'Resources/Courses/Holes/{h["id"]}.json').write_text(json.dumps(doc,indent=2)+'\n')
    print(h['id'],round(length(route)/.9144,3),'yd')
