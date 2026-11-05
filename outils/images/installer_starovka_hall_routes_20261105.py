#!/usr/bin/env python3
"""Starovka: convert three PNGs, connect station, hotel and reindeer farm."""
from pathlib import Path
from PIL import Image, ImageOps
from tempfile import TemporaryDirectory
import shutil

ROOT=Path(__file__).resolve().parents[2]
IMG=ROOT/'images/Sovarka/Starovka'
FILES=('Starovka_gare_hall','Starovka_rue_hotel','Starovka_maisons_ferme')

def change(path,old,new):
    p=ROOT/path
    src=p.read_text(encoding='utf-8')
    if src.count(old)!=1: raise RuntimeError(f'{path}: expected one anchor, found {src.count(old)}')
    p.write_text(src.replace(old,new,1),encoding='utf-8')

# Validate ALL the conversions before removing any source.
with TemporaryDirectory() as tmp:
    prepared=[]
    for basename in FILES:
        original=IMG/(basename+'.png')
        dest=IMG/(basename+'.webp')
        if dest.exists() and not original.exists():
            with Image.open(dest) as im:
                assert im.format=='WEBP'
                im.verify()
            continue
        if not original.is_file() or dest.exists(): raise RuntimeError(f'Conflicting image: {basename}')
        work=Path(tmp)/(basename+'.webp')
        with Image.open(original) as im:
            rgb=ImageOps.exif_transpose(im).convert('RGB')
            dims=rgb.size
            rgb.save(work,'WEBP',quality=85,method=6)
        with Image.open(work) as im:
            assert im.format=='WEBP' and im.size==dims
            im.verify()
        assert work.stat().st_size>100
        prepared.append((original,dest,work))
    for original,dest,work in prepared:
        shutil.copy2(work,dest)
        with Image.open(dest) as im:
            assert im.format=='WEBP'
            im.verify()
    for original,_,_ in prepared: original.unlink()

old="""    // STAROVKA — ouverture de la navigation par la gare de fret.
    // La sortie basse sera raccordée à la prochaine illustration : flèche visible,
    // non cliquable pour ne pas inventer une destination côté serveur.
    'starovka-rue-gare': {
      image: 'images/Sovarka/Starovka/Starovka_rue_gare.webp',
      zones: [],
      liens: { toutDroit: 'starovka-rue-port-industriel' },
      liensEnAttente: { arriere: true },
      flechesStyle: {
        toutDroit: RC_FLECHE_HAUT,
        arriere: RC_FLECHE_BAS
      }
    },

    // PORT INDUSTRIEL — terminaison de la carte, retour unique vers la gare.
    'starovka-rue-port-industriel': {
      image: 'images/Sovarka/Starovka/Starovka_rue_port industriel.webp',
      zones: [],
      liens: { arriere: 'starovka-rue-gare' },
      flechesStyle: { arriere: RC_FLECHE_BAS }
    },"""
new="""    // Starovka : la gare utilise le transport et les pièces du socle partagé.
    'starovka-rue-gare': {
      image: 'images/Sovarka/Starovka/Starovka_rue_gare.webp',
      zones: [
        { xPct: [0, 43], yPct: [6, 77], nom: 'Gare de Starovka', type: 'batiment', buildingId: 'centre-multinodal-montrouge' }
      ],
      liens: { toutDroit: 'starovka-rue-port-industriel', arriere: 'starovka-rue-hotel' },
      flechesStyle: { toutDroit: RC_FLECHE_HAUT, arriere: RC_FLECHE_BAS }
    },

    // Port industriel : seul retour vers la gare.
    'starovka-rue-port-industriel': {
      image: 'images/Sovarka/Starovka/Starovka_rue_port industriel.webp',
      zones: [],
      liens: { arriere: 'starovka-rue-gare' },
      flechesStyle: { arriere: RC_FLECHE_BAS }
    },

    'starovka-rue-hotel': {
      image: 'images/Sovarka/Starovka/Starovka_rue_hotel.webp',
      zones: [],
      liens: { toutDroit: 'starovka-rue-gare', arriere: 'starovka-maisons-ferme' },
      flechesStyle: { toutDroit: RC_FLECHE_HAUT, arriere: RC_FLECHE_BAS }
    },

    'starovka-maisons-ferme': {
      image: 'images/Sovarka/Starovka/Starovka_maisons_ferme.webp',
      zones: [],
      liens: { toutDroit: 'starovka-rue-hotel' },
      flechesStyle: { toutDroit: RC_FLECHE_HAUT }
    },"""
change('plateau-rue-centrale.js',old,new)
old="""      buildingContext: {
        'hotel-republica': {
          name: "Baraquement Sibirsk-9","""
new="""      buildingContext: {
        'centre-multinodal-montrouge': {
          name: "Gare de Starovka",
          desc: "Gare ferroviaire de la ville portuaire de Starovka.",
          roomOverrides: {
            hall_gare_montrouge: {
              name: "Hall de la gare de Starovka",
              desc: "Un hall chauffé par un poêle, avec son guichet et ses voyageurs.",
              imageUrl: "images/Sovarka/Starovka/Starovka_gare_hall.webp",
              personsVides: true
            }
          }
        },
        'hotel-republica': {
          name: "Baraquement Sibirsk-9","""
