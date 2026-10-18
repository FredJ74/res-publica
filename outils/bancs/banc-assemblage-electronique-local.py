#!/usr/bin/env python3
"""Moteur SQL reel, PostgreSQL jetable ; services annexes simules, aucun acces distant."""
import argparse,json,tempfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
SCHEMA="""
CREATE TABLE recettes_commerce(id text PRIMARY KEY,generique_id text,pa integer,portions integer,materiaux jsonb,intermediaires jsonb);
CREATE TABLE entreprises(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
CREATE TABLE personnages_donnees(name text PRIMARY KEY,pa integer,day integer,arg numeric,liquide numeric,updated_at timestamptz);
CREATE TABLE entreprises_constantes(cle text,valeur numeric);
INSERT INTO entreprises_constantes VALUES ('cout_main_oeuvre_pa_alimentaire',2);
CREATE TABLE productions_references(requete text PRIMARY KEY,fonds_id text,reference_id text,generique_id text,recette_id text,acteur text,quantite integer,pa integer,matieres jsonb,cout_matieres numeric,cout_lot numeric,cout_unitaire numeric);
CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF $1 NOT IN ('Alice','pj:Alice') THEN RAISE EXCEPTION 'acteur_refuse_fixture'; END IF;END$$;
CREATE FUNCTION fonds_acteur_present(text,jsonb) RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
CREATE FUNCTION fonds_generiques_accessibles(text) RETURNS TABLE(generique_id text) LANGUAGE sql AS $$SELECT DISTINCT generique_id FROM recettes_commerce$$;
CREATE FUNCTION matiere_refus_circuit_legal_lot(text,jsonb,text) RETURNS jsonb LANGUAGE sql AS $$SELECT NULL::jsonb$$;
CREATE FUNCTION entreprise_ajouter_historique(jsonb,numeric,text,integer) RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
"""
RECETTES=[('composants-electroniques',3,2,{'metal':1,'produits_exotiques':1},0),('ordinateur',2,1,{'metal':1},2),('telephone',1,1,{'metal':1},1),('box',2,1,{'metal':1},1),('camera',2,1,{'metal':1},1),('imprimante',2,1,{'metal':2},1),('imprimante3d',4,1,{'metal':3},2),('stockage',1,1,{'metal':1},1),('intranet',2,1,{'metal':1},2),('jeu',1,1,{},1)]
def main():
 argparse.ArgumentParser(description=__doc__).parse_args()
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-electronique-'),cleanup_mode='delete');uri=serveur.get_uri()
 c=psycopg2.connect(uri);c.autocommit=True;q=c.cursor();q.execute(SCHEMA)
 for nom,pa,rendement,mat,comps in RECETTES:q.execute('INSERT INTO recettes_commerce VALUES (%s,%s,%s,%s,%s,%s)',(nom,nom,pa,rendement,json.dumps(mat),json.dumps({'composants-electroniques':comps} if comps else {})))
 original=(R/'migrations/20261018234500_assemblage_electronique.sql').read_text();original=original[original.index('CREATE OR REPLACE FUNCTION'):];q.execute(original)
 def reset(split=False,comps=10,caisse=1000,pa=100):
  q.execute('TRUNCATE entreprises,personnages_donnees,productions_references');refs={n:{'generique_id':n,'recette_id':n} for n,*_ in RECETTES};refs['comp-a']={'generique_id':'composants-electroniques'};refs['comp-b']={'generique_id':'composants-electroniques'}
  d={'version':2,'statut':'actif','implantation':{},'references':refs,'stockReferences':{'comp-a':1 if split else comps,'comp-b':1 if split else 0},'stockMatieres':{'metal':100,'produits_exotiques':100},'coutMoyenMatieres':{'metal':3,'produits_exotiques':7},'coutMoyenReferences':{'comp-a':5.5,'comp-b':6.5},'caisse':caisse}
  q.execute('INSERT INTO entreprises VALUES (%s,%s,now())',('fonds',json.dumps(d)));q.execute("INSERT INTO personnages_donnees VALUES ('Alice',%s,1,0,0,now())",(pa,))
 def appel(nom='ordinateur',requete='prod-test-000001',lots=1,cur=q):
  cur.execute('SELECT fonds_reference_produire_lots(%s,%s,%s,%s,%s)',(requete,'Alice','fonds',nom,lots));return cur.fetchone()[0]
 def etat():
  q.execute('SELECT data FROM entreprises');d=q.fetchone()[0];q.execute('SELECT pa,arg,liquide FROM personnages_donnees');return d,q.fetchone()
 # Contre-epreuves sur le vrai moteur archive.
 reset(split=True);assert appel()['raison']=='composants_insuffisants'
 reset();assert appel()['ok'];assert etat()[0]['stockMatieres']['composants-electroniques']==-2
 migration=next((R/'migrations').glob('*_assemblage_composants_stocks_reels.sql'));q.execute(migration.read_text());q.execute(migration.read_text())
 n=0
 for nom,pa,rendement,mat,comp in RECETTES:
  reset();v=appel(nom);assert v['ok'],v;d,pj=etat();assert d['stockReferences'][nom]==rendement;assert pj[0]==100-pa
  assert d['stockReferences']['comp-a']==10-comp;assert 'composants-electroniques' not in d['stockMatieres'];assert pj[1]==pj[2]==pa*2
  for m,quantite in mat.items():assert d['stockMatieres'][m]==100-quantite
  n+=1
 reset(split=True);v=appel();assert v['ok'];assert v['coutMatieres']==15;assert etat()[0]['stockReferences']['comp-b']==0;n+=1
 for kw,raison in [({'comps':1},'composants_insuffisants'),({'pa':0},'pa_insuffisants'),({'caisse':0},'caisse_insuffisante')]:
  reset(**kw);avant=etat();assert appel()['raison']==raison;assert etat()==avant;n+=1
 reset();avant=etat();q.execute("UPDATE entreprises SET data=data #- '{coutMoyenReferences,comp-a}'");avant=etat();assert appel()['raison']=='cout_composants_inconnu';assert etat()==avant;n+=1
 reset();assert appel()['ok'];avant=etat();assert appel()['rejeu'];assert etat()==avant;assert appel(lots=2)['raison']=='requete_reutilisee';n+=1
 # Echec tardif : la transaction annule egalement PA, argent, matieres, composants et produit.
 q.execute("CREATE FUNCTION fixture_echec() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_fixture'; END$$; CREATE TRIGGER fixture_echec BEFORE INSERT ON productions_references FOR EACH ROW EXECUTE FUNCTION fixture_echec()")
 reset();avant=etat()
 try:appel();raise AssertionError('panne non levee')
 except psycopg2.Error as e:assert 'panne_fixture' in str(e)
 assert etat()==avant;q.execute('DROP TRIGGER fixture_echec ON productions_references');n+=1
 def concurrent(requete):
  with psycopg2.connect(uri) as cc:
   with cc.cursor() as cur:return appel(requete=requete,cur=cur)
 for memes in [True,False]:
  reset(comps=2)
  with ThreadPoolExecutor(2) as pool:resultats=list(pool.map(concurrent,['prod-concurrent-001','prod-concurrent-001' if memes else 'prod-concurrent-002']))
  if memes:assert all(r['ok'] for r in resultats) and sum(bool(r.get('rejeu')) for r in resultats)==1
  else:assert sum(bool(r['ok']) for r in resultats)==1
  assert etat()[1][0]==98;n+=1
 # Catalogue SQL reel : dix articles, aucun ancien generique en supplement.
 q.execute("ALTER TABLE recettes_commerce ADD COLUMN source text, ADD COLUMN label text, ADD COLUMN categorie text, ADD COLUMN types_autorises jsonb")
 q.execute("CREATE TABLE catalogue_generiques(id text PRIMARY KEY,libelle text,famille_id text,regime text,est_service boolean,empilable boolean,individualise boolean,consommable boolean,equipable boolean,note text); CREATE TABLE catalogue_generique_type(generique_id text,type_id text,PRIMARY KEY(generique_id,type_id))")
 for id in ['ordinateur-complet','telephone-cellulaire','camera-de-surveillance','jeu-video','appareil-electronique']:
  q.execute('INSERT INTO catalogue_generiques(id) VALUES (%s)',(id,));q.execute("INSERT INTO catalogue_generique_type VALUES (%s,'electronique-informatique')",(id,))
 for id,gen in [('ordinateur_complet_commerce','ordinateur-complet'),('telephone_cellulaire_commerce','telephone-cellulaire')]:q.execute("INSERT INTO recettes_commerce(id,generique_id) VALUES (%s,%s)",(id,gen))
 q.execute((R/'migrations/20261018230000_composants_electroniques_catalogue.sql').read_text())
 q.execute((R/'migrations/20261018234500_assemblage_electronique.sql').read_text())
 q.execute((R/'migrations/20261019001000_catalogue_informatique_dix_articles.sql').read_text())
 q.execute("SELECT count(*) FROM catalogue_generique_type WHERE type_id='electronique-informatique'");assert q.fetchone()[0]==10
 q.execute("SELECT pa,portions,materiaux,intermediaires FROM recettes_commerce WHERE id='ordinateur_complet_commerce'");assert q.fetchone()==(2,1,{'metal':1},{'composants-electroniques':2})
 n+=1
 c.close();serveur.cleanup();print(f'{n}/{n} groupes PostgreSQL reussis ; deux defauts historiques reproduits avant correction. Aucun Supabase.')
if __name__=='__main__':main()
