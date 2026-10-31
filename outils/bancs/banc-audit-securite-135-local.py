#!/usr/bin/env python3
"""Audit indépendant : vrais corps RPC archivés, identité/justice/coups déterministes simulés.
Aucun catalogue vivant. Le détecteur absent du dépôt n'est PAS reconstitué.
"""
from pathlib import Path
import re, tempfile, json, sys, subprocess, time
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
M='migrations/20261031115734_securite_privee_socle_policier.sql'
ETAPES=[M,'migrations/20261031115735_securite_privee_detection_unites.sql','migrations/20261031115736_securite_privee_combat_pa_et_registre.sql']

def fonction(f,nom):
 s=(R/f).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(')
 m=re.search(r'AS (\$\w*\$).*?\1\s*;',s[a:],re.S)
 assert m,nom
 return s[a:a+m.end()]

def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 original='--contre-pr' in sys.argv
 sql=subprocess.check_output(['git','show','7c91ef1b:'+M],cwd=R,text=True) if original else '\n'.join((R/p).read_text() for p in ETAPES)
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-audit-135-'),cleanup_mode='delete')
 c=psycopg2.connect(srv.get_uri());q=c.cursor();resultats=[]
 try:
  q.execute('''CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE TABLE personnages_donnees(id uuid DEFAULT gen_random_uuid(),name text PRIMARY KEY,user_id uuid,country text,current_city text,current_building text,current_room text,current_street text,pa integer,hp integer,resources jsonb,stats jsonb,est_emprisonne jsonb,day integer);
CREATE TABLE batiments_etat(id text PRIMARY KEY,country text,city text,building_id text,data jsonb,updated_at timestamptz);
CREATE TABLE police_interceptions(personnage text,rencontre text,country text,city text,building text,room text,street text,expires_at timestamptz DEFAULT now()+interval '5 minutes',fuite_tentee boolean DEFAULT false,PRIMARY KEY(personnage,rencontre));
CREATE TABLE police_action_receipts(personnage text,rencontre text,action text,round_key integer,verdict jsonb,created_at timestamptz DEFAULT now(),PRIMARY KEY(personnage,rencontre,action,round_key));
CREATE TABLE police_combat_rounds(personnage text,rencontre text,round_key integer,PRIMARY KEY(personnage,rencontre,round_key));
CREATE TABLE pnj_membres(id text PRIMARY KEY,famille text,classe text,nom text,pays text,proprietaire_pj text,leader_pj text,leader_pnj_id text,ville text,building_id text,room_id text,rue_noeud_id text,statut text DEFAULT 'actif',pa integer DEFAULT 12,car_per integer DEFAULT 12,car_vol integer DEFAULT 12,maj_le timestamptz DEFAULT now());
CREATE TABLE pnj_employes_metier(pnj_id text PRIMARY KEY,job text);
ALTER TABLE pnj_membres ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS $$ SELECT name FROM personnages_donnees WHERE user_id=nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT current_setting('role',true)='none' $$;
CREATE FUNCTION justice_recherches(text) RETURNS TABLE(id text,country text) LANGUAGE sql AS $$ SELECT 'justice-fictive','republic' $$;
CREATE FUNCTION recherche_inscrire(jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true}'::jsonb $$;
CREATE FUNCTION justice_executer_condamnation_soi(text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true,"detention_id":"fictive","jours":1}'::jsonb $$;
CREATE FUNCTION combat_coup_resoudre(numeric,numeric,numeric,integer,integer) RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('pa_apres',greatest(0,$5-1)) $$;
CREATE TABLE rue_noeuds_serveur(country text,city text,noeud text,voisins text[]);
CREATE TABLE rue_sorties_batiments(country text,city text,building text,noeud text);
INSERT INTO personnages_donnees VALUES(gen_random_uuid(),'Victime','00000000-0000-4000-8000-000000000001','republic','capitale','test','salle',NULL,100,100,'{"dis":0}','{"PER":8,"VOL":8}',NULL,1);
INSERT INTO personnages_donnees VALUES(gen_random_uuid(),'Chef','00000000-0000-4000-8000-000000000002','republic','capitale','test','salle',NULL,100,100,'{}','{}',NULL,1);
INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,ville,building_id,room_id) VALUES('agent','employe','Agent fictif','republic','Chef','capitale','test','salle');
INSERT INTO pnj_employes_metier VALUES('agent','agent_securite');
INSERT INTO police_interceptions(personnage,rencontre,country,city,building,room) VALUES('Victime','prive-fixture','republic','capitale','test','salle');
''')
  q.execute('ALTER TABLE pnj_membres ADD COLUMN proprietaire_institution text, ADD COLUMN proprietaire_perimetre text')
  tables=(R/'baseline/domaines/socle-PNJ/10_tables.sql').read_text()
  for nom in ['pnj_axes_autorite','pnj_mouvement_individuel','pnj_institutions']:
   q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',tables,re.S)[0])
  for nom in ['pnj_axes_autorite','pnj_mouvement_individuel']:
   q.execute((R/f'baseline/seeds/90_socle/{nom}.sql').read_text())
  for nom in ['pnj_autorite_de_perimetre','pnj_autorite_de','pnj_peut_administrer','pnj_peut_conduire','pnj_axe_au_socle','pnj_axe_verrouille','pnj_axe_position_refus','pnj_mouvement_individuel_refus']:
   q.execute(fonction('baseline/domaines/socle-PNJ/20_fonctions.sql',nom))
  for nom in ['pnj_position_effective','pnj_co_present','pnj_prendre','pnj_quitter_groupe','pnj_pas_de_sous_hierarchie']:
   q.execute(fonction('baseline/domaines/socle-PNJ/20_fonctions.sql',nom))
  contraintes=(R/'baseline/domaines/socle-PNJ/30_contraintes.sql').read_text()
  for nom in ['pnj_mort_sans_leader','pnj_pas_son_propre_leader','pnj_position_deux_etats','pnj_un_seul_leader','pnj_membres_leader_pnj_id_fkey']:
   q.execute(re.search(r'ALTER TABLE public.pnj_membres ADD CONSTRAINT '+nom+r' .*?;',contraintes,re.S)[0])
  q.execute('CREATE TRIGGER sous_hierarchie BEFORE INSERT OR UPDATE ON pnj_membres FOR EACH ROW EXECUTE FUNCTION pnj_pas_de_sous_hierarchie()')
  for nom in ['police_reddition_resoudre','police_fuite_resoudre','police_combat_resoudre']:
   q.execute(fonction('migrations/20261018093000_police_interception_reprise_transactionnelle.sql',nom))
  signatures=['police_fuite_resoudre(text)','police_reddition_resoudre(text)','police_combat_resoudre(text,text,text,text,integer)']
  for sig in signatures:
   q.execute('REVOKE ALL ON FUNCTION '+sig+' FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION '+sig+' TO authenticated')
  q.execute("SELECT oid::regprocedure::text,proacl::text FROM pg_proc WHERE oid=ANY(ARRAY["+','.join("'"+x+"'::regprocedure" for x in signatures)+"])");acl_avant=dict(q.fetchall())
  q.execute(sql[:sql.index('-- La RPC police_detection_verifier')])
  patches=re.findall(r'DO \$patch\$.*?END \$patch\$;',sql,re.S)
  assert len(patches)==3
  # Le premier patch exige le détecteur vivant, absent du baseline : non simulé ici.
  q.execute(patches[1]);q.execute(patches[2])
  if not original:
   q.execute(sql[:sql.index('-- La RPC police_detection_verifier')]);q.execute(patches[1]);q.execute(patches[2])
  q.execute("SELECT oid::regprocedure::text,proacl::text FROM pg_proc WHERE oid=ANY(ARRAY["+','.join("'"+x+"'::regprocedure" for x in signatures)+"])");assert dict(q.fetchall())==acl_avant,'ACL des portes modifiées par les patchs'
  c.commit() # Uniquement le décor fictif ; toutes les opérations testées sont annulées.
  q.execute("SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true)")
  def photo_police():
   q.execute("SELECT data->'effectifsPolice'->'policiers' FROM batiments_etat");return q.fetchone()[0]
  def appel(nom,params=()):
   q.execute("SELECT set_config('request.path',%s,true),set_config('role','authenticated',true)",('/rpc/'+nom,))
   try:
    q.execute('SELECT '+nom+'('+','.join(['%s']*len(params))+')',params);r=q.fetchone()[0]
   except Exception:
    raise
   else:q.execute('RESET ROLE');return r
  def cas(nom,fn):
   q.execute('SAVEPOINT cas')
   try:fn();resultats.append({'cas':nom,'ok':True})
   except AssertionError as e:resultats.append({'cas':nom,'ok':False,'preuve':str(e)})
   finally:q.execute('ROLLBACK TO SAVEPOINT cas')
  police=[{'matricule':x,'pa':12,'stats':{'PER':12,'VOL':12},'buildingId':'test','roomId':'salle','metadonnee':'conserver'} for x in ['p1','p2','p3']]
  def installer(selected):
   q.execute("INSERT INTO batiments_etat VALUES('comm','republic','capitale','commissariat',%s,now())",(Json({'effectifsPolice':{'policiers':police},'autreCle':True}),))
   q.execute("UPDATE police_interceptions SET intervenants=%s",(Json(selected),))
  def registre_prive():
   installer(['prive:agent']);avant=photo_police();r=appel('police_combat_resoudre',('prive-fixture',None,'test','salle',1))
   assert r['ok'],r
   assert photo_police()==avant,'combat privé a supprimé des policiers non intervenants'
  def registre_police():
   installer(['p1']);r=appel('police_combat_resoudre',('prive-fixture',None,'test','salle',1));assert r['ok'],r
   reste=photo_police();assert len(reste)==3,'registre policier tronqué après filtrage du seul intervenant'
   assert reste[1:]==police[1:],'agents hors combat modifiés'
   assert reste[0]['pa']==11,'PA de l intervenant non persistés'
  def rejeu():
   installer(['prive:agent']);a=appel('police_combat_resoudre',('prive-fixture',None,'test','salle',1))
   q.execute("SELECT pa FROM pnj_membres WHERE id='agent'");pa=q.fetchone()[0]
   b=appel('police_combat_resoudre',('prive-fixture',None,'test','salle',1))
   q.execute("SELECT pa FROM pnj_membres WHERE id='agent'")
   assert a==b and pa==q.fetchone()[0] and pa==11,'rejeu ou PA privé incohérent'
  def axes():
   q.execute("UPDATE pnj_membres SET leader_pj='Chef',ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL;SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);UPDATE pnj_membres SET famille='titulaire_poste'")
   r=appel('pnj_deployer_unite',(['agent'],True));assert r.get('raison')=='axe_position_hors_socle','nouvelle dépose contourne les gardes du socle'
  def groupes():
   q.execute("INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,ville,building_id,room_id) VALUES('agent2','employe','B','republic','Chef','capitale','test','salle')")
   q.execute("INSERT INTO pnj_employes_metier VALUES('agent2','agent_securite');UPDATE pnj_membres SET leader_pj='Chef',ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL;SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true)")
   r=appel('pnj_deployer_unite',(['agent','agent2'],True));assert r['ok'],r
   def unites():
    q.execute("SELECT securite_ordre_detection_interne(securite_agents_prives_presents_interne('republic','capitale','test','salle',NULL,'Victime'),'test','salle',NULL)");return q.fetchone()[0]
   g=unites();assert len(g)==1 and g[0]['effectif']==2,'déploiement ensemble non conservé'
   r=appel('pnj_prendre',(['agent','agent2'],));assert r['ok'],r
   r=appel('pnj_quitter_groupe',(['agent','agent2'],));assert r['ok'],r
   g=unites();assert len(g)==2 and all(x['effectif']==1 for x in g),'ancien marqueur de déploiement regroupe des unités désormais séparées'
  def priorites():
   src=(R/'outils/bancs/banc-securite-privee-priorites-135.sql').read_text()
   bloc=re.search(r'DO \$t\$.*?END \$t\$;',src,re.S)[0]
   q.execute(bloc)
  def droits():
   for nom,sig in [('securite_agents_prives_presents_interne','text,text,text,text,text,text'),('securite_ordre_detection_interne','jsonb,text,text,text')]:
    for role in ['anon','authenticated','service_role']:
     q.execute('SELECT has_function_privilege(%s,%s,\'EXECUTE\')',(role,'public.'+nom+'('+sig+')'))
     assert q.fetchone()[0] is False,(nom,role)
  def intrus():
   q.execute("UPDATE pnj_membres SET leader_pj='Chef',ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL")
   q.execute('SELECT to_jsonb(m) FROM pnj_membres m');avant=q.fetchone()[0]
   r=appel('pnj_deployer_unite',(['agent'],True));assert r.get('ok') is False,r
   q.execute('SELECT to_jsonb(m) FROM pnj_membres m');assert avant==q.fetchone()[0],'un autre PJ a changé le groupe'
  def absent():
   installer(['prive:agent']);q.execute("UPDATE pnj_membres SET building_id='ailleurs'")
   r=appel('police_combat_resoudre',('prive-fixture',None,'test','salle',1))
   assert r.get('raison')=='aucun_policier_present',r
   q.execute("SELECT pa FROM personnages_donnees WHERE name='Victime'");assert q.fetchone()[0]==100
  def employeur():
   q.execute("SELECT securite_agents_prives_presents_interne('republic','capitale','test','salle',NULL,'Chef')")
   assert q.fetchone()[0]==[],'agents hostiles à leur propre employeur'
  def panne():
   installer(['prive:agent'])
   q.execute("CREATE FUNCTION panne_recu_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_recu_fixture';END $$;CREATE TRIGGER panne_recu BEFORE INSERT ON police_action_receipts FOR EACH ROW EXECUTE FUNCTION panne_recu_fixture()")
   q.execute('SAVEPOINT avant_panne')
   try:appel('police_combat_resoudre',('prive-fixture',None,'test','salle',1));raise AssertionError('panne non déclenchée')
   except psycopg2.Error as e:
    assert 'panne_recu_fixture' in str(e)
    q.execute('ROLLBACK TO SAVEPOINT avant_panne')
   q.execute("SELECT pa FROM pnj_membres WHERE id='agent'");assert q.fetchone()[0]==12,'PA laissés après erreur de reçu'
   q.execute("SELECT pa FROM personnages_donnees WHERE name='Victime'");assert q.fetchone()[0]==100
   assert photo_police()==police,'registre altéré malgré rollback'
  def preconditions():
   q.execute('SAVEPOINT avant_precondition')
   try:q.execute(patches[0]);raise AssertionError('détecteur absent accepté')
   except psycopg2.errors.UndefinedFunction:q.execute('ROLLBACK TO SAVEPOINT avant_precondition')
  def reddition():
   installer(['prive:agent']);r=appel('police_reddition_resoudre',('prive-fixture',))
   assert r.get('detention_id')=='fictive',r
   assert appel('police_reddition_resoudre',('prive-fixture',))==r
   q.execute("SELECT expires_at<=now() FROM police_interceptions WHERE personnage='Victime'");assert q.fetchone()[0]
  def fuite():
   issues=set()
   for seed in [-.9,-.5,0,.5,.9]:
    q.execute('SAVEPOINT issue_fuite');installer(['prive:agent'])
    q.execute("INSERT INTO rue_sorties_batiments VALUES('republic','capitale','test','sortie');SELECT setseed(%s)",(seed,))
    r=appel('police_fuite_resoudre',('prive-fixture',));assert r.get('ok'),r
    issues.add(r['reussite']);assert appel('police_fuite_resoudre',('prive-fixture',))==r
    q.execute("SELECT current_building,current_street,pa FROM personnages_donnees WHERE name='Victime'");pos=q.fetchone()
    assert pos==(None,'sortie',100) if r['reussite'] else pos==('test',None,100)
    q.execute('ROLLBACK TO SAVEPOINT issue_fuite')
   assert issues=={True,False},'les deux issues doivent être réellement exercées'
  def position_rue():
   q.execute("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue-a' WHERE name='Chef';UPDATE pnj_membres SET leader_pj='Chef',ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL")
   q.execute("SELECT rue_noeud_id FROM pnj_position_effective('agent')")
   assert q.fetchone()[0]=='rue-a','la position commune perd la rue du chef suivi'
  def deploiement_rue():
   q.execute("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue-a' WHERE name='Chef';UPDATE pnj_membres SET leader_pj='Chef',ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL;SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true)")
   r=appel('pnj_deployer_unite',(['agent'],False));assert r['ok'],r
   r=appel('pnj_prendre',(['agent'],));assert r['ok'],'le garde de co-présence refuse une reprise réelle dans la rue'
  def identites_unites():
   q.execute("SELECT securite_ordre_detection_interne('[{\"pa\":12,\"buildingId\":\"test\",\"roomId\":\"salle\"},{\"pa\":12,\"buildingId\":\"test\",\"roomId\":\"salle\"}]','test','salle',NULL)")
   assert q.fetchone()[0]==[],'des entrées sans identité ont constitué un groupe par seule co-présence'
  def ancien_deploiement():
   q.execute('ALTER TABLE pnj_membres ADD COLUMN IF NOT EXISTS groupe_deploiement_id text;SAVEPOINT avant_ancien')
   try:
    q.execute(sql[:sql.index('-- La RPC police_detection_verifier')])
    assert original,'ancienne identité de déploiement ignorée sans prévol'
   except psycopg2.Error as e:
    assert not original,'la proposition originale doit reconnaître son propre schéma'
    assert 'audit135_ancien_deploiement_a_reconcilier' in str(e)
    q.execute('ROLLBACK TO SAVEPOINT avant_ancien')
  extras=[('priorites',priorites),('droits_auxiliaires',droits),('autre_chef',intrus),('intervenant_absent',absent),('employeur_exempte',employeur),('panne_recu',panne),('detecteur_absent_refuse',preconditions),('reddition_rejeu',reddition),('fuite_deux_issues_rejeu',fuite),('position_rue',position_rue),('deploiement_reprise_rue',deploiement_rue),('identites_unites',identites_unites),('ancienne_preparation_compatibilite',ancien_deploiement)]
  for nom,fn in [('registre_prive',registre_prive),('registre_police',registre_police),('rejeu_pa',rejeu),('gardes_communes',axes),('reprise_separation',groupes)]+extras:cas(nom,fn)
  c.rollback()
  # Deux vraies transactions métier concurrentes, toutes deux annulées.
  # Une séquence de fixture observe le moment de lecture sans committer les effets.
  q.execute("INSERT INTO personnages_donnees SELECT gen_random_uuid(),'Victime2','00000000-0000-4000-8000-000000000003',country,current_city,current_building,current_room,current_street,pa,hp,resources,stats,est_emprisonne,day FROM personnages_donnees WHERE name='Victime'")
  q.execute("UPDATE police_interceptions SET intervenants='[\"prive:agent\"]';INSERT INTO police_interceptions(personnage,rencontre,country,city,building,room,intervenants) VALUES('Victime2','prive-fixture2','republic','capitale','test','salle','[\"prive:agent\"]')")
  q.execute("CREATE SEQUENCE lectures_pa_fixture;ALTER FUNCTION securite_agents_prives_presents_interne(text,text,text,text,text,text) RENAME TO source_presence_fixture")
  q.execute("CREATE FUNCTION securite_agents_prives_presents_interne(text,text,text,text,text,text) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN PERFORM nextval('lectures_pa_fixture');RETURN source_presence_fixture($1,$2,$3,$4,$5,$6);END $$")
  c.commit() # Installation de cette seule instrumentation fictive.
  un=psycopg2.connect(srv.get_uri());deux=psycopg2.connect(srv.get_uri())
  def combat(conn,uid,rencontre):
   with conn.cursor() as cur:
    cur.execute("SET LOCAL statement_timeout='8s';SELECT set_config('request.jwt.claim.sub',%s,true),set_config('role','authenticated',true),set_config('request.path','/rpc/police_combat_resoudre',true)",(uid,))
    cur.execute("SELECT police_combat_resoudre(%s,NULL,'test','salle',1)",(rencontre,));return cur.fetchone()[0]
  try:
   r1=combat(un,'00000000-0000-4000-8000-000000000001','prive-fixture');assert r1['ok'],r1
   with ThreadPoolExecutor(max_workers=1) as pool:
    futur=pool.submit(combat,deux,'00000000-0000-4000-8000-000000000003','prive-fixture2')
    try:
     limite=time.monotonic()+5;bloque=False
     while time.monotonic()<limite:
      c.rollback();q.execute("SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s",(deux.get_backend_pid(),))
      if q.fetchone()[0]=='Lock':bloque=True;break
      if futur.done():break
      time.sleep(.02)
     assert bloque,'la seconde transaction doit réellement atteindre un verrou'
     q.execute('SELECT last_value FROM lectures_pa_fixture');lectures=q.fetchone()[0]
     resultats.append({'cas':'concurrence_lecture_pa','ok':lectures==1,'lectures_avant_liberation':lectures})
    finally:un.rollback()
    assert futur.result(timeout=8)['ok']
  finally:un.rollback();deux.rollback();un.close();deux.close()
  q.execute("SELECT pa FROM pnj_membres WHERE id='agent'");assert q.fetchone()[0]==12,'une transaction de test a été committée'
  c.rollback()
  if '--concurrence-commit-jetable' in sys.argv:
   # Option explicite : une seule opération committée dans ce PostgreSQL éphémère.
   # Indispensable pour vérifier le snapshot lu après l'attente du verrou.
   q.execute("SELECT setval('lectures_pa_fixture',1,false)");c.commit()
   un=psycopg2.connect(srv.get_uri());deux=psycopg2.connect(srv.get_uri())
   try:
    assert combat(un,'00000000-0000-4000-8000-000000000001','prive-fixture')['ok']
    with ThreadPoolExecutor(max_workers=1) as pool:
     futur=pool.submit(combat,deux,'00000000-0000-4000-8000-000000000003','prive-fixture2')
     try:
      limite=time.monotonic()+5;bloque=False
      while time.monotonic()<limite:
       c.rollback();q.execute("SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s",(deux.get_backend_pid(),))
       if q.fetchone()[0]=='Lock':bloque=True;break
       if futur.done():break
       time.sleep(.02)
      assert bloque
     finally:un.commit()
     assert futur.result(timeout=8)['ok']
    with deux.cursor() as cur:
     cur.execute("RESET ROLE;SELECT pa FROM pnj_membres WHERE id='agent'");pa=cur.fetchone()[0]
    resultats.append({'cas':'snapshot_apres_commit_jetable','ok':pa==10,'pa_apres_deux_coups':pa})
   finally:un.close();deux.rollback();deux.close()
  print(json.dumps({'source':'PR212-originale' if original else 'audit-corrige','tests':resultats,'production':False,'role':'authenticated','rollback':'--concurrence-commit-jetable' not in sys.argv,'detecteur_vivant_teste':False,'coups_et_justice':'simules','decor_fictif_committe':True,'acl_portes_preservees':True},ensure_ascii=False,indent=2))
  return int(any(not x['ok'] for x in resultats))
 finally:c.close();srv.cleanup()
if __name__=='__main__':sys.exit(main())
