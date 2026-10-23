#!/usr/bin/env python3
"""Negociation #94 : vrais verrous PostgreSQL et payeurs communs, identites fictives."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import re, tempfile, json
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver, psycopg2
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-nego-'),cleanup_mode='delete')
 try:
  c=psycopg2.connect(srv.get_uri());c.autocommit=True;q=c.cursor()
  q.execute('''CREATE ROLE anon;CREATE ROLE authenticated;
  CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT coalesce(nullif(current_setting('hg.acteur',true),''),'Fixture') $$;
  CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF $1 IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'identite'; END IF;END $$;
  CREATE TABLE personnages_donnees(id uuid DEFAULT gen_random_uuid() PRIMARY KEY,name text UNIQUE,country text,current_city text,current_building text,
   stats jsonb,excommunie jsonb,stats_affaiblies jsonb,hp integer,pa integer,moral integer,liquide integer,arg integer,updated_at timestamptz);
  CREATE TABLE comptes_bancaires(id text PRIMARY KEY,personnage text,banque text,solde numeric,updated_at timestamptz);
  CREATE TABLE terrains_etat(id text PRIMARY KEY,country text,building_id text,proprietaire text,data text,updated_at timestamptz);
  CREATE TABLE indices_villes(id text,data jsonb);
  CREATE TABLE pnj_membres(id text,proprietaire_pj text,leader_pj text,statut text,car_cha integer);
  CREATE TABLE pnj_employes_metier(pnj_id text);
  CREATE TABLE organisations(id text,data text);
  CREATE TABLE ordres_couts(fn text,pa integer,cost integer);
  CREATE TABLE ordres_couts_inconnus(fn text PRIMARY KEY,pa integer,cost integer,occurrences integer DEFAULT 1);
  CREATE TABLE ordres_couts_ecarts(fn text,pa integer,cost integer,occurrences integer DEFAULT 1,vu_le timestamptz,UNIQUE(fn,pa,cost));
  CREATE TABLE presidence_memoire_ordres(fn text,pa integer,cost integer,sujet text);
  CREATE FUNCTION presidence_memoire_noter(text,text,text,text,jsonb,text) RETURNS void LANGUAGE sql AS $$ SELECT $$;
  INSERT INTO personnages_donnees(name,country,current_city,current_building,stats,hp,pa,moral,liquide,arg)
   VALUES('Fixture','republic','capitale','terrain-a-batir-1','{"CHA":13}',100,30,50,200,10200),
    ('Autre','republic','capitale','terrain-a-batir-1','{"CHA":13}',100,30,50,200,10200);
  INSERT INTO comptes_bancaires VALUES('c1','Fixture','nationale',10000,now()),('c2','Autre','nationale',10000,now());
  INSERT INTO terrains_etat VALUES('republic_terrain-a-batir-1','republic','terrain-a-batir-1',NULL,
   '{"city":"capitale","pnj":"squatter_cool","dateGeneration":1,"surface":2150}',now());
  INSERT INTO ordres_couts VALUES('negocier_squatteurs',1,0);
  INSERT INTO indices_villes VALUES('republic_capitale','{"social":50}');''')
  def charger(path,fn,tous=False):
   s=(R/path).read_text();matches=list(re.finditer(r'CREATE OR REPLACE FUNCTION public\.'+fn+r'\(',s))
   for x in matches if tous else matches[:1]:
    m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[x.start():],re.S);q.execute(s[x.start():x.start()+m.end()])
  for fn in ['terrain_etat_lire','terrain_etat_fusionner_interne']:charger('baseline/domaines/immobilier-et-territoire/20_fonctions.sql',fn)
  charger('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre')
  charger('migrations/20261020222029_construction_lancement_priorite_bancaire.sql','helvetia_debiter_fonds_ordinaires',True)
  sql=(R/'migrations/20261023225617_squatteurs_negociation_transactionnelle.sql').read_text();q.execute(sql);q.execute(sql)
  n=0
  def check(v):
   nonlocal n
   assert v;n+=1
  def contexte(cur=q):
   cur.execute("SELECT terrain_negociation_preparer('terrain-a-batir-1')");return cur.fetchone()[0]
  def appel(k,montant=500,occupation='1:squatter_cool',cur=q):
   cur.execute("SELECT terrain_negociation_conclure('terrain-a-batir-1',%s,%s,%s)",(occupation,montant,f'00000000-0000-4000-8000-{k:012d}'));return cur.fetchone()[0]
  def jet(v):q.execute(f'CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$ SELECT {v} $$')
  def etat(**patch):
   e={'city':'capitale','pnj':'squatter_cool','dateGeneration':1,'surface':2150};e.update(patch)
   q.execute('UPDATE terrains_etat SET data=%s',(json.dumps(e),))
  def snapshot():
   q.execute('SELECT name,pa,moral,liquide,arg FROM personnages_donnees ORDER BY name');p=q.fetchall()
   q.execute('SELECT solde FROM comptes_bancaires ORDER BY id');b=q.fetchall()
   q.execute('SELECT data::jsonb FROM terrains_etat');t=q.fetchone()[0]
   q.execute('SELECT (SELECT count(*) FROM terrain_negociations_recus),(SELECT count(*) FROM terrain_negociations_refus)');return p,b,t,q.fetchone()
  check(contexte()['baseTaux']==50);check(contexte()['minimum']==1)
  jet(100);r=appel(1);check(r['ok'] and not r['accepte']);check(r['paiement']['pa']==29)
  check(r['paiement']['arg']==10200 and r['paiement']['liquide']==200 and r['paiement']['moral']==50)
  check(contexte()['minimum']==501 and contexte()['dernierRefus']==500)
  avant=snapshot();check(appel(1)['rejeu']);check(snapshot()==avant)
  for montant in [1,499,500]:check(appel(2,montant)['raison']=='offre_trop_faible');check(snapshot()==avant)
  check(appel(1,501)['raison']=='requete_reutilisee');check(snapshot()==avant)
  jet(1);r=appel(3,501);check(r['ok'] and r['accepte']);check(r['bonusMoral']==1)
  check(r['paiement']=={'pa':28,'arg':9699,'liquide':0,'solde_national':9699,'moral':51})
  check(r['etat']['pnj'] is None and r['etat']['occupationScellee'] and r['etat']['surface']==2150)
  avant=snapshot();check(appel(3,501)['rejeu']);check(snapshot()==avant)
  check(appel(4,600)['raison']=='aucun_squatteur');check(snapshot()==avant)
  etat(pnj='squatter_agr',dateGeneration=2);check(contexte()['minimum']==500)
  avant=snapshot();check(appel(5,500)['raison']=='occupation_modifiee');check(snapshot()==avant)
  check(appel(5,499,'2:squatter_agr')['raison']=='offre_trop_faible');check(snapshot()==avant)
  r=appel(5,500,'2:squatter_agr');check(r['accepte'] and r['bonusMoral']==0 and r['paiement']['moral']==51)
  etat(dateGeneration=3);q.execute("UPDATE personnages_donnees SET moral=100 WHERE name='Fixture'")
  check(appel(6,500,'3:squatter_cool')['bonusMoral']==0)
  for i,patch,raison in [(7,{'pnj':'cadavre'},'aucun_squatteur'),(8,{'pnj':None},'aucun_squatteur'),
   (9,{'succession_gel':'dossier'},'terrain_gele'),(10,{'policeAppellee':'legale'},'intervention_en_cours'),
   (11,{'city':'ailleurs'},'terrain_incoherent')]:
   etat(**patch);avant=snapshot();check(appel(i)['raison']==raison);check(snapshot()==avant)
  etat();q.execute("UPDATE personnages_donnees SET current_building=NULL WHERE name='Fixture'");avant=snapshot()
  check(appel(12)['raison']=='pas_sur_place');check(snapshot()==avant)
  q.execute("UPDATE personnages_donnees SET current_building='terrain-a-batir-1',pa=0 WHERE name='Fixture'");avant=snapshot()
  check(appel(13,501)['raison']=='pa_insuffisants');check(snapshot()==avant)
  q.execute("UPDATE personnages_donnees SET pa=20,liquide=0 WHERE name='Fixture';UPDATE comptes_bancaires SET solde=0 WHERE personnage='Fixture'");avant=snapshot()
  check(appel(14,501)['raison']=='fonds_insuffisants');check(snapshot()==avant)
  q.execute("UPDATE comptes_bancaires SET solde=10000 WHERE personnage='Fixture'")
  # Une panne apres paiement annule PA, francs, depart, moral et recu.
  etat(dateGeneration=4)
  q.execute("CREATE FUNCTION panne() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'panne_recu';END $$;CREATE TRIGGER panne BEFORE INSERT ON terrain_negociations_recus FOR EACH ROW EXECUTE FUNCTION panne()")
  avant=snapshot()
  try:appel(15,500,'4:squatter_cool');raise AssertionError('panne attendue')
  except psycopg2.Error as exc:check('panne_recu' in str(exc))
  check(snapshot()==avant);q.execute('DROP TRIGGER panne ON terrain_negociations_recus')
  # Meme UUID simultane : exactement un debit et un seul bonus.
  q.execute("UPDATE personnages_donnees SET moral=50 WHERE name='Fixture'")
  def concurrent(_):
   with psycopg2.connect(srv.get_uri()) as cc:return appel(16,500,'4:squatter_cool',cc.cursor())
  with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(concurrent,range(2)))
  check(all(x['ok'] for x in rr));check(sum(bool(x.get('rejeu')) for x in rr)==1)
  q.execute("SELECT moral FROM personnages_donnees WHERE name='Fixture'");check(q.fetchone()[0]==51)
  # Deux joueurs, un seul terrain : le second ne paie rien quand le premier l'a libere.
  etat(dateGeneration=5)
  def deux(nom):
   with psycopg2.connect(srv.get_uri()) as cc:
    cur=cc.cursor();cur.execute('SET hg.acteur=%s',(nom,));return appel(17,500,'5:squatter_cool',cur)
  with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(deux,['Fixture','Autre']))
  check(sum(bool(x.get('accepte')) for x in rr)==1);check(sum(x.get('raison')=='aucun_squatteur' for x in rr)==1)
  # Groupe reel, excommunication, affaiblissement et meilleurs paliers des organisations.
  etat(dateGeneration=6)
  q.execute("INSERT INTO pnj_membres VALUES('a','Fixture','Fixture','actif',9),('b','Autre','Autre','actif',1);INSERT INTO pnj_employes_metier VALUES('a'),('b')")
  check(contexte()['baseTaux']==46)
  q.execute("UPDATE personnages_donnees SET excommunie='{}' WHERE name='Fixture'");check(contexte()['baseTaux']==42)
  q.execute("UPDATE personnages_donnees SET stats_affaiblies='{\"CHA\":true}',hp=50 WHERE name='Fixture'");check(contexte()['baseTaux']==34)
  q.execute("INSERT INTO organisations VALUES('o1','{\"type\":\"economique\",\"membres\":[{\"nom\":\"Fixture\",\"gradeIdx\":3}]}'),('o2','{\"type\":\"syndicale\",\"membres\":[{\"nom\":\"Fixture\",\"gradeIdx\":2}]}')")
  check(contexte()['baseTaux']==89)
  q.execute("SELECT has_table_privilege('authenticated','terrain_negociations_recus','INSERT'),has_function_privilege('anon','terrain_negociation_conclure(text,text,integer,uuid)','EXECUTE'),has_function_privilege('authenticated','terrain_negociation_jet_interne()','EXECUTE')")
  check(q.fetchone()==(False,False,False))
  print(json.dumps({'ok':True,'assertions':n,'production':False}))
 finally:srv.cleanup()
if __name__=='__main__':main()
