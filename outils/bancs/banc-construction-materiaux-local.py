#!/usr/bin/env python3
"""Fonctions réelles, PostgreSQL jetable, dépendances d'identité/réception simulées. Jamais Supabase."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,re,tempfile
R=Path(__file__).resolve().parents[2]
import runpy
_sources=runpy.run_path(str(R/'outils/bancs/banc-audit-securite-135-local.py'))
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-construction-'),cleanup_mode='delete')
 try:
  c=psycopg2.connect(serveur.get_uri());c.autocommit=True;q=c.cursor()
  q.execute('''CREATE ROLE anon; CREATE ROLE authenticated;
  CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,current_building text,arg integer,liquide integer,inventory jsonb,day integer DEFAULT 1,updated_at timestamptz DEFAULT now());
  CREATE TABLE comptes_bancaires(personnage text,banque text,solde numeric,updated_at timestamptz DEFAULT now(),PRIMARY KEY(personnage,banque));
  CREATE VIEW personnages AS SELECT * FROM personnages_donnees;
  CREATE TABLE terrains_etat(id text PRIMARY KEY,data text,updated_at timestamptz);
  CREATE TABLE ressources_economie(cle text PRIMARY KEY,prix_base numeric);
  CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF $1<>'Fixture' THEN RAISE EXCEPTION 'acteur_interdit'; END IF;END$$;
  CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT 'Fixture'::text$$;
  CREATE FUNCTION terrain_etat_lire(text) RETURNS jsonb LANGUAGE sql AS $$SELECT $1::jsonb$$;
  CREATE FUNCTION inventaire_reception_etat(text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('ok',true,'inventory',inventory) FROM personnages_donnees WHERE name=$1$$;
  INSERT INTO ressources_economie VALUES('bois',5),('minerai',10),('metal',15);
  INSERT INTO personnages_donnees VALUES('Fixture','republic','capitale','terrain',100,100,'[{"stackKey":"bois","stackable":true,"qty":20}]',1,now());
  INSERT INTO terrains_etat VALUES('republic_terrain','{"city":"capitale","proprietaire":"Fixture","chantier":{"dureeJours":6,"progressionJours":1,"tresorerie":100,"stockMateriaux":{}}}',now());''')
  q.execute(_sources['entree_historique']('vendre_materiaux_chantier'))
  q.execute("CREATE TABLE chantiers_paliers(palier text PRIMARY KEY,apport_minimal numeric,cout_total numeric,gabarit jsonb)")
  q.execute("INSERT INTO chantiers_paliers VALUES('hangar',10500,30000,'{\"niveau\":\"hangar\",\"dureeJours\":6,\"progressionJours\":0}')")
  q.execute(_sources['entree_historique']('helvetia_debiter_fonds_ordinaires'))
  q.execute(_sources['entree_historique']('chantier_lancer'))
  migration=_sources['chemin_source']('migrations/20261031113610_construction_materiaux_prix_et_dons.sql').read_text();q.execute(migration);q.execute(migration)
  q.execute("INSERT INTO terrains_etat VALUES('republic_nouveau','{\"city\":\"capitale\",\"proprietaire\":\"Fixture\",\"constructionAutorisee\":true,\"permis\":{\"palierDemande\":\"hangar\"}}',now())")
  q.execute("UPDATE personnages_donnees SET arg=20000,liquide=20000")
  q.execute("SELECT chantier_lancer('Fixture','republic','nouveau','hangar',10500)");lancement=q.fetchone()[0]
  assert lancement['ok'] and lancement['chantier']['prixAchatPJ']=={'bois':6,'minerai':11,'metal':17}
  q.execute("UPDATE ressources_economie SET prix_base=100 WHERE cle='bois'")
  q.execute("SELECT data::jsonb->'chantier'->'prixAchatPJ' FROM terrains_etat WHERE id='republic_nouveau'");assert q.fetchone()[0]['bois']==6
  q.execute("SELECT chantier_lancer('Fixture','republic','nouveau','hangar',10500)");assert q.fetchone()[0]['raison']=='chantier_en_cours'
  q.execute("SELECT liquide FROM personnages_donnees");assert q.fetchone()[0]==9500
  q.execute("UPDATE ressources_economie SET prix_base=5 WHERE cle='bois'")
  q.execute("UPDATE personnages_donnees SET arg=100,liquide=100")
  def appel(requete,qty=2,prix=1,cur=q):
   cur.execute('SELECT vendre_materiaux_chantier(%s,%s,%s,%s,%s,%s,%s)',('Fixture','republic','terrain','bois',qty,prix,requete));return cur.fetchone()[0]
  def etat():
   q.execute("SELECT arg,liquide,inventory FROM personnages_donnees");pj=q.fetchone();q.execute("SELECT data::jsonb FROM terrains_etat WHERE id='republic_terrain'");return pj,q.fetchone()[0]
  v=appel('vente-001');assert v['ok'] and v['montant']==12 and v['prixUnitaire']==6;assert etat()[0][:2]==(112,112)
  avant=etat();assert appel('vente-001')['rejeu'];assert etat()==avant
  assert appel('vente-001',qty=4)['raison']=='requete_reutilisee';assert etat()==avant
  q.execute("UPDATE ressources_economie SET prix_base=100 WHERE cle='bois'")
  assert appel('vente-002',qty=1)['montant']==6;assert etat()[0][:2]==(118,118)
  q.execute("UPDATE ressources_economie SET prix_base=5 WHERE cle='bois'")
  v=appel('don-00001',qty=1,prix=0);assert v['ok'] and v['montant']==0;assert etat()[0][:2]==(118,118)
  for matiere,prix_attendu in [('minerai',11),('metal',17)]:
   q.execute("UPDATE personnages_donnees SET inventory=%s",(json.dumps([{'stackKey':matiere,'stackable':True,'qty':1}]),))
   q.execute("SELECT vendre_materiaux_chantier('Fixture','republic','terrain',%s,1,1,%s)",(matiere,'prix-'+matiere));v=q.fetchone()[0]
   assert v['ok'] and v['prixUnitaire']==prix_attendu and v['montant']==prix_attendu
  q.execute("UPDATE personnages_donnees SET inventory='[{\"stackKey\":\"bois\",\"stackable\":true,\"qty\":20}]'")
  for prix_invalide in ['1.50','1.5','1.00','-1','NaN','Infinity']:
   avant=etat();q.execute("SELECT chantier_prix_definir('terrain',%s)",(json.dumps({'bois':prix_invalide}),));assert not q.fetchone()[0]['ok'];assert etat()==avant
  q.execute("SELECT chantier_prix_definir('terrain','{\"bois\":null}')");assert not q.fetchone()[0]['ok']
  q.execute("SELECT chantier_prix_definir('terrain','{\"bois\":\"1.001\"}')");assert not q.fetchone()[0]['ok']
  q.execute("SELECT chantier_prix_definir('terrain','{\"bois\":\"2\"}')");assert q.fetchone()[0]['ok']
  assert appel('prix-001',qty=1,prix=999)['montant']==2 # le vendeur ne fixe jamais son prix
  avant=etat();q.execute("SELECT chantier_prix_definir('terrain','{\"bois\":1.5}')");assert not q.fetchone()[0]['ok'];assert etat()==avant
  q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,prixAchatPJ,bois}','1.5')::text WHERE id='republic_terrain'");avant=etat()
  assert appel('fraction-historique',qty=1)['raison']=='prix_indisponible';assert etat()==avant
  q.execute("SELECT chantier_prix_definir('terrain','{\"bois\":2}')");assert q.fetchone()[0]['ok']

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
  # Comparaison avant/apres : meme helper historique, memes soldes, meme priorite liquide.
  cas=[(100,0,40),(50,80,100),(0,100,40),(0,0,0),(0,0,1),(20,0,21)]
  def configurer(liquide,banque):
   q.execute("UPDATE personnages_donnees SET liquide=%s,arg=%s",(liquide,liquide+banque))
   q.execute("INSERT INTO comptes_bancaires(personnage,banque,solde) VALUES('Fixture','nationale',%s) ON CONFLICT(personnage,banque) DO UPDATE SET solde=excluded.solde",(banque,))
  def soldes():
   q.execute("SELECT arg,liquide,(SELECT solde FROM comptes_bancaires WHERE personnage='Fixture' AND banque='nationale') FROM personnages_donnees WHERE name='Fixture'");return q.fetchone()
  references=[]
  for liq,banque,montant in cas:
   configurer(liq,banque);q.execute("SELECT helvetia_debiter_fonds_ordinaires('Fixture',%s)",(montant,));references.append((q.fetchone()[0],soldes()))
  financement=_sources['chemin_source']('migrations/20261031113611_construction_lancement_priorite_bancaire.sql').read_text();q.execute(financement);q.execute(financement)
  for (liq,banque,montant),reference in zip(cas,references):
   configurer(liq,banque);q.execute("SELECT helvetia_debiter_fonds_ordinaires('Fixture',%s)",(montant,));assert (q.fetchone()[0],soldes())==reference
  for liq,banque,montant,attendu in [(100,100,40,(160,100,60)),(50,80,100,(30,30,0)),(20,80,101,(100,20,80)),(100,0,40,(60,60,0))]:
   configurer(liq,banque);q.execute("SELECT helvetia_debiter_fonds_ordinaires('Fixture',%s,'nationale')",(montant,));assert q.fetchone()[0]==(liq+banque>=montant);assert soldes()==attendu
  q.execute("SELECT has_function_privilege('authenticated','public.helvetia_debiter_fonds_ordinaires(text,numeric,text)','EXECUTE')");assert q.fetchone()[0] is False
  configurer(10000,5000)
  q.execute("INSERT INTO terrains_etat VALUES('republic_banque','{\"city\":\"capitale\",\"proprietaire\":\"Fixture\",\"constructionAutorisee\":true,\"permis\":{\"palierDemande\":\"hangar\"}}',now())")
  q.execute("SELECT chantier_lancer('Fixture','republic','banque','hangar',10500)");assert q.fetchone()[0]['ok'];assert soldes()==(4500,4500,0)
  q.execute("SELECT chantier_lancer('Fixture','republic','banque','hangar',10500)");assert not q.fetchone()[0]['ok'];assert soldes()==(4500,4500,0)
  configurer(10000,5000);avant=soldes()
  q.execute("INSERT INTO terrains_etat VALUES('republic_panne','{\"city\":\"capitale\",\"proprietaire\":\"Fixture\",\"constructionAutorisee\":true,\"permis\":{\"palierDemande\":\"hangar\"}}',now())")
  q.execute("CREATE FUNCTION panne_terrain() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.id='republic_panne' THEN RAISE EXCEPTION 'panne_apres_debit_fixture';END IF;RETURN NEW;END$$; CREATE TRIGGER panne_terrain BEFORE UPDATE ON terrains_etat FOR EACH ROW EXECUTE FUNCTION panne_terrain()")
  try:q.execute("SELECT chantier_lancer('Fixture','republic','panne','hangar',10500)");raise AssertionError('rollback de lancement attendu')
  except psycopg2.Error as e:assert 'panne_apres_debit_fixture' in str(e)
  assert soldes()==avant
  q.execute("SELECT data::jsonb ? 'chantier' FROM terrains_etat WHERE id='republic_panne'");assert not q.fetchone()[0]
  configurer(10,10);avant=soldes()
  q.execute("INSERT INTO terrains_etat VALUES('republic_refus','{\"city\":\"capitale\",\"proprietaire\":\"Fixture\",\"constructionAutorisee\":true,\"permis\":{\"palierDemande\":\"hangar\"}}',now())")
  q.execute("SELECT chantier_lancer('Fixture','republic','refus','hangar',10500)");assert q.fetchone()[0]['raison']=='fonds_insuffisants';assert soldes()==avant
  q.execute("SELECT data::jsonb ? 'chantier' FROM terrains_etat WHERE id='republic_refus'");assert not q.fetchone()[0]
  configurer(10,10);q.execute("UPDATE comptes_bancaires SET solde=10.5");avant=soldes()
  try:q.execute("SELECT helvetia_debiter_fonds_ordinaires('Fixture',1,'nationale')");raise AssertionError('fraction historique a refuser')
  except psycopg2.Error as e:assert 'etat_financier_non_entier' in str(e)
  assert soldes()==avant
  q.execute("CREATE OR REPLACE FUNCTION vendre_materiaux_chantier(p_vendeur text,p_country text,p_building_id text,p_matiere text,p_quantite integer,p_prix integer) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$")
  try:q.execute(migration);raise AssertionError('garde attendue')
  except psycopg2.Error as e:assert 'definition_non_examinee' in str(e)
  c.close();print('Groupes PostgreSQL réussis : prix initiaux figes au lancement et arrondis au franc superieur, dons, refus des fractions, rejeu, concurrence, rollback, territoire, droits, garde de source, financement bancaire prioritaire et compatibilite historique. Dépendances simulées, aucun Supabase.')
 finally:serveur.cleanup()
if __name__=='__main__':main()
