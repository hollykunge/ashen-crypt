import json, sys
from PIL import Image, ImageDraw, ImageFont
man = json.load(open(sys.argv[1])); out = sys.argv[2]; title = sys.argv[3] if len(sys.argv) > 3 else ""
rows = man["rows"]; tags = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else {}; cell = 320; head = 40 if title else 0
cols = max(len(r) for r in rows)
sheet = Image.new("RGB", (cell*cols, head + cell*len(rows)), (220, 214, 204))
dr = ImageDraw.Draw(sheet)
try: font = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 16); tfont = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 22)
except Exception: font = tfont = ImageFont.load_default()
if title: dr.text((10, 8), title, fill=(30, 30, 30), font=tfont)
for y, r in enumerate(rows):
    for x, (label, p) in enumerate(r):
        sheet.paste(Image.open(p).convert("RGB"), (x*cell, head + y*cell))
        dr.rectangle([x*cell, head+y*cell, x*cell+cell-1, head+y*cell+24], fill=(235, 230, 222))
        dr.text((x*cell+6, head+y*cell+3), label, fill=(30, 30, 30), font=font)
        t = tags.get(label.split(" ")[0])
        if t and x == 0: dr.text((x*cell+8, head+y*cell+cell-30), t, fill=(150, 30, 20), font=font)
sheet.save(out, quality=88); print("SHEET", out, sheet.size)
