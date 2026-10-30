#!/usr/bin/env python3
"""Moteur de rue Git authentique + groupes, PostgreSQL jetable, JWT fictifs.
Les 59 cas antérieurs restent exécutés. Chaque nouveau cas est annulé.
Ce banc ne prétend pas vérifier les entrées de bâtiment ni le catalogue vivant.
"""
import importlib.util,json,sys,hashlib,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('force',R/'outils/bancs/banc-groupes-force-publique-local.py');force=importlib.util.module_from_spec(sp);sp.loader.exec_module(force)
def suite(ctx, suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 source=json.loads((R/'outils/bancs/fixtures/groupes-corps-git-20261028.json').read_text())['sources'][0]
 brut=source['sql'].encode()
 assert hashlib.sha256(brut).hexdigest()==source['sha256']
 if '--verifier-git' in sys.argv:assert subprocess.check_output(['git','show',source['commit']+':'+source['chemin']],cwd=R)==brut
 q.execute('''ALTER TABLE personnages_donnees ADD COLUMN id uuid DEFAULT gen_random_uuid(), ADD COLUMN est_emprisonne jsonb, ADD COLUMN hp integer DEFAULT 100, ADD COLUMN hospitalisation jsonb, ADD COLUMN day integer DEFAULT 1, ADD COLUMN updated_at timestamptz DEFAULT clock_timestamp();
 CREATE TABLE rue_noeuds_serveur(country text,city text,noeud text,voisins text[]);
 CREATE TABLE rue_sorties_batiments(country text,city text,building text,noeud text);
 CREATE TABLE police_interceptions(personnage text,expires_at timestamptz);
 INSERT INTO rue_noeuds_serveur VALUES('republic','capitale','rue-1',ARRAY['rue-2']),('republic','capitale','rue-2',ARRAY['rue-1']),('republic','capitale','loin','{}');
 INSERT INTO rue_sorties_batiments VALUES('republic','capitale','mairie','rue-1');''')
 if '--catalogue-20261029' in sys.argv:
  vivant=next(x for x in json.loads((R/'outils/bancs/fixtures/groupes-catalogue-communique-20261029.json').read_text())['fonctions'] if x['nom']=='rue_position_enregistrer')
  assert hashlib.sha256(vivant['sql'].encode()).hexdigest()==vivant['sha256'];q.execute(vivant['sql'])
  q.execute("SELECT md5(prosrc) FROM pg_proc WHERE oid='rue_position_enregistrer(text)'::regprocedure");assert q.fetchone()[0]=='e84a0ba5b5a4760414873b269c3cba4a'
 else:q.execute(source['sql'])
 q.execute("SELECT md5(pg_get_functiondef('rue_position_enregistrer(text)'::regprocedure))");assert q.fetchone()[0]==source['fonction'][1]
 migration=(R/'migrations/20261028183000_groupes_rue_transaction_commune.sql').read_text()
 def derive_refusee():
  q.execute("ALTER FUNCTION rue_position_enregistrer(text) SET search_path TO public")
  q.execute('SAVEPOINT derive')
  try:q.execute(migration)
  except Exception as e:
   q.execute('ROLLBACK TO SAVEPOINT derive');assert 'rue_definition_vivante_non_examinee' in str(e)
  else:raise AssertionError('définition différente acceptée')
 cas('rue_prevol_refuse_definition_non_examinee',derive_refusee)
 if '--contre-rue' not in sys.argv:q.execute(migration);q.execute(migration)

 ctx['c'].commit()
 soldats=['cie-S'+str(i) for i in range(1,5)];police=['police-republic-capitale-P'+str(i) for i in range(1,4)]
 def groupe():
  exige(rpc('pnj_prendre',(soldats,)));exige(rpc('pnj_prendre',(police,),qui='B'))
  exige(rpc('pnj_transferer',(soldats,'B',False)))
  exige(rpc('groupe_pj_rejoindre',('B',)))
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d');p=q.fetchone()[0]
  q.execute('SELECT jsonb_agg(to_jsonb(b) ORDER BY id) FROM batiments_etat b');return [p,q.fetchone()[0]]
 def marche():
  groupe();v=exige(rpc('rue_position_enregistrer',('rue-1',),qui='B'));assert v['membres']==['A','B'],v
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_street='rue-1' AND current_building IS NULL");assert q.fetchone()[0]==2
  q.execute("SELECT count(*) FROM unnest(%s::text[]) id CROSS JOIN LATERAL pnj_position_effective(id) p WHERE p.rue_noeud_id='rue-1'",(soldats+police,));assert q.fetchone()[0]==7
  avant=photo();v=exige(rpc('rue_position_enregistrer',('rue-1',),qui='B'));assert v['deja_present'] is True and photo()==avant
  exige(rpc('rue_position_enregistrer',('rue-2',),qui='B'))
 cas('rue_2_PJ_7_PNJ_sortie_marche_et_reponse_perdue',marche)
 def refus(raison,prepare,qui='B',noeud='rue-1'):
  groupe();sql(prepare);avant=photo();exige(rpc('rue_position_enregistrer',(noeud,),qui=qui),raison);assert photo()==avant
 cas('rue_membre_ne_commande_pas_le_chef',lambda:refus('chef_de_groupe_requis','SELECT 1',qui='A'))
 cas('rue_prison_second_membre_refuse_sans_mutation',lambda:refus('personnage_indisponible',"UPDATE personnages_donnees SET est_emprisonne='{}' WHERE name='B'"))
 cas('rue_interception_membre_refuse_sans_mutation',lambda:refus('interception_en_cours',"INSERT INTO police_interceptions VALUES('A',now()+interval '1 hour')"))
 cas('rue_coma_membre_refuse_sans_mutation',lambda:refus('acteur_incapacite',"UPDATE personnages_donnees SET hp=0 WHERE name='A'"))
 cas('rue_hopital_membre_refuse_sans_mutation',lambda:refus('acteur_incapacite',"UPDATE personnages_donnees SET hospitalisation=jsonb_build_object('dateFinParis','2999-01-01') WHERE name='B'"))
 cas('rue_hopital_legacy_refuse_sans_mutation',lambda:refus('acteur_incapacite',"UPDATE personnages_donnees SET hospitalisation='{\"jourFin\":3}' WHERE name='B'"))
 cas('rue_noeud_inconnu_refuse',lambda:refus('noeud_inconnu','SELECT 1',noeud='absent'))
 cas('rue_sortie_non_referencee_refuse',lambda:refus('sortie_invalide','SELECT 1',noeud='rue-2'))
 cas('rue_groupe_disperse_refuse',lambda:refus('groupe_disperse',"UPDATE personnages_donnees SET current_room='autre' WHERE name='A'"))
 def saut():
  groupe();exige(rpc('rue_position_enregistrer',('rue-1',),qui='B'));avant=photo()
  exige(rpc('rue_position_enregistrer',('loin',),qui='B'),'trajet_invalide');assert photo()==avant
 cas('rue_saut_non_adjacent_refuse',saut)
 def panne_projection():
  groupe();avant=photo()
  q.execute("CREATE OR REPLACE FUNCTION pnj_groupes_projeter_institutions_interne(p_ids text[]) RETURNS void LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'panne_fixture'; END $$")
  q.execute('SAVEPOINT panne')
  try:rpc('rue_position_enregistrer',('rue-1',),qui='B')
  except Exception as e:
   q.execute('ROLLBACK TO SAVEPOINT panne');q.execute('RESET ROLE');assert 'panne_fixture' in str(e)
  else:raise AssertionError('panne aval ignorée')
  assert photo()==avant
 cas('rue_echec_projection_annule_toutes_positions',panne_projection)
 def priv():
  for role in ['anon','authenticated','service_role']:
   q.execute("SELECT has_function_privilege(%s,'rue_position_personnage_interne(text,text,boolean)','EXECUTE')",(role,));assert q.fetchone()[0] is False
 cas('rue_moteur_interne_non_appelable_sur_reseau',priv)
 def derive_rejeu(signature,raison):
  q.execute('ALTER FUNCTION '+signature+' SET search_path TO public')
  q.execute('SAVEPOINT rejeu')
  try:q.execute(migration)
  except Exception as e:
   q.execute('ROLLBACK TO SAVEPOINT rejeu');assert raison in str(e),str(e)
  else:raise AssertionError('dérive acceptée au rejeu')
 cas('rue_rejeu_refuse_moteur_interne_modifie',lambda:derive_rejeu('rue_position_personnage_interne(text,text,boolean)','rue_moteur_interne_inconnu'))
 cas('rue_rejeu_refuse_enveloppe_modifiee',lambda:derive_rejeu('rue_position_enregistrer(text)','rue_enveloppe_non_examinee'))
 def legacy_invalide():
  groupe();sql("UPDATE personnages_donnees SET hospitalisation='{\"jourFin\":\"ancien\"}' WHERE name='B'")
  exige(rpc('rue_position_enregistrer',('rue-1',),qui='B'))
 cas('rue_hospitalisation_legacy_non_numerique_sans_exception',legacy_invalide)
 # Décor de concurrence committé dans cette seule base jetable ; aucun joueur.
 groupe();ctx['c'].commit()
 def concurrence():
  import psycopg2,time
  from concurrent.futures import ThreadPoolExecutor
  un=psycopg2.connect(ctx['serveur'].get_uri());deux=psycopg2.connect(ctx['serveur'].get_uri())
  try:
   for cc in [un,deux]:cc.cursor().execute("SET statement_timeout='8s'")
   v=exige(rpc('rue_position_enregistrer',('rue-1',),qui='B',cur=un.cursor()))
   assert v.get('deja_present') is False,v
   with ThreadPoolExecutor(1) as pool:
    f=pool.submit(rpc,'rue_position_enregistrer',('rue-1',),'B',deux.cursor())
    try:
     limite=time.monotonic()+3;bloque=False
     while time.monotonic()<limite:
      q.execute('SELECT pg_stat_clear_snapshot()')
      q.execute('SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s',(deux.get_backend_pid(),))
      if q.fetchone()[0]=='Lock':bloque=True;break
      if f.done():break
      time.sleep(.01)
     assert bloque,'la seconde commande ne rencontre pas réellement le verrou'
    finally:
     un.commit() # acte fictif, nécessaire au snapshot après attente
     ctx['preuves_extension']['action_fictive_committee']=True
     ctx['preuves_extension']['precision']='Une sortie fictive committée dans PostgreSQL éphémère pour vérifier le snapshot du second appel ; autres cas annulés, aucune production.'
    v=exige(f.result(timeout=8));assert v.get('deja_present') is True,v
   deux.rollback()
   q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_street='rue-1'");assert q.fetchone()[0]==2
  finally:un.rollback();deux.rollback();un.close();deux.close()
 cas('rue_deux_commandes_concurrentes_un_deplacement_et_un_rejeu',concurrence)
 if suivante is not None:suivante(ctx)


if __name__=='__main__':sys.exit(force.corps.g.main(lambda c:force.corps.extension(c,lambda c:force.suite(c,suite))))
