#!/usr/bin/env python3
"""Pièces dynamiques : la subdivision persistante, pas une copie de catalogue."""
import importlib.util,re,sys,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('amb',R/'outils/bancs/banc-groupes-ambassades-local.py');amb=importlib.util.module_from_spec(sp);sp.loader.exec_module(amb)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']];a=amb.rondes.interieur.natif.rue.force.corps.g.audit
 q.execute('SELECT to_regclass(\'public.terrains_etat\')');existe=q.fetchone()[0]
 if not existe:
  s=(R/'baseline/domaines/immobilier-et-territoire/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.terrains_etat \(.*?\n\);',s,re.S)[0])
 q.execute(a.fonction('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','terrain_etat_lire'))
 migration=(R/'migrations/20261028193500_navigation_lots_dynamiques.sql').read_text();
 if '--contre-lots' not in sys.argv:q.execute(migration);q.execute(migration)
 sql("INSERT INTO rue_sorties_batiments VALUES('republic','capitale','immeuble-fixture','rue-1')")
 ctx['c'].commit()
 def terrain(lots,ville='capitale',pays='republic'):
  q.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('terrain-fixture',%s,'immeuble-fixture','C',%s)",(pays,json.dumps({'city':ville,'subdivisions':lots})))
 def dedans(piece='lot_dyn_lot-1'):return rpc('navigation_interieure',('immeuble-fixture',piece),qui='B')
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d');return q.fetchone()[0]
 def visite():
  terrain([{'id':'lot-1','surface':40,'locataire':'A','label':'Commerce'}]);exige(dedans())
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_room='lot_dyn_lot-1'");assert q.fetchone()[0]==2
  q.execute("SELECT proprietaire,data FROM terrains_etat WHERE id='terrain-fixture'");p,d=q.fetchone();assert p=='C' and json.loads(d)['subdivisions'][0]['locataire']=='A'
 cas('lot_persistant_visitable_sans_modifier_propriete_ni_bail',visite)
 def refus(lots,piece='lot_dyn_lot-1',ville='capitale',pays='republic'):
  terrain(lots,ville,pays);avant=photo();exige(dedans(piece),'destination_inconnue');assert photo()==avant
 cas('lot_invente_refuse',lambda:refus([{'id':'autre'}]))
 cas('lot_autre_ville_refuse',lambda:refus([{'id':'lot-1'}],ville='ville_a'))
 cas('lot_autre_pays_refuse',lambda:refus([{'id':'lot-1'}],pays='soviet'))
 cas('lot_identites_assainies_ambigues_refusees',lambda:refus([{'id':'a b'},{'id':'a?b'}],piece='lot_dyn_a_b'))
 def renomme():
  terrain([{'id':'lot-1','label':'Avant'}]);exige(dedans())
  q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{subdivisions,0,label}','\"Après\"')::text")
  exige(dedans())
 cas('lot_renomme_conserve_identite_piece',renomme)
 if suivante is not None:suivante(ctx)

if __name__=='__main__':
 rondes=amb.rondes;interieur=rondes.interieur;natif=interieur.natif;rue=natif.rue;f=rue.force
 sys.exit(f.corps.g.main(lambda c:f.corps.extension(c,lambda c:f.suite(c,lambda c:rue.suite(c,lambda c:natif.suite(c,lambda c:interieur.suite(c,lambda c:rondes.suite(c,lambda c:amb.suite(c,suite)))))))))
