# Redessine le bandeau « NOUVEAU PROPRIETAIRE » d'apres les mesures relevees sur
# l'image « moyen », seule du lot a l'avoir conserve, et le pose sur les trois
# autres. Le bandeau est un element graphique PLAT (un autocollant) : le
# redessiner donne un resultat identique sur les quatre, ce qu'un decoupage ne
# peut pas garantir -- le rouge du bandeau touche des pixels rougeatres du decor,
# et toute selection par couleur emporte des morceaux d'etagere.
#
# Mesures du modele (image 1536 x 1024) :
#   boite inclinee 326 x 140 px, angle -15,3 deg
#   -> bandeau reel ~322 x 57 px, soit 0,210 de la largeur de l'image
#   teinte moyenne #901420
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ANGLE        = 15.3            # PIL tourne dans le sens trigonometrique
LARGEUR_REL  = 0.210           # largeur du bandeau / largeur de l'image
RATIO_H      = 0.177           # hauteur / largeur du bandeau
FOND         = (144, 20, 32)   # #901420
BORD         = (255, 255, 255)
TEXTE        = "NOUVEAU PROPRIÉTAIRE"
FONTE        = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"

def bandeau(largeur_image):
    l = int(largeur_image * LARGEUR_REL)
    h = int(l * RATIO_H)
    marge = int(h * 0.55)                      # place pour l'ombre portee
    tuile = Image.new('RGBA', (l + marge*2, h + marge*2), (0,0,0,0))
    d = ImageDraw.Draw(tuile)
    x0, y0, x1, y1 = marge, marge, marge + l, marge + h
    r = int(h * 0.20)

    # ombre portee : une copie sombre, floutee, decalee
    ombre = Image.new('RGBA', tuile.size, (0,0,0,0))
    ImageDraw.Draw(ombre).rounded_rectangle([x0+h*0.10, y0+h*0.14, x1+h*0.10, y1+h*0.14],
                                            radius=r, fill=(0,0,0,110))
    ombre = ombre.filter(ImageFilter.GaussianBlur(h*0.09))
    tuile.alpha_composite(ombre)

    # lisere blanc, puis le fond bordeaux en retrait
    d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=BORD)
    e = max(2, int(h * 0.105))
    d.rounded_rectangle([x0+e, y0+e, x1-e, y1-e], radius=max(1, r-e//2), fill=FOND)

    # texte : on cherche la taille qui remplit la largeur utile
    utile = (x1-x0) - 2*e - int(h*0.24)
    taille = int(h * 0.74)
    while taille > 6:
        f = ImageFont.truetype(FONTE, taille)
        if d.textlength(TEXTE, font=f) <= utile: break
        taille -= 1
    f = ImageFont.truetype(FONTE, taille)
    tl = d.textlength(TEXTE, font=f)
    hb = f.getbbox(TEXTE)
    d.text(((x0+x1-tl)/2, (y0+y1)/2 - (hb[3]+hb[1])/2), TEXTE, font=f, fill=BORD)

    return tuile.rotate(ANGLE, resample=Image.BICUBIC, expand=True)

def poser(chemin, cx_rel, cy_rel):
    im = Image.open(chemin).convert('RGBA')
    b = bandeau(im.width)
    x = int(im.width * cx_rel - b.width/2)
    y = int(im.height * cy_rel - b.height/2)
    im.alpha_composite(b, (x, y))
    im.convert('RGB').save(chemin)
    return im.size, b.size

if __name__ == '__main__':
    import sys
    for arg in sys.argv[1:]:
        t, cx, cy = arg.split(':')
        c = f'images/luthecia-centre-commercial-{t}-local-loue.png'
        taille, bt = poser(c, float(cx), float(cy))
        print(f'  {t:6} image {taille[0]}x{taille[1]}  bandeau {bt[0]}x{bt[1]}  centre ({cx}, {cy})')
