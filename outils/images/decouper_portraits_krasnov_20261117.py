#!/usr/bin/env python3
"""Krasnov : découpe exclusivement la planche définitive de 17 portraits validée par Fred.
N'utilise jamais l'ancienne planche à 18 personnages ni les générés à noms inventés.
L'image source a été vérifiée localement : 922x1825, SHA256 e16b41a7...
"""
from pathlib import Path
from hashlib import sha256
from PIL import Image, ImageOps
import json

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "images/Sovarka/Krasnov"
SHA_FINAL = "e16b41a7d971e8de670eb935851acac27de1eac3bd5800a298641bd849fc6e95"

# Ordre de la planche 3 colonnes × 6 rangées, dernière case vide.
# Ignat, Nina, Kouzma, Praskovia et tous les PNJ déjà illustrés SONT EXCLUS.
ROSTER = [
  ("Le Maire", "mairie", "bureau_maire_local", "le-maire"),
  ("Lieutenant Fiodor Doznaïev", "mairie", "salle_partis", "fiodor-doznaiev"),
  ("Egor Tikhonov", "commissariat-local", "bureau_commissaire", "egor-tikhonov"),
  ("Anatoli Gromov", "tribunal-local", "salle_audience_locale", "anatoli-gromov"),
  ("Directeur Platon Iermakov", "usine-principale", "direction_usine", "platon-iermakov"),
  ("Varvara Kozlova", "centre-commercial", "hall", "varvara-kozlova"),
  ("Efim Iakovlev", "centre-commercial", "hall", "efim-iakovlev"),
  ("Stas Mironov", "centre-artisanal", "travees", "stas-mironov"),
  ("Valentina Makhorkina", "tabac-presse-krasnov", "boutique", "valentina-makhorkina"),
  ("Stiopa « le Tambour » Ossipov", "stade", "siege_supporters", "stiopa-ossipov"),
  ("Fiodor Kolkhozov", "entrepot-logistique-krasnov", "bureau_direction", "fiodor-kolkhozov"),
  ("Stepan Kouznetsov", "maison-krasnov", "piece_maison", "stepan-kouznetsov"),
  ("Antonina Merkoulova", "maison-krasnov-bureaux", "piece_maison", "antonina-merkoulova"),
  ("Matveï Rybakov", "maison-krasnov-rouge", "piece_maison", "matvei-rybakov"),
  ("Galina Belova", "ferme-krasnov", "cour_ferme", "galina-belova"),
  ("Anatoli Pokhmelkine", "distillerie-krasnov", "bureau_direction", "anatoli-pokhmelkine"),
  ("Vassili Gradousov", "distillerie-krasnov", "atelier_distillerie", "vassili-gradousov")
]
assert len(ROSTER) == 17 and len(set(x[0] for x in ROSTER)) == 17
assert "Ignat" not in " ".join(x[0] for x in ROSTER)

sources = sorted(list(DIR.glob("Galerie des personnages de Krasnov*.png"))
                 + list(DIR.glob("Grille de portraits du village*.png")))
assert len(sources) == 2, f"Deux fichiers source attendus : {sources}"
for source in sources:
    print("SOURCE", source.name, sha256(source.read_bytes()).hexdigest(), flush=True)
matches = [p for p in sources if sha256(p.read_bytes()).hexdigest() == SHA_FINAL]
assert len(matches) == 1, (
    "La planche finale de 17 portraits n'est pas parmi les PNG chargés. "
    "Il faut charger exactement Krasnov_planche_17_portraits_sans_Ignat.png "
    "et ne pas utiliser une planche antérieure. Les sources restent intactes."
)
source = matches[0]
with Image.open(source) as im:
    im.load()
    assert im.size == (922, 1825), f"Format inattendu de la planche : {im.size}"
    assert im.mode in ("RGB","RGBA")
    # La dernière case (colonne 3, ligne 6) doit être vide.
    empty = im.crop((12+2*301+25,12+5*301+25,12+2*301+220,12+5*301+220)).convert("RGB")
    colors = empty.getcolors(maxcolors=5)
    assert colors is not None, "Dernière cellule non vide : planche à 18 portraits ?"
    for index, (name,building,room,slug) in enumerate(ROSTER):
        row,col = divmod(index,3)
        x,y=12+col*301,12+row*301
        # Le visage et les épaules seulement, sans cartouche de nom en bas.
        box=(x+25,y+5,x+271,y+226)
        crop=im.crop(box).convert("RGB")
        dest=DIR/f"Krasnov_portrait_{building}_{slug}.webp"
        assert not dest.exists(), f"Portrait existant : REFUS de l'écraser ({dest})"
        tile=ImageOps.fit(crop,(512,512),method=Image.Resampling.LANCZOS,centering=(.5,.42))
        tile.save(dest,"WEBP",quality=90,method=6)
        with Image.open(dest) as proof:
            assert proof.format=="WEBP" and proof.size==(512,512)
            proof.verify()
        assert dest.stat().st_size > 5000, str(dest)
        print("PORTRAIT",index,name,dest.name,dest.stat().st_size,flush=True)

