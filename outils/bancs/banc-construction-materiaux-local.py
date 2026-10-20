#!/usr/bin/env python3
"""Fonctions réelles, PostgreSQL jetable, dépendances d'identité/réception simulées. Jamais Supabase."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,re,tempfile
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-construction-'),cleanup_mode='delete')
 try:
  c=psycopg2.connect(serveur.get_uri());c.autocommit=True;q=c.cursor()
  q.execute('''CREATE ROLE anon; CREATE ROLE authenticated;
  CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,current_building text,arg integer,liquide integer,inventory jsonb);
  CREATE VIEW personnages AS SELECT * FROM personnages_donnees;
  CREATE TABLE terrains_etat(id text PRIMARY KEY,data text,updated_at timestamptz);
  CREATE TABLE ressources_economie(cle text PRIMARY KEY,prix_base numeric);
  CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF $1<>'Fixture' THEN RAISE EXCEPTION 'acteur_interdit'; END IF;END$$;
  CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT 'Fixture'::text$$;
  CREATE FUNCTION terrain_etat_lire(text) RETURNS jsonb LANGUAGE sql AS $$SELECT $1::jsonb$$;
  CREATE FUNCTION inventaire_reception_etat(text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('ok',true,'inventory',inventory) FROM personnages_donnees WHERE name=$1$$;
  INSERT INTO ressources_economie VALUES('bois',5),('minerai',10),('metal',15);
  INSERT INTO personnages_donnees VALUES('Fixture','republic','capitale','terrain',100,100,'[{"stackKey":"bois","stackable":true,"qty":20}]');
  INSERT INTO terrains_etat VALUES('republic_terrain','{"city":"capitale","proprietaire":"Fixture","chantier":{"dureeJours":6,"progressionJours":1,"tresorerie":100,"stockMateriaux":{}}}',now());''')
  src=(R/'baseline/domaines/economie/20_fonctions-2.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.vendre_materiaux_chantier(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);q.execute(src[a:a+m.end()])
  migration=next((R/'migrations').glob('*_construction_materiaux_prix_et_dons.sql')).read_text();q.execute(migration);q.execute(migration)
  def appel(requete,qty=2,prix=1,cur=q):
   cur.execute('SELECT vendre_materiaux_chantier(%s,%s,%s,%s,%s,%s,%s)',('Fixture','republic','terrain','bois',qty,prix,requete));return cur.fetchone()[0]
  def etat():
   q.execute("SELECT arg,liquide,inventory FROM personnages_donnees");pj=q.fetchone();q.execute("SELECT data::jsonb FROM terrains_etat");return pj,q.fetchone()[0]
  v=appel('vente-001');assert v['ok'] and v['montant']=='11.00' and v['prixUnitaire']=='5.50';assert etat()[0][:2]==(111,111)
  avant=etat();assert appel('vente-001')['rejeu'];assert etat()==avant
  assert appel('vente-001',qty=4)['raison']=='requete_reutilisee';assert etat()==avant
  assert appel('vente-002',qty=1)['raison']=='precision_monetaire_requise';assert etat()==avant
  v=appel('don-00001',qty=1,prix=0);assert v['ok'] and v['montant']=='0.00';assert etat()[0][:2]==(111,111)
  q.execute("SELECT chantier_prix_definir('terrain','{\"bois\":null}')");assert not q.fetchone()[0]['ok']
  q.execute("SELECT chantier_prix_definir('terrain','{\"bois\":\"1.001\"}')");assert not q.fetchone()[0]['ok']
  q.execute("SELECT chantier_prix_definir('terrain','{\"bois\":\"2.00\"}')");assert q.fetchone()[0]['ok']
  assert appel('prix-001',qty=1,prix=999)['montant']=='2.00' # le vendeur ne fixe jamais son prix
  q.execute("UPDATE personnages_donnees SET current_city='ailleurs'");avant=etat();assert not appel('ville-001')['ok'];assert etat()==avant
  q.execute("UPDATE personnages_donnees SET current_city='capitale'")
  q.execute("CREATE OR REPLACE FUNCTION inventaire_reception_etat(text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{\"ok\":false}'::jsonb$$")
  avant=etat()
  try:appel('panne-001');raise AssertionError('rollback attendu')
  except psycopg2.Error as e:assert 'inventaire_non_confirme' in str(e)
  assert etat()==avant
  q.execute("CREATE OR REPLACE FUNCTION inventaire_reception_etat(text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{\"ok\":true}'::jsonb$$")
  def concurrent(_):
   with psycopg2.connect(serveur.get_uri()) as cc:return appel('concurrent-001',qty=1,cur=cc.cursor())
  avant=etat()[0][0]
  with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(concurrent,range(2)))
  assert all(v['ok'] for v in results) and sum(bool(v.get('rejeu')) for v in results)==1;assert etat()[0][0]==avant+2
  q.execute("SELECT has_function_privilege('authenticated','public.vendre_materiaux_chantier(text,text,text,text,integer,integer)','EXECUTE'),has_function_privilege('authenticated','public.vendre_materiaux_chantier(text,text,text,text,integer,integer,text)','EXECUTE')");assert q.fetchone()==(False,True)
  q.execute("CREATE OR REPLACE FUNCTION vendre_materiaux_chantier(p_vendeur text,p_country text,p_building_id text,p_matiere text,p_quantite integer,p_prix integer) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$")
  try:q.execute(migration);raise AssertionError('garde attendue')
  except psycopg2.Error as e:assert 'definition_non_examinee' in str(e)
  c.close();print('14 groupes PostgreSQL réussis : prix, dons, centimes, rejeu, concurrence, rollback, territoire, droits et garde de source. Dépendances simulées, aucun Supabase.')
 finally:serveur.cleanup()
if __name__=='__main__':main()
