#!/usr/bin/env python3
"""Paiements silencieusement ignorés : reproduction et rollback du moteur privé."""
from pathlib import Path
import importlib.util,re,json,uuid,sys
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('filature',R/'outils/bancs/banc-filature-benediction-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MIGRATION='migrations/20261025011201_filature_confirmation_financiere.sql'
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK filature confirmation',msg,flush=True)
 def lire(sql,args=(),cur=q):cur.execute(sql,args or None);return cur.fetchone()[0]
 def appel(cle,cur=q):return lire('SELECT police_filature_commande(%s,%s)',('Autre',cle),cur)
 def position():q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET hp=100,pa=50,current_room='bureau_commissaire',current_building='commissariat' WHERE name='Fixture';UPDATE caisses_batiments SET data='{\"solde\":10000}' WHERE id='republic_commissariat_capitale';CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 1$$")
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c),(SELECT jsonb_agg(m ORDER BY id) FROM caisses_mouvements_clients m),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM police_filatures_recus r),(SELECT count(*) FROM acquisitions_transactions_internes))")
 position();q.execute("CREATE FUNCTION ignorer_finance_filature() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NULL;END$$;CREATE TRIGGER ignorer_finance_filature BEFORE UPDATE ON personnages_donnees FOR EACH ROW WHEN (NEW.name='Fixture' AND NEW.pa<OLD.pa) EXECUTE FUNCTION ignorer_finance_filature()")
 r=appel(str(uuid.uuid4()));check(r['ok'] and r['pa']==50 and r['paPreleves']==2 and r['solde_caisse']==9850,'defaut reproduit succes annonce avec PA ignores et caisse debitee')
 q.execute('DROP TRIGGER ignorer_finance_filature ON personnages_donnees');position()
 acl=lire("SELECT proacl::text FROM pg_proc WHERE oid='police_filature_commande(text,uuid)'::regprocedure")
 for _ in range(2):q.execute((R/MIGRATION).read_text())
 check(lire("SELECT proacl::text FROM pg_proc WHERE oid='police_filature_commande(text,uuid)'::regprocedure")==acl,'droits prives conserves par migration rejouable')
 if MUTANT:
  avant={'pa':"IF (SELECT pa FROM public.personnages_donnees WHERE id=p.id) IS DISTINCT FROM p.pa-site.pa THEN",'caisse':"IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id=site.caisse) IS DISTINCT FROM solde-site.cout THEN",'identite':"IF NOT FOUND OR p.user_id IS DISTINCT FROM auth.uid() THEN"}[MUTANT]
  d=lire("SELECT pg_get_functiondef('police_filature_commande(text,uuid)'::regprocedure)");assert d.count(avant)==1;q.execute(d.replace(avant,'IF false THEN'))
 # Nouveau bonus réel pour vérifier qu'un paiement incertain ne le consomme pas.
 q.execute("UPDATE personnages_donnees SET current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture'");r=lire('SELECT religion_benediction_demander(%s,%s)',('Père Ception',str(uuid.uuid4())));assert r['ok'] and r['succes'];position()
 for table,condition,raison in [('personnages_donnees',"NEW.name='Fixture' AND NEW.pa<OLD.pa",'paiement_filature_non_confirme'),('caisses_batiments',"NEW.id='republic_commissariat_capitale'",'caisse_filature_non_confirmee')]:
  q.execute(f'CREATE TRIGGER ignorer_finance_filature BEFORE UPDATE ON {table} FOR EACH ROW WHEN ({condition}) EXECUTE FUNCTION ignorer_finance_filature()');avant=photo()
  try:appel(str(uuid.uuid4()));raise AssertionError('ecriture ignoree acceptee')
  except psycopg2.Error as ex:check(raison in str(ex) and photo()==avant,'ecriture ignoree rollback complet '+raison)
  q.execute(f'DROP TRIGGER ignorer_finance_filature ON {table}')
 ancien=lire("SELECT user_id FROM personnages_donnees WHERE name='Fixture'");q.execute("UPDATE personnages_donnees SET user_id=gen_random_uuid() WHERE name='Fixture'");avant=photo();r=appel(str(uuid.uuid4()))
 check(r.get('raison')=='personnage_non_possede' and photo()==avant,'UID du compte authentifie requis meme avec nom et poste concordants')
 q.execute("UPDATE personnages_donnees SET user_id=%s WHERE name='Fixture'",(ancien,));cle=str(uuid.uuid4())
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(cle,cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'concurrence un paiement et un recu confirmes')
 r=rs[0];check(r['pa']==48 and r['solde_caisse']==9850 and r['bonus']==5,'PA caisse et bonus correspondent aux ecritures reelles')
 avant=photo();check(appel(cle)['rejeu'] and photo()==avant,'reponse perdue aucun nouvel effet')
 print(json.dumps({'filature_confirmation':True,'assertions':n,'client_raccorde':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.banque.m.main(tout)
