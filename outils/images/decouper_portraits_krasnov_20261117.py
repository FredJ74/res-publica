#!/usr/bin/env python3
"""Krasnov : pose uniquement les 19 portraits manquants, avec sources contrôlées par SHA256.
N'utilise jamais l'ancienne planche à 18 personnages ni les générés à noms inventés.
Les 17 portraits de la planche finale et deux nouveaux portraits sont fournis en ZIP contrôlé.
"""
from pathlib import Path
from hashlib import sha256
from PIL import Image, ImageOps
from zipfile import ZipFile
import json

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "images/Sovarka/Krasnov"

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
  ("Vassili Gradousov", "distillerie-krasnov", "atelier_distillerie", "vassili-gradousov"),
  ("Receptionniste", "hotel-mineur", "hall_mineur", "receptionniste"),
  ("Caporal Ilia Sorokine", "station-radar-krasnov", "salle_ecoute", "ilia-sorokine")
]
assert len(ROSTER) == 19 and len(set(x[0] for x in ROSTER)) == 19
assert "Ignat" not in " ".join(x[0] for x in ROSTER)

# ZIP final de 19 WebP contrôlé par empreinte et par noms exacts.
# Le ZIP ne contient aucun autre nom ni personnage déjà illustré.
zip_source=DIR/"Krasnov_19_portraits_WebP.zip"
ZIP_SHA="984355c8d8981254eee3af259a28f88113d429a3c407ea59d7aa738d25d3e9c3"
sources=sorted(list(DIR.glob("Galerie des personnages de Krasnov*.png"))
               + list(DIR.glob("Grille de portraits du village*.png"))
               + list(DIR.glob("Krasnov_planche_17_portraits_sans_Ignat.png")))
to_delete=list(sources)
if zip_source.exists():
    assert sha256(zip_source.read_bytes()).hexdigest()==ZIP_SHA, "ZIP inattendu : SHA256 incorrect"
    to_delete.append(zip_source)
    expected={
        f"images/Sovarka/Krasnov/Krasnov_portrait_{building}_{slug}.webp"
        for _,building,_,slug in ROSTER
    }
    with ZipFile(zip_source) as archive:
        assert set(archive.namelist())==expected, (
            "Liste ZIP non conforme aux 19 noms exacts du jeu",archive.namelist()
        )
        for entry in sorted(expected):
            dest=ROOT/entry
            assert not dest.exists(), f"Refus de remplacer une photo existante : {dest}"
            dest.write_bytes(archive.read(entry))
            with Image.open(dest) as proof:
                assert proof.format=="WEBP" and proof.size==(512,512),entry
                proof.verify()
            assert dest.stat().st_size>5000,entry
            print("PORTRAIT",entry,dest.stat().st_size,flush=True)
else:
    raise AssertionError("Le ZIP final des 19 portraits n'est pas présent ; les deux anciens PNG sont incorrects.")

data=ROOT/"data.js"
text=data.read_text(encoding="utf-8")
marker="// KRASNOV_PORTRAITS_MANQUANTS_20261117 (19 PNJ ; Ignat et photos existantes préservés)"
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
    cite.buildingContext = cite.buildingContext || {};
    const ctx = cite.buildingContext[batiment] = cite.buildingContext[batiment] || {};
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
    if (!(ro && ro.persons) && extra && extra.persons === liste) {
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
# Uniquement après la validation des dix-neuf WebP ET l'écriture du raccordement.
for f in to_delete:
    f.unlink()
print("OK 19 PORTRAITS : images WebP, raccordement, PNG supprimés",flush=True)
