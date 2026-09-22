"""Generate adaptive launcher icon layers from assets/icon.png.

Outputs:
  assets/launcher/foreground.png  (1024x1024, logo at ~58% within safe zone)
  assets/launcher/background.png  (1024x1024, flat fill of the icon's own bg color)
  assets/launcher/mono.png        (432x432, white silhouette for themed icons)

Adaptive icon layers live on a 108x108dp canvas where only the middle
66x66dp is guaranteed visible; keeping the logo <=66/108 of the canvas
means no launcher mask can cut it off and no filler frames appear.
"""
from PIL import Image
import os

SRC = os.path.join(os.path.dirname(__file__), "..", "icon.png")
OUT = os.path.dirname(__file__)

im = Image.open(SRC).convert("RGBA")

# Trim uniform transparent padding so the logo fills the tile deterministically.
bbox = im.getchannel("A").getbbox()
im = im.crop(bbox)

# --- background: dominant color of dense (alpha>220) pixels -------------
small = im.resize((64, 64))
rs = gs = bs = n = 0
for r, g, b, a in small.getdata():
    if a > 220:
        rs += r
        gs += g
        bs += b
        n += 1
bg = (rs // n, gs // n, bs // n)
print("background: #%02X%02X%02X" % bg)

bg_img = Image.new("RGBA", (1024, 1024), bg + (255,))
bg_img.save(os.path.join(OUT, "background.png"))

# --- foreground: logo scaled to 58% of the 108dp canvas -----------------
canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
# 58% of 1024, expanded to a square around the logo center
side = int(1024 * 0.58)
w, h = im.size
if w >= h:
    nw, nh = side, max(1, round(h * side / w))
else:
    nw, nh = max(1, round(w * side / h)), side
logo = im.resize((nw, nh), Image.LANCZOS)
canvas.paste(logo, ((1024 - nw) // 2, (1024 - nh) // 2), logo)
fg_path = os.path.join(OUT, "foreground.png")
canvas.save(fg_path)

# --- monochrome: white silhouette, same geometry as foreground ----------
white = Image.new("RGBA", (nw, nh), (255, 255, 255, 255))
white.putalpha(mono_alpha := logo.getchannel("A"))
mono = Image.new("RGBA", (1024, 1024), (255, 255, 255, 0))
mono.paste(white, ((1024 - nw) // 2, (1024 - nh) // 2), white)
mono.save(os.path.join(OUT, "mono.png"))
print("done: foreground/background/mono written")