change('data.js',old,new)

sql="""-- Starovka : liens tenus par le serveur et sortie du hall de gare.
DO $starovka$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
      WHERE pays='soviet' AND ville='ville_a'
        AND batiment='centre-multinodal-montrouge'
        AND pieces ? 'hall_gare_montrouge')
  THEN RAISE EXCEPTION 'starovka_hall_gare_non_reference'; END IF;

  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES
    ('soviet','ville_a','starovka-rue-gare',
      ARRAY['starovka-rue-port-industriel','starovka-rue-hotel']::text[],
      '{"liens":{"toutDroit":"starovka-rue-port-industriel","arriere":"starovka-rue-hotel"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-rue-hotel',
      ARRAY['starovka-rue-gare','starovka-maisons-ferme']::text[],
      '{"liens":{"toutDroit":"starovka-rue-gare","arriere":"starovka-maisons-ferme"},"parArrivee":{}}'::jsonb),
    ('soviet','ville_a','starovka-maisons-ferme',
      ARRAY['starovka-rue-hotel']::text[],
      '{"liens":{"toutDroit":"starovka-rue-hotel"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO UPDATE
    SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

  INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
  VALUES ('soviet','ville_a','starovka-rue-gare','centre-multinodal-montrouge')
  ON CONFLICT DO NOTHING;
  IF NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments
      WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-gare'
        AND building='centre-multinodal-montrouge')
  THEN RAISE EXCEPTION 'starovka_sortie_gare_non_referencee'; END IF;
END $starovka$;
"""
(ROOT/'migrations/20261105234500_starovka_gare_hotel_ferme.sql').write_text(sql,encoding='utf-8')

p=ROOT/'outils/bancs/test-starovka-gare-port-20261105.mjs'
t=p.read_text()
for a,b in [
  ("test('Starovka : gare en entrée, port terminus et flèche basse en attente'","test('Starovka : gare en entrée, port terminus et hôtel raccordé'"),
  ("assert.deepEqual(Object.keys(result.gare.liens), ['toutDroit']);","assert.deepEqual(Object.keys(result.gare.liens), ['toutDroit','arriere']);"),
  ("assert.equal(result.gare.liensEnAttente.arriere, true);","assert.equal(result.gare.liens.arriere,'starovka-rue-hotel');")
]:
    if t.count(a)!=1: raise RuntimeError(f'test anchor missing: {a}')
    t=t.replace(a,b)
p.write_text(t)

test="""import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
test('Starovka : gare, hôtel, ferme, port et hall bidirectionnels',()=>{
  const ctx=vm.createContext({console,state:{country:'soviet',currentCity:'ville_a'}});
  vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
  vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
  const got=vm.runInContext(`({
    gare:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-gare'],
    hotel:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-hotel'],
    ferme:RUE_CENTRALE_NOEUDS.soviet['starovka-maisons-ferme'],
    port:RUE_CENTRALE_NOEUDS.soviet['starovka-rue-port-industriel'],
    contexte:WORLD.soviet.ville_a.buildingContext['centre-multinodal-montrouge'],
    sortie:noeudRueDuBatiment('soviet','centre-multinodal-montrouge')
  })`,ctx);
  assert.equal(got.gare.liens.arriere,'starovka-rue-hotel');
  assert.equal(got.gare.liens.toutDroit,'starovka-rue-port-industriel');
  assert.equal(got.hotel.liens.toutDroit,'starovka-rue-gare');
  assert.equal(got.hotel.liens.arriere,'starovka-maisons-ferme');
  assert.equal(got.ferme.liens.toutDroit,'starovka-rue-hotel');
  assert.equal(got.port.liens.arriere,'starovka-rue-gare');
  assert.equal(got.gare.zones[0].buildingId,'centre-multinodal-montrouge');
  assert.equal(got.sortie,'starovka-rue-gare');
  assert.equal(got.contexte.roomOverrides.hall_gare_montrouge.imageUrl,'images/Sovarka/Starovka/Starovka_gare_hall.webp');
  for(const node of [got.gare,got.hotel,got.ferme,got.port])
    assert.ok(fs.statSync(path.join(root,node.image)).size>100,node.image);
  assert.ok(fs.statSync(path.join(root,got.contexte.roomOverrides.hall_gare_montrouge.imageUrl)).size>100);
  assert.deepEqual(fs.readdirSync(path.join(root,'images/Sovarka/Starovka')).filter(n=>n.endsWith('.png')),[]);
});
"""
(ROOT/'outils/bancs/test-starovka-hall-hotel-ferme-20261105.mjs').write_text(test,encoding='utf-8')
assert not list(IMG.glob('*.png'))
print('STAROVKA conversion and wiring completed')
