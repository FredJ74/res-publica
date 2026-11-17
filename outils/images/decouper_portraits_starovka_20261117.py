#!/usr/bin/env python3
"""Découpe contrôlée des portraits de Starovka depuis la planche déposée sur GitHub."""
from pathlib import Path
from PIL import Image, ImageOps
import re

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "images/Sovarka/Starovka"
sources = list(DIR.glob("Galerie de portraits*.png"))
assert len(sources) == 1, f"Planche attendue unique, trouvé : {sources}"
source = sources[0]
labels = [
    ("Damdin Mazoutov", "usine-principale", "direction_usine", "damdin-mazoutov"),
    ("Bayar Otchirov", "centre-artisanal", "travees", "bayar-otchirov"),
    ("Ganbold Garmaïev", "centre-artisanal", "travees", "ganbold-garmaiev"),
    ("Temür Dougarov", "centre-artisanal", "travees", "temur-dougarov"),
    ("Meneur des Supporters", "stade", "siege_supporters", "meneur-supporters"),
    ("Saran Batbayar", "presse-starovka", "presse", "saran-batbayar"),
    ("Dolgor Tsybikova", "maison-starovka", "piece_maison", "dolgor-tsybikova"),
    ("Zorigto Badmaev", "maison-starovka-ouvrier", "piece_maison", "zorigto-badmaev"),
    ("Bair Sambuev", "ferme-starovka", "cour_ferme", "bair-sambuev"),
]
outputs=[]
with Image.open(source) as im:
    im.load()
    w,h=im.size
    assert w>=900 and h>=600, f"Planche trop petite {w}x{h}"
    ratio=w/h
    assert .9<ratio<1.9, f"Planche 3×3 attendue {w}x{h}"
    tw,th=w/3,h/3
    for i, (name,building,room,slug) in enumerate(labels):
        col,row=i%3,i//3
        # Zone carrée centrée sur le visage, au-dessus du cartouche de nom
        side=min(tw*.67,th*.68)
        cx=(col+.5)*tw
        cy=row*th+th*.38
        box=(round(cx-side/2),round(cy-side/2),round(cx+side/2),round(cy+side/2))
        assert box[0]>=0 and box[1]>=0 and box[2]<=w and box[3]<=h
        portrait=im.crop(box).convert("RGB").resize((512,512),Image.Resampling.LANCZOS)
        dest=DIR/f"Starovka_portrait_{building}_{slug}.webp"
        portrait.save(dest,"WEBP",quality=87,method=6)
        outputs.append((name,building,room,dest))
        print("IMAGE",name,dest.relative_to(ROOT),box,dest.stat().st_size)
# Le sergent est représenté au bureau de droite dans la scène du centre d'écoute.
# Recadrage de la photographie existante : PAS de génération d'un nouveau visage.
sergent=DIR/"Starovka_centre_ecoute_salle.webp"
assert sergent.is_file(),sergent
with Image.open(sergent) as im:
    im.load()
    w,h=im.size
    # Opérateur assis au bureau de droite, seul visage exploitable.
    box=(round(w*.62),round(h*.31),round(w*.82),round(h*.65))
    crop=im.crop(box).convert("RGB")
    portrait=ImageOps.fit(crop,(512,512),method=Image.Resampling.LANCZOS,centering=(.5,.38))
    dest=DIR/"Starovka_portrait_poste-vigilance-glaciale_bair-dorjiev.webp"
    portrait.save(dest,"WEBP",quality=87,method=6)
    outputs.append(("Sergent Bair Dorjiev","poste-vigilance-glaciale","salle_ecoute",dest))
    print("IMAGE Sergent Bair Dorjiev",dest.relative_to(ROOT),box,dest.stat().st_size)

for name,building,room,dest in outputs:
    with Image.open(dest) as verify:
        verify.verify()
    assert dest.stat().st_size>5000,f"Image suspecte : {dest}"

data=ROOT/"data.js"
src=data.read_text(encoding="utf-8")
marker="// STAROVKA_PORTRAITS_MANQUANTS_20261117 — planche contrôlée après inventaire"
assert marker not in src,"Déjà raccordé"
for name,building,room,dest in outputs:
    assert name in src,f"Personnage absent de data.js : {name}"
items=",\n".join(
    f"    [{building!r}, {room!r}, {name+' (PNJ)'!r}, {'images/Sovarka/Starovka/'+dest.name!r}]"
    for name,building,room,dest in outputs
)
append=marker+"""
// 9 visages issus de la planche GitHub, plus le sergent recadré depuis son décor.
// Pas de modification des portraits préexistants (bookmaker, secrétaire, etc.).
(function () {
  const ville = WORLD.soviet && WORLD.soviet.ville_a;
  if (!ville) throw new Error('Starovka absente');
  const portraits = [
"""+items+"""
  ];
  for (const [batiment, piece, nom, url] of portraits) {
    const original = BUILDINGS[batiment];
    if (!original || !original.rooms || !original.rooms[piece]) {
      throw new Error('Portrait Starovka : pièce absente ' + batiment + '/' + piece);
    }
    const ctx = ville.buildingContext && ville.buildingContext[batiment];
    const ro = ctx && ctx.roomOverrides && ctx.roomOverrides[piece];
    const extra = ctx && ctx.roomsExtra && ctx.roomsExtra[piece];
    const liste = (ro && ro.persons) || (extra && extra.persons)
      || (original.rooms[piece] && original.rooms[piece].persons) || [];
    if (!liste.some(p => p.name === nom)) {
      throw new Error('Portrait Starovka : PNJ absent ' + nom + ' ' + batiment + '/' + piece);
    }
    const nouvelle = liste.map(p => p.name === nom
      ? Object.assign({}, p, { photoUrl: url, photoPos: '50% 30%' })
      : Object.assign({}, p));
    if (!ctx) {
      // Construction exclusivement utilisée par Starovka.
      const utiliseAilleurs = Object.entries(WORLD).some(([pays, villes]) =>
        Object.entries(villes || {}).some(([villeId, v]) =>
          !(pays === 'soviet' && villeId === 'ville_a')
          && Array.isArray(v && v.buildings) && v.buildings.includes(batiment)));
      if (utiliseAilleurs) throw new Error('Portrait Starovka : bâtiment partagé sans contexte ' + batiment);
      original.rooms[piece].persons = nouvelle;
    } else if (extra && extra.persons === liste && !(ro && ro.persons)) {
      ctx.roomsExtra = Object.assign({},ctx.roomsExtra);
      ctx.roomsExtra[piece] = Object.assign({},extra,{ persons:nouvelle });
    } else {
      ctx.roomOverrides = Object.assign({},ctx.roomOverrides);
      ctx.roomOverrides[piece] = Object.assign({},ro || {},{ persons:nouvelle });
    }
  }
})();
"""
# La fonction de résolution exige une salle du gabarit, même pour roomsExtra.
# Le stade utilise une salle roomsExtra boutique, mais nos cibles ne sont pas en boutique.
src+="\n"+append
data.write_text(src,encoding="utf-8")
# Source d'origine devenue inutile dans le dépôt, supprimée seulement après les 10 vérifications.
source.unlink()
print("OK: 10 photos WebP vérifiées, data.js raccordé, planche PNG supprimée")
