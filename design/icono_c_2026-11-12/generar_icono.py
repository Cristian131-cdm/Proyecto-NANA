import sys
from PIL import Image, ImageFilter, ImageChops
src, out_full, out_fg = sys.argv[1:4]
im = Image.open(src).convert('RGB')
w, h = im.size
print('tamano', im.size)
# crema: promedio de las 4 esquinas
px = [im.getpixel(p) for p in [(8, 8), (w-9, 8), (8, h-9), (w-9, h-9)]]
crema = tuple(sum(c[i] for c in px)//4 for i in range(3))
print('crema #%02X%02X%02X' % crema, px)
im.resize((1024, 1024), Image.LANCZOS).save(out_full)

# Frente: quita el crema. Distancia de color al fondo -> alfa, y solo se
# borra lo que esta conectado al borde (no los blancos de adentro).
big = im.resize((1024, 1024), Image.LANCZOS)
diff = ImageChops.difference(big, Image.new('RGB', big.size, crema)).convert('L')
# umbral suave: <10 fondo, >34 mascota
mask = diff.point(lambda v: 0 if v < 10 else (255 if v > 34 else int((v-10)*255/24)))
# relleno desde las esquinas sobre la mascara binaria para hallar "afuera"
binm = mask.point(lambda v: 255 if v > 128 else 0)
from PIL import ImageDraw
flood = binm.copy()
for p in [(0, 0), (1023, 0), (0, 1023), (1023, 1023)]:
    ImageDraw.floodfill(flood, p, 128)
afuera = flood.point(lambda v: 255 if v == 128 else 0)
# adentro = todo lo que no es afuera -> opaco; el borde usa la mascara suave
adentro = ImageChops.invert(afuera)
adentro_erosion = adentro.filter(ImageFilter.MinFilter(7))
alfa = ImageChops.lighter(adentro_erosion, ImageChops.multiply(mask, adentro.filter(ImageFilter.MaxFilter(5))))
alfa = alfa.filter(ImageFilter.GaussianBlur(0.8))
rgba = big.convert('RGBA'); rgba.putalpha(alfa)
box = alfa.point(lambda v: 255 if v > 40 else 0).getbbox()
print('caja', box)
masc = rgba.crop(box)
lado = int(1024 * 0.66)
esc = lado / max(masc.size)
masc = masc.resize((round(masc.width*esc), round(masc.height*esc)), Image.LANCZOS)
lienzo = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
lienzo.paste(masc, ((1024-masc.width)//2, (1024-masc.height)//2), masc)
lienzo.save(out_fg)
# vista previa sobre el crema con mascara circular
prev = Image.new('RGBA', (1024, 1024), crema + (255,)); prev.alpha_composite(lienzo)
prev.convert('RGB').resize((400, 400)).save(out_fg.replace('.png', '_prev.png'))