data=ROOT/"data.js"
text=data.read_text(encoding="utf-8")
marker="// KRASNOV_PORTRAITS_MANQUANTS_20261117 (17 PNJ ; Ignat et photos existantes préservés)"
assert marker not in text, "Portraits déjà branchés, ne pas relancer le générateur"
rows=[]
for name,building,room,slug in ROSTER:
    exact=name+" (PNJ)"
    assert name in text, f"Nom de personnage non présent dans data.js : {name}"  # les noms des maisons sont assemblés au runtime
    path=f"images/Sovarka/Krasnov/Krasnov_portrait_{building}_{slug}.webp"
    rows.append("    ["+", ".join(json.dumps(v,ensure_ascii=False) for v in [building,room,exact,path])+"]")
# Même mécanisme de surcharge sûre que les portraits déjà implémentés en 20261116.
patch = marker+"""
(function () {
  const cite = WORLD.soviet && WORLD.soviet.ville_b;
  if (!cite) throw new Error('Krasnov absente');
  const portraits = [
"""+",\n".join(rows)+"""
  ];
  const dejaVus = new Set();
  for (const [batiment, piece, nom, photo] of portraits) {
    if (dejaVus.has(nom)) throw new Error('Portrait Krasnov en double : ' + nom);
    dejaVus.add(nom);
    const b = BUILDINGS[batiment];
    if (!b) throw new Error('Portrait Krasnov : bâtiment absent ' + batiment);
    const ctx = cite.buildingContext && cite.buildingContext[batiment];
    const ro = ctx && ctx.roomOverrides && ctx.roomOverrides[piece];
    const extra = ctx && ctx.roomsExtra && ctx.roomsExtra[piece];
    const premiere = Object.keys(b.rooms || {})[0];
    const liste = (ro && ro.persons)
      || (piece === premiere && ctx && ctx.persons && ctx.persons.length ? ctx.persons : null)
      || (extra && extra.persons)
      || (b.rooms && b.rooms[piece] && b.rooms[piece].persons) || [];
    const cibles = liste.filter(p => p.name === nom);
    if (cibles.length !== 1) throw new Error('Portrait Krasnov : PNJ absent ou doublé ' + nom + ' (' + batiment + '/' + piece + ')');
    if (cibles[0].photoUrl) throw new Error('Portrait Krasnov : photo EXISTANTE à conserver ' + nom);
    const copie = liste.map(p => p.name === nom
      ? Object.assign({}, p, { photoUrl: photo, photoPos: '50% 30%' })
      : Object.assign({}, p));
    if (!ctx) {
      const ailleurs = Object.entries(WORLD).some(([pays,villes]) =>
        Object.entries(villes || {}).some(([ville,c]) =>
          !(pays === 'soviet' && ville === 'ville_b')
          && c && Array.isArray(c.buildings) && c.buildings.includes(batiment)));
      if (ailleurs) throw new Error('Portrait Krasnov : bâtiment partagé sans contexte ' + batiment);
      b.rooms[piece].persons = copie;
    } else if (!(ro && ro.persons) && extra && extra.persons === liste) {
      ctx.roomsExtra = Object.assign({},ctx.roomsExtra);
      ctx.roomsExtra[piece] = Object.assign({},extra,{ persons:copie });
    } else {
      ctx.roomOverrides = Object.assign({},ctx.roomOverrides);
      ctx.roomOverrides[piece] = Object.assign({},ro || {},{ persons:copie });
    }
  }
})();
"""
text+="\n"+patch
data.write_text(text,encoding="utf-8")
# Uniquement après la validation des dix-sept WebP ET l'écriture du raccordement.
for f in sources:
    f.unlink()
print("OK 17 PORTRAITS : images WebP, raccordement, PNG supprimés",flush=True)
