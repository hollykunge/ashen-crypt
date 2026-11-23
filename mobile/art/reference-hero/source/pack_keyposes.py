"""Register the two armor atlases to the game rig. Requires Pillow, NumPy, SciPy."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.spatial import Delaunay
from scipy.ndimage import map_coordinates
from slot_mask import outfit_slots

ROOT = Path(__file__).resolve().parent.parent
# Landmarks: topknot, brow, jaw, collar, shoulder, elbow, wrist, grip, guard,
# rear elbow/wrist/hand, sash, hips, knees, ankles and toes. Atlas coordinates
# are expressed on an 800 x 500 reference grid independent of export resolution.
TARGET = {
    'ready': [(325,124),(358,148),(354,182),(322,182),(278,201),(228,266),(253,304),(270,316),(295,311),(347,283),(377,316),(403,329),(304,297),(284,357),(210,469),(383,468),(184,521),(384,518),(179,555),(425,551)],
    'strike': [(388,148),(418,172),(412,202),(379,198),(402,220),(464,241),(524,244),(540,247),(557,247),(278,269),(248,299),(242,312),(349,314),(338,363),(230,473),(463,469),(193,520),(478,517),(177,555),(521,551)]
}
LANDMARKS = {
    ('leather','ready'): [(184,24),(216,54),(212,86),(180,85),(147,99),(110,167),(143,216),(156,230),(177,225),(221,189),(252,227),(274,243),(186,211),(173,270),(101,378),(252,378),(80,452),(260,449),(72,485),(292,485)],
    ('chain','ready'): [(200,23),(232,52),(228,89),(194,88),(163,100),(116,178),(141,219),(155,232),(178,228),(232,207),(261,238),(285,255),(188,214),(179,281),(109,379),(263,378),(83,454),(271,451),(77,485),(307,485)],
    ('leather','strike'): [(581,36),(605,63),(602,94),(574,92),(610,110),(642,143),(711,146),(724,147),(740,147),(490,172),(465,201),(455,218),(562,216),(552,275),(444,378),(664,379),(414,452),(680,449),(408,485),(709,485)],
    ('chain','strike'): [(573,40),(603,70),(597,100),(565,98),(611,117),(655,141),(703,144),(718,146),(737,146),(468,177),(447,207),(436,222),(548,215),(539,280),(444,377),(660,378),(413,454),(676,450),(406,485),(706,485)]
}
# The polygon boundaries follow wrists, elbows and trouser cuffs in each pose.
GLOVES = {
    'ready': [[(195,276),(231,263),(246,271),(260,289),(273,302),(287,337),(222,345)],[(345,297),(353,287),(410,309),(441,352),(378,358),(365,321)]],
    'strike': [[(478,210),(583,211),(584,277),(481,272)],[(228,310),(251,282),(264,262),(282,278),(270,297),(262,329),(224,336)]]
}
BOOTS = {
    'ready': [(110,466),(188,462),(228,482),(282,468),(359,479),(409,459),(472,460),(472,571),(110,571)],
    'strike': [(105,460),(210,462),(247,484),(301,482),(441,480),(486,457),(564,457),(564,572),(105,572)]
}
# Restore original identity, fingers and hilt with their original alpha.
IDENTITY = {
    'ready': [[(295,103),(389,104),(390,191),(355,192),(344,184),(337,199),(318,185),(314,172),(291,167)],[(214,329),(246,315),(252,305),(260,301),(276,306),(283,298),(321,288),(324,331),(279,335),(244,346),(213,349)],[(379,319),(387,314),(429,317),(432,355),(390,354),(378,331)]],
    'strike': [[(348,121),(450,120),(450,210),(419,211),(402,201),(377,198),(363,190),(351,182)],[(521,230),(531,230),(545,235),(551,223),(580,221),(582,271),(504,271),(503,257),(518,254)],[(217,305),(241,294),(254,293),(267,304),(279,310),(278,332),(214,336)]]
}

def mask(polygons):
    image = Image.new('L', (800,640))
    draw = ImageDraw.Draw(image)
    for polygon in polygons:
        draw.polygon(polygon, fill=255)
    return image

def register(atlas, style, pose):
    dst = list(TARGET[pose])
    src = list(LANDMARKS[style,pose])
    # Boundary anchors extrapolate local pose scale outside the silhouette.
    offset = 0 if pose == 'ready' else 400
    for x,y,u,v in [(70,55,-45,-55),(630,55,515,-55),(70,630,-45,577),(630,630,515,577)]:
        dst.append((x,y)); src.append((u+offset,v))
    tris = Delaunay(np.array(dst))
    y,x = np.indices((640,800))
    points = np.stack((x.ravel(),y.ravel()),axis=1)
    tri = tris.find_simplex(points)
    transform = tris.transform[tri]
    bary = np.einsum('nij,nj->ni',transform[:,:2],points-transform[:,2])
    weights = np.column_stack((bary,1-bary.sum(axis=1)))
    uv = np.einsum('ni,nij->nj',weights,np.array(src)[tris.simplices[tri]])
    valid = (tri>=0) & (uv[:,0] < 355 if pose=='ready' else uv[:,0]>375)
    coords = np.vstack((uv[:,1]*atlas.height/500,uv[:,0]*atlas.width/800))
    # Premultiplied interpolation avoids dark fringes at the original cut edge.
    pixels = np.asarray(atlas.convert('RGBa'))
    result = np.stack([map_coordinates(c,coords,order=1,mode='constant') for c in pixels.transpose(2,0,1)],axis=1)
    result[~valid]=0
    return Image.frombytes('RGBa',(800,640),result.tobytes()).convert('RGBA')

out = ROOT/'keyposes'
out.mkdir(exist_ok=True)
for pose in TARGET:
    cloth = Image.open(ROOT/'bodies'/'cloth'/(pose+'.png')).convert('RGBA')
    glove, boot = mask(GLOVES[pose]), mask([BOOTS[pose]])
    legs = [TARGET[pose][i:20:2] for i in (14, 15)]
    outfit_slots(glove, boot, legs).save(out/(pose+'-slots.png'))
    keep = mask(IDENTITY[pose]).filter(ImageFilter.GaussianBlur(.8))
    for style in ['chain','leather']:
        atlas = Image.open(ROOT/'source'/('keyposes-'+style+'.png'))
        armor = register(atlas,style,pose)
        Image.composite(cloth,armor,keep).save(out/(pose+'-'+style+'.png'))
