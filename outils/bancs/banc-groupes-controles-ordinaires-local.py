#!/usr/bin/env python3
"""Contrôles ordinaires raccordés au détecteur et aux sanctions communs, base jetable."""
import importlib.util,sys,json,re
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('socle',R/'outils/bancs/banc-groupes-squatteurs-contrat-local.py');b=importlib.util.module_from_spec(sp);sp.loader.exec_module(b)
def suite(c):
 q,cas,rpc,exige,sql=[c[x] for x in ['q','cas','rpc','exige','sql']]
 for f in ['20261029220000_police_controles_detecteur_commun.sql','20261029220100_police_controles_actions_atomiques.sql']:
  q.execute((R/'migrations'/f).read_text());q.execute((R/'migrations'/f).read_text())
 q.execute(re.search(r'CREATE TABLE public.infractions \(.*?\n\);',(R/'baseline/domaines/justice/10_tables.sql').read_text(),re.S)[0])
 q.execute("INSERT INTO infractions(id,libelle,jours_reference,amende_reference,bareme_propre,detectable) VALUES('possession_illegale_douane','Possession d’objets prohibés',1,500,true,false)")
 if '--contre-controle-sans-recu' in sys.argv:
  q.execute("SELECT pg_get_functiondef('police_controle_action_interne(text,text)'::regprocedure)");s=q.fetchone()[0]
  s=s.replace('IF FOUND THEN RETURN v;END IF;',"IF FOUND THEN RETURN jsonb_build_object('ok',false,'raison','recu_ignore');END IF;",1)
  q.execute(s)
 q.execute(re.search(r'CREATE TABLE public.infractions_categories \(.*?\n\);',(R/'baseline/domaines/justice/10_tables.sql').read_text(),re.S)[0])
 q.execute("INSERT INTO infractions_categories VALUES('delit_mineur','Délit mineur',2,500)")
 c['c'].commit()
 def decor():
  sql("DELETE FROM batailles_rounds; DELETE FROM batailles_groupes; DELETE FROM batailles_engagements; DELETE FROM batailles; DELETE FROM police_interceptions; DELETE FROM police_detection_attempts; DELETE FROM police_action_receipts; DELETE FROM groupes_pj_adhesions; DELETE FROM jugements;")
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='mairie',current_room='accueil',current_street=NULL,hp=100,pa=100,est_emprisonne=NULL,hospitalisation=NULL,stats='{\"PER\":12,\"DUP\":8,\"VOL\":8}',resources='{\"dis\":0}',inventory='[{\"name\":\"Objet interdit\",\"type\":\"arme\",\"legal\":false}]',convocations='[]' WHERE name='C'")
  sql("UPDATE personnages_donnees SET current_building='ailleurs',current_room='ailleurs' WHERE name IN ('A','B','D')")
  sql("UPDATE pnj_membres SET leader_pj=NULL,leader_pnj_id=NULL,ville='capitale',building_id='mairie',room_id='accueil',pa=12,car_per=12,car_vol=12 WHERE famille='policier'")
  q.execute("SELECT pnj_groupes_projeter_interne(ARRAY(SELECT id FROM pnj_membres WHERE famille='policier'))")
 def choix():
  for n in range(100):
   q.execute('SAVEPOINT essai');q.execute('SELECT setseed(%s)',(n/100,))
   v=rpc('police_detection_verifier',('mairie','accueil',None),qui='C')
   if v.get('controle',{}).get('phase')=='choix':return v
   q.execute('ROLLBACK TO SAVEPOINT essai');q.execute('RELEASE SAVEPOINT essai')
  raise AssertionError('aucune détection suivie de fouille obtenue')
 def phases():
  decor();sql("UPDATE personnages_donnees SET resources='{\"dis\":100}' WHERE name='C'");vus=set()
  for n in range(100):
   q.execute('SAVEPOINT essai');q.execute('SELECT setseed(%s)',(n/100,))
   v=rpc('police_detection_verifier',('mairie','accueil',None),qui='C');vus.add(v.get('controle',{}).get('phase','non_detecte'))
   q.execute('ROLLBACK TO SAVEPOINT essai');q.execute('RELEASE SAVEPOINT essai')
  assert {'choix','persuasion','non_detecte'}<=vus,vus
 cas('controle_ordinaire_detection_persuasion_fouille_vrais_jets',phases)
 def soumission():
  decor();v=choix();rid=v['rencontre'];r=exige(rpc('police_reddition_resoudre',(rid,),qui='C'));assert r['phase']=='convocation',r
  q.execute("SELECT inventory,jsonb_array_length(convocations),est_emprisonne FROM personnages_donnees WHERE name='C'");inv,nb,d=q.fetchone();assert inv==[] and nb==1 and d is None,(inv,nb,d)
  assert rpc('police_reddition_resoudre',(rid,),qui='C')==r
  q.execute("SELECT jsonb_array_length(convocations) FROM personnages_donnees WHERE name='C'");assert q.fetchone()[0]==1
  exige(rpc('police_fuite_resoudre',(rid,),qui='C'),'controle_termine')
 cas('controle_soumission_saisie_convocation_rejeu_sans_double_effet',soumission)
 def reprise():
  decor();v=choix();r=exige(rpc('police_reprise_lire',(),qui='C'));assert r['controle_ordinaire'] and r['active'] and r['controle']['phase']=='choix'
  exige(rpc('police_combat_resoudre',(v['rencontre'],None,'mairie','accueil',1),qui='C'),'controle_non_judiciaire')
 cas('controle_rechargement_lecture_sans_tirage_ni_combat_invente',reprise)
 def autre():
  decor();v=choix();exige(rpc('police_reddition_resoudre',(v['rencontre'],),qui='A'),'rencontre_invalide')
  sql("UPDATE personnages_donnees SET current_room='autre' WHERE name='C'")
  exige(rpc('police_reddition_resoudre',(v['rencontre'],),qui='C'),'rencontre_invalide')
  q.execute("SELECT jsonb_array_length(inventory),jsonb_array_length(convocations) FROM personnages_donnees WHERE name='C'");assert q.fetchone()==(1,0)
 cas('controle_autre_personnage_ou_position_refuse_sans_saisie',autre)
 def fuite():
  decor();v=choix();vus=set()
  for n in range(100):
   q.execute('SAVEPOINT fuite');q.execute('SELECT setseed(%s)',(n/100,))
   r=exige(rpc('police_fuite_resoudre',(v['rencontre'],),qui='C'));vus.add(r['phase'])
   assert rpc('police_fuite_resoudre',(v['rencontre'],),qui='C')==r
   q.execute("SELECT est_emprisonne,jsonb_array_length(inventory) FROM personnages_donnees WHERE name='C'");d,inv=q.fetchone()
   if r['phase']=='detention':assert d['jours']==2 and inv==0,(d,inv)
   else:assert r['phase']=='fuite' and d is None and inv==1,r
   q.execute('ROLLBACK TO SAVEPOINT fuite');q.execute('RELEASE SAVEPOINT fuite')
   if vus=={'fuite','detention'}:break
  assert vus=={'fuite','detention'},vus
 cas('controle_fuite_vrais_jets_peine_plus_un_atomique_et_rejeu',fuite)
 def sain():
  decor();sql("UPDATE personnages_donnees SET inventory='[]' WHERE name='C'")
  termine=False
  for n in range(100):
   q.execute('SAVEPOINT sain');q.execute('SELECT setseed(%s)',(n/100,))
   v=rpc('police_detection_verifier',('mairie','accueil',None),qui='C')
   termine=v.get('controle',{}).get('phase')=='rien'
   q.execute('ROLLBACK TO SAVEPOINT sain');q.execute('RELEASE SAVEPOINT sain')
   if termine:break
  assert termine
 cas('controle_inventaire_legal_relache_sans_saisie_ni_peine',sain)
 def echec_aval():
  decor();rid=choix()['rencontre']
  q.execute("CREATE FUNCTION fixture_echec_convocation() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'panne_aval_controle'; END $$")
  q.execute("CREATE TRIGGER fixture_echec_convocation BEFORE UPDATE OF convocations ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION fixture_echec_convocation()")
  q.execute('SAVEPOINT avant_panne')
  try:
   rpc('police_reddition_resoudre',(rid,),qui='C')
   raise AssertionError('panne non déclenchée')
  except Exception as e:
   assert 'panne_aval_controle' in str(e),str(e)
   q.execute('ROLLBACK TO SAVEPOINT avant_panne')
  q.execute("SELECT jsonb_array_length(inventory),jsonb_array_length(convocations) FROM personnages_donnees WHERE name='C'");assert q.fetchone()==(1,0)
  q.execute("SELECT count(*) FROM police_action_receipts WHERE rencontre=%s",(rid,));assert q.fetchone()[0]==0
  q.execute("SELECT expires_at>now() FROM police_interceptions WHERE rencontre=%s",(rid,));assert q.fetchone()[0]
 cas('controle_panne_apres_saisie_annule_objets_convocation_et_recu',echec_aval)
 def prive_seul():
  decor();sql("UPDATE pnj_membres SET building_id='ailleurs' WHERE famille='policier'")
  q.execute("SELECT pnj_groupes_projeter_interne(ARRAY(SELECT id FROM pnj_membres WHERE famille='policier'))")
  v=rpc('police_detection_verifier',('mairie','accueil',None),qui='C')
  assert not v.get('detecte'),v
 cas('controle_pas_de_pouvoir_institutionnel_donne_aux_agents_prives',prive_seul)
 cas('controle_extension_preserve_deux_rounds_judiciaires_reels',lambda:(decor(),c['police_deux_rounds_reels']()))
 for champ,valeur in [('hp','0'),('est_emprisonne',"'{}'::jsonb"),('hospitalisation',"'{\"jourFin\":9999}'::jsonb")]:
  def indisponible(champ=champ,valeur=valeur):
   decor();sql('UPDATE personnages_donnees SET '+champ+'='+valeur+" WHERE name='C'")
   v=rpc('police_detection_verifier',('mairie','accueil',None),qui='C');assert not v.get('detecte'),v
   q.execute("SELECT count(*) FROM police_interceptions WHERE personnage='C'");assert q.fetchone()[0]==0
  cas('controle_detection_refuse_indisponibilite_'+champ,indisponible)
 def pa_nuls():
  decor();sql("UPDATE personnages_donnees SET pa=0 WHERE name='C'")
  v=choix();exige(rpc('police_reddition_resoudre',(v['rencontre'],),qui='C'))
  q.execute("SELECT pa FROM personnages_donnees WHERE name='C'");assert q.fetchone()[0]==0
 cas('controle_PA_nuls_ne_sont_ni_restaurees_ni_depensees_par_soumission',pa_nuls)
 def disponibilite_invalide():
  decor();rid=choix()['rencontre']
  q.execute("CREATE OR REPLACE FUNCTION public.navigation_disponibilite_interne(p_nom text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $$ SELECT '{}'::jsonb $$")
  v=rpc('police_reddition_resoudre',(rid,),qui='C');assert not v.get('ok'),v
  q.execute("SELECT jsonb_array_length(inventory),jsonb_array_length(convocations) FROM personnages_donnees WHERE name='C'");assert q.fetchone()==(1,0)
  q.execute("SELECT count(*) FROM police_action_receipts WHERE rencontre=%s",(rid,));assert q.fetchone()[0]==0
 cas('controle_disponibilite_sans_verdict_refuse_avant_saisie',disponibilite_invalide)
 def installation():
  decor();q.execute('ALTER FUNCTION public.police_controle_action_interne(text,text) RENAME TO fixture_action_non_installee')
  exige(rpc('police_detection_verifier',('mairie','accueil',None),qui='C'),'installation_incomplete')
  q.execute("SELECT count(*) FROM police_interceptions WHERE personnage='C'");assert q.fetchone()[0]==0
 cas('controle_installation_partielle_refuse_avant_detection',installation)
 # Décor et résultat committés uniquement pour deux vraies connexions au PG jetable.
 decor();rid=choix()['rencontre'];c['c'].commit()
 def concurrence():
  import psycopg2
  from threading import Barrier
  from concurrent.futures import ThreadPoolExecutor
  barriere=Barrier(2)
  def agir():
   cn=psycopg2.connect(c['serveur'].get_uri())
   try:
    cur=cn.cursor();cur.execute("SET statement_timeout='15s'");barriere.wait(timeout=5)
    v=rpc('police_reddition_resoudre',(rid,),qui='C',cur=cur);cn.commit();return v
   finally:cn.close()
  with ThreadPoolExecutor(2) as pool:
   a=pool.submit(agir);b=pool.submit(agir);un=exige(a.result(timeout=20));deux=exige(b.result(timeout=20))
  assert un==deux
  q.execute("SELECT jsonb_array_length(convocations) FROM personnages_donnees WHERE name='C'");assert q.fetchone()[0]==1
  q.execute("SELECT count(*) FROM police_action_receipts WHERE personnage='C' AND rencontre=%s",(rid,));assert q.fetchone()[0]==1
 cas('controle_deux_sessions_concurrentes_une_seule_saisie_et_convocation',concurrence)
 def autre_empire():
  decor();sql("UPDATE personnages_donnees SET country='soviet' WHERE name='C'")
  sql("INSERT INTO batiments_etat(id,country,city,building_id,data) VALUES('controle-soviet-fixture','soviet','capitale','commissariat','{\"effectifsPolice\":{\"policiers\":[{\"matricule\":\"SOV1\",\"buildingId\":\"mairie\",\"roomId\":\"accueil\"}]}}')")
  rid=choix()['rencontre'];termine=False
  for n in range(100):
   q.execute('SAVEPOINT peine_pays');q.execute('SELECT setseed(%s)',(n/100,))
   v=exige(rpc('police_fuite_resoudre',(rid,),qui='C'))
   if v['phase']=='detention':
    q.execute("SELECT est_emprisonne FROM personnages_donnees WHERE name='C'");d=q.fetchone()[0]
    assert d['country']=='soviet' and d['jours']==3,d
    termine=True
   q.execute('ROLLBACK TO SAVEPOINT peine_pays');q.execute('RELEASE SAVEPOINT peine_pays')
   if termine:break
  assert termine,'aucune fuite ratée dans le décor du second empire'
 cas('controle_autre_empire_preserve_bareme_generique_sans_pouvoir_judiciaire_nouveau',autre_empire)
 def droits():
  for sig in ['police_controle_action_interne(text,text)','police_detection_contexte_interne(text,text,text,text,boolean)']:
   for role in ['anon','authenticated','service_role']:
    q.execute('SELECT has_function_privilege(%s,%s,\'EXECUTE\')',(role,sig));assert not q.fetchone()[0]
 cas('controle_helpers_inaccessibles_aux_roles_reseau',droits)
if __name__=='__main__':sys.exit(b.lancer(suite))
