#!/usr/bin/env python3
"""Deux actes différents, un état privé commun et des reçus qui ne le réactivent pas."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,uuid,json
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('chasse',R/'outils/bancs/banc-chasse-benediction-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK inter hotes',msg,flush=True)
 def lire(s,args=(),cur=q):cur.execute(s,args or None);return cur.fetchone()[0]
 q.execute((R/'migrations/20261025011201_filature_confirmation_financiere.sql').read_text())
 q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET hp=100,pa=50,country='republic',current_city='capitale',current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture';UPDATE caisses_batiments SET data='{\"solde\":10000}' WHERE id='republic_commissariat_capitale';CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 1$$;INSERT INTO jugements(id,country,city,accuse,motif,jour,data) VALUES('inter-hotes-fixture','republic','capitale','Autre','Fixture',200,'{\"motifs\":[{\"jours\":3}]}')")
 def bonus():
  q.execute("UPDATE personnages_donnees SET current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture'");r=lire('SELECT religion_benediction_demander(%s,%s)',('Père Ception',str(uuid.uuid4())));assert r['ok'] and r['succes'];q.execute("UPDATE personnages_donnees SET current_building='commissariat',current_room='bureau_commissaire' WHERE name='Fixture'");return r
 generation=bonus()['benediction'];pa=lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")
 cles={f:str(uuid.uuid4()) for f in ['police_filature_commande','police_chasse_commande']}
 def appel(f,cle=None,cur=q):return lire('SELECT '+f+'(%s,%s)',('Autre',cle or cles[f]),cur)
 def concurrent(f):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(f,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,list(cles)))
 check(all(r['ok'] and r['succes'] for r in rs),'filature et chasse concurrentes reussissent par leurs moteurs respectifs')
 check(sorted(r['bonus'] for r in rs)==[0,5],'deux familles ne consomment pas deux fois la meme generation')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==pa-5 and lire("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id='republic_commissariat_capitale'")==9550,'cout total exact de deux ordres distincts deux plus trois PA et 450 FR')
 check(lire("SELECT count(*) FROM religion_benedictions_consommations c JOIN religion_benedictions b USING(acteur) WHERE c.demande=b.demande AND c.bonus=5")==1,'un seul journal de consommation pour la generation commune')
 check(lire("SELECT executee FROM jugements WHERE id='inter-hotes-fixture'"),'condamnation executee une fois dans le meme calendrier')
 bonus();courant=lire('SELECT religion_benediction_lire()');pa=lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")
 for f in cles:check(appel(f)['rejeu'],'relecture du recu '+f)
 check(lire('SELECT religion_benediction_lire()')==courant and courant['benediction']['actif'],'anciens recus ne consomment pas le nouveau bonus')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==pa and lire("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id='republic_commissariat_capitale'")==9550,'relecture apres nouveau bonus sans nouveau paiement')
 # Un même UUID présenté à une autre famille n'est pas un nouvel acte autorisé.
 cle=str(uuid.uuid4());r=appel('police_filature_commande',cle);assert r['ok']
 photo=lire("SELECT jsonb_build_array((SELECT pa FROM personnages_donnees WHERE name='Fixture'),(SELECT data FROM caisses_batiments WHERE id='republic_commissariat_capitale'),(SELECT count(*) FROM police_chasses_recus),(SELECT count(*) FROM religion_benedictions_consommations))")
 # Nouvelle condamnation valide : ne pas faire passer ce test seulement grâce au refus de cible.
 lire("SELECT detention_clore_interne('Autre','fixture_fin')");q.execute("INSERT INTO jugements(id,country,city,accuse,motif,jour,data) VALUES('inter-hotes-uuid-fixture','republic','capitale','Autre','Fixture',201,'{\"motifs\":[{\"jours\":3}]}')")
 try:appel('police_chasse_commande',cle);raise AssertionError('UUID inter famille accepte')
 except psycopg2.Error as ex:
  apres=lire("SELECT jsonb_build_array((SELECT pa FROM personnages_donnees WHERE name='Fixture'),(SELECT data FROM caisses_batiments WHERE id='republic_commissariat_capitale'),(SELECT count(*) FROM police_chasses_recus),(SELECT count(*) FROM religion_benedictions_consommations))")
  check('acte_benediction_deja_traite' in str(ex) and apres==photo,'UUID reutilise dans une autre famille refuse sans depense ni execution')
 check(not lire("SELECT executee FROM jugements WHERE id='inter-hotes-uuid-fixture'"),'refus inter famille laisse la condamnation executable')
 print(json.dumps({'inter_hotes':True,'assertions':n,'client_raccorde':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.base.base.banque.m.main(tout)
