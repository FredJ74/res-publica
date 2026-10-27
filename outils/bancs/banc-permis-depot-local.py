#!/usr/bin/env python3
"""#94 : PostgreSQL jetable, fonctions archivees reelles, identite/calendrier simules."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import re,tempfile,json
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-permis-'),cleanup_mode='delete')
 try:
  c=psycopg2.connect(serveur.get_uri());c.autocommit=True;q=c.cursor()
  q.execute('''CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT '00000000-0000-4000-8000-000000000001'::uuid$$;
  CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT 'Fixture'::text$$;
  CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF $1 IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'identite';END IF;END$$;
  CREATE FUNCTION titulaire_est_moi(text) RETURNS boolean LANGUAGE sql AS $$SELECT coalesce($1=mon_personnage(),false)$$;
  CREATE FUNCTION jour_de_jeu_pays(text) RETURNS integer LANGUAGE sql AS $$SELECT 20$$;
  CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,pa integer,liquide integer,arg integer);
  CREATE TABLE comptes_bancaires(id text,personnage text,banque text,solde numeric,updated_at timestamptz);
  CREATE TABLE ordres_couts(fn text,pa integer,cost integer,UNIQUE(fn,pa,cost));
  CREATE TABLE ordres_couts_inconnus(fn text PRIMARY KEY,pa integer,cost integer,occurrences integer DEFAULT 1);
  CREATE TABLE ordres_couts_ecarts(fn text,pa integer,cost integer,occurrences integer DEFAULT 1,vu_le timestamptz,UNIQUE(fn,pa,cost));
  CREATE TABLE presidence_memoire_ordres(fn text,pa integer,cost integer,sujet text);
  CREATE FUNCTION presidence_memoire_noter(text,text,text,text,jsonb,text) RETURNS void LANGUAGE sql AS $$SELECT$$;
  CREATE TABLE terrains_etat(id text PRIMARY KEY,country text,building_id text,proprietaire text,data text,updated_at timestamptz);
  CREATE TABLE dossiers_urbanisme(id text PRIMARY KEY,country text,city text,building_id text,numero_dossier text,type_evenement text,demandeur text,jour integer,libelle text,data jsonb);
  CREATE TABLE objets_recus(id text PRIMARY KEY,destinataire text,expediteur text,data jsonb);
  CREATE TABLE vols_en_attente(id text,type_butin text,victime text,voleur text,objet jsonb);
  INSERT INTO personnages_donnees VALUES('Fixture','republic','capitale',10,1000,1000);
  INSERT INTO ordres_couts VALUES('deposer_demande_permis',2,0);
  INSERT INTO terrains_etat VALUES('republic_terrain','republic','terrain','Fixture','{"city":"capitale","proprietaire":"Fixture","surface":900}',now());''')
  def charger(path,fn):
   src=(R/path).read_text();a=src.index('CREATE OR REPLACE FUNCTION public.'+fn+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);q.execute(src[a:a+m.end()])
  for fn in ['terrain_etat_verrouiller_interne','terrain_etat_fusionner_interne']:
   charger('baseline/domaines/immobilier-et-territoire/20_fonctions.sql',fn)
  charger('outils/bancs/banc-fixture-terrain-permis-acte-avant-depot.sql','terrain_permis_acte')
  charger('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre')
  charger('baseline/domaines/socle/20_fonctions.sql','objet_sas_deposer')
  charger('baseline/domaines/socle/20_fonctions.sql','titulaire_est_moi')
  sql=(R/'migrations/20261022220516_permis_depot_transactionnel.sql').read_text();q.execute(sql)  # une reinstallation volontaire est refusee par l'empreinte de la RPC modifiee
  # Une archive de depot ne peut etre ajoutee directement par un joueur.
  try:
   q.execute("INSERT INTO dossiers_urbanisme(id,country,type_evenement,data) VALUES('faux-depot','republic','depot','{}')")
   raise AssertionError('archive non protegee')
  except psycopg2.Error as erreur:
   assert 'depot_permis_commande_versionnee_requise' in str(erreur)
  q.execute("SELECT count(*) FROM dossiers_urbanisme WHERE id='faux-depot'")
  assert q.fetchone()[0]==0
  n=0
  def check(ok):
   nonlocal n
   assert ok;n+=1
  def appel(k=1,palier='hangar',cur=q):
   cur.execute('SELECT terrain_permis_deposer(%s,%s,%s)',('terrain',palier,f'00000000-0000-4000-8000-{k:012d}'));return cur.fetchone()[0]
  def snapshot():
   q.execute("SELECT pa,liquide,arg FROM personnages_donnees");p=q.fetchone();q.execute("SELECT data FROM terrains_etat ORDER BY id");t=q.fetchall()
   q.execute('SELECT (SELECT count(*) FROM dossiers_urbanisme),(SELECT count(*) FROM objets_recus),(SELECT count(*) FROM permis_depots_recus),(SELECT count(*) FROM permis_transactions_internes)');return p,t,q.fetchone()
  def terrain(**kw):
   d={'city':'capitale','surface':900,'proprietaire':'Fixture'};d.update(kw);q.execute("UPDATE terrains_etat SET data=%s WHERE id='republic_terrain'",(json.dumps(d),))
  avant=snapshot();r=appel();check(r['ok']);check(snapshot()[0]==(9,900,900));check(snapshot()[2]==(1,1,1,0));check(r['etat']['permis']['decoupageInitial']==[])
  avant=snapshot();check(appel()['rejeu']);check(snapshot()==avant);check(appel(palier='building')['raison']=='requete_reutilisee');check(snapshot()==avant)
  check(appel(2)['raison']=='permis_existant');check(snapshot()==avant)
  q.execute("SELECT payer_ordre('Fixture','deposer_demande_permis',1,100)");check(q.fetchone()[0]['raison']=='commande_versionnee_requise');check(snapshot()==avant)
  q.execute("SELECT terrain_permis_acte('terrain','permis_deposer','{\"permis\":{}}')");check(q.fetchone()[0]['raison']=='commande_versionnee_requise');check(snapshot()==avant)
  terrain(proprietaire='Autre',compromis=True,compromisPar='Fixture',compromisExpireAt=4102444800000)
  check(appel(3,'building')['ok']);check(snapshot()[0]==(8,800,800));check(appel(3,'building')['document']['palier']=='building')
  q.execute("SELECT data::jsonb->'permis'->>'dureeInstruction' FROM terrains_etat");check(q.fetchone()[0]=='7')
  for i,patch,raison in [
   (4,{'proprietaire':'Autre'},'pas_titulaire'),
   (5,{'proprietaire':'Autre','compromis':True,'compromisPar':'Fixture','compromisExpireAt':1},'compromis_expire'),
   (6,{'proprietaire':'Autre','compromis':True,'compromisPar':'Autre','compromisExpireAt':4102444800000},'pas_titulaire'),
   (7,{'proprietaire':'Autre','compromis':True,'compromisPar':'Fixture'},'compromis_expiration_inconnue'),
   (8,{'city':'ailleurs'},'hors_juridiction'),(9,{'succession_gel':'dossier'},'terrain_gele'),
   (10,{'niveau_construction':'hangar'},'deja_construit'),(11,{'permis':{'statut':'refuse','jourRefus':18}},'cooldown_refus')]:
   terrain(**patch);avant=snapshot();check(appel(i)['raison']==raison);check(snapshot()==avant)
  terrain();q.execute('UPDATE personnages_donnees SET pa=0');avant=snapshot();check(appel(12)['raison']=='pa_insuffisants');check(snapshot()==avant)
  q.execute('UPDATE personnages_donnees SET pa=10,liquide=0,arg=0');avant=snapshot();check(appel(13)['raison']=='fonds_insuffisants');check(snapshot()==avant)
  q.execute('UPDATE personnages_donnees SET liquide=1000,arg=1000')
  # Vrai moteur documentaire : une panne d'insertion SAS doit annuler paiement, permis ET archive.
  q.execute("CREATE FUNCTION panne() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_sas';END$$;CREATE TRIGGER panne BEFORE INSERT ON objets_recus FOR EACH ROW EXECUTE FUNCTION panne()")
  avant=snapshot()
  try:appel(14);raise AssertionError('exception attendue')
  except psycopg2.Error as e:check('panne_sas' in str(e))
  check(snapshot()==avant);q.execute('DROP TRIGGER panne ON objets_recus')
  def concurrent(_):
   with psycopg2.connect(serveur.get_uri()) as cc:return appel(15,cur=cc.cursor())
  with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(concurrent,range(2)))
  check(all(x['ok'] for x in rr));check(sum(bool(x.get('rejeu')) for x in rr)==1);check(snapshot()[0]==(9,900,900))
  q.execute("SELECT has_table_privilege('authenticated','permis_transactions_internes','INSERT'),has_table_privilege('authenticated','permis_depots_recus','INSERT'),has_function_privilege('anon','terrain_permis_deposer(text,text,uuid)','EXECUTE')");check(q.fetchone()==(False,False,False))
  # Une archive fabriquée ne peut pas servir de recu de paiement.
  terrain();q.execute("INSERT INTO dossiers_urbanisme(id,data) VALUES('urb-depot-00000000-0000-4000-8000-000000000001-00000000-0000-4000-8000-000000000016','{}')")
  avant=snapshot()
  try:appel(16);raise AssertionError('collision attendue')
  except psycopg2.Error as e:check(e.pgcode=='23505')
  check(snapshot()==avant)
  # Proprietaire type pj:, complement bancaire et refus sans debit partiel.
  terrain(proprietaire='pj:Fixture');q.execute("UPDATE personnages_donnees SET liquide=25,arg=125;INSERT INTO comptes_bancaires VALUES('compte','Fixture','nationale',100,now())")
  check(appel(17)['ok']);check(snapshot()[0]==(8,0,25))
  q.execute("SELECT solde FROM comptes_bancaires");check(q.fetchone()[0]==25)
  terrain();avant=snapshot();check(appel(18)['raison']=='fonds_insuffisants');check(snapshot()==avant)
  q.execute("UPDATE personnages_donnees SET pa=10,liquide=1000,arg=1025")
  terrain(permis={'statut':'refuse','jourRefus':17});check(appel(19)['ok'])
  # Rejouer un ancien recu renvoie les soldes actuels, pas ceux du debit historique.
  q.execute("UPDATE personnages_donnees SET liquide=777,arg=802")
  r=appel(19);check(r['rejeu'] and r['paiement']['liquide']==777)
  terrain();avant=snapshot();check(appel(20,'inconnu')['raison']=='palier_invalide');check(snapshot()==avant)
  # Une definition non examinee fait echouer toute la migration, sans affaiblissement.
  q.execute("CREATE OR REPLACE FUNCTION payer_ordre(p_acteur text,p_fn text DEFAULT NULL,p_pa integer DEFAULT 0,p_cost integer DEFAULT 0) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$")
  try:q.execute(sql);raise AssertionError('garde attendue')
  except psycopg2.Error as e:check('definition_non_examinee' in str(e));q.execute('ROLLBACK')
  print(json.dumps({'ok':True,'assertions':n,'production':False,'identite':'simulee','fonctions':'payeur,terrain,document reels archives'}))
 finally:serveur.cleanup()
if __name__=='__main__':main()

