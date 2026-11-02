#!/usr/bin/env python3
"""Corps SQL réels, PostgreSQL jetable, JWT/acteurs fictifs, jamais de production.
Les actes sont annulés par savepoint, sauf un acquittement concurrent committé
sur deux connexions au cluster détruit en fin de banc. Aucun autre compte.
"""
import hashlib,importlib.util,json,os,re,sys,tempfile,time,traceback
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
M=['20261102202046_subtilisation_reponse_serveur_versionnee.sql','20261102202047_impacts_consommation_serveur_atomique.sql']
def fonction(f,nom):
 s=(R/f).read_text();a=re.search(r'CREATE OR REPLACE FUNCTION public\.'+nom+r'\(',s).start();m=re.search(r'AS\s+(\$\w*\$).*?\1;',s[a:],re.S);return s[a:a+m.end()]
def table(q,f,nom):
 s=(R/f).read_text();q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
def main():
 if os.environ.get('HG219_POSTGRES_BIN'):
  sp=importlib.util.spec_from_file_location('pg17',R/'outils/baseline/epreuve-postgresql.py');p=importlib.util.module_from_spec(sp);sp.loader.exec_module(p);p.configurer_binaires(Path(os.environ['HG219_POSTGRES_BIN']))
 import pgserver,psycopg2
 from psycopg2.extras import Json
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-379-'),cleanup_mode='delete');cas=[];c=None
 try:
  c=psycopg2.connect(srv.get_uri());q=c.cursor();q.execute('SHOW server_version_num');version=q.fetchone()[0]
  if os.environ.get('HG219_POSTGRES_BIN'):assert version=='170006',version
  q.execute("SELECT collversion,pg_collation_actual_version(oid) FROM pg_collation WHERE collname='en-US-x-icu'");icu=q.fetchone()
  q.execute("CREATE ROLE authenticated;CREATE ROLE anon;CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;")
  table(q,'baseline/domaines/personnage-et-presence/10_tables.sql','personnages_donnees')
  q.execute('ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE personnages_donnees ENABLE ROW LEVEL SECURITY;CREATE VIEW personnages AS SELECT * FROM personnages_donnees')
  q.execute(fonction('baseline/domaines/socle/20_fonctions.sql','mon_personnage'))
  table(q,'baseline/domaines/justice/10_tables.sql','impacts_indices_attente');q.execute('ALTER TABLE impacts_indices_attente ADD PRIMARY KEY(id);ALTER TABLE impacts_indices_attente ENABLE ROW LEVEL SECURITY')
  q.execute('CREATE TABLE indices_villes(id text PRIMARY KEY,data jsonb);CREATE TABLE budgets_nationaux(id text PRIMARY KEY,data jsonb,updated_at timestamptz)')
  for f,n in [('baseline/domaines/militaire/20_fonctions-1.sql','caserne_stock_mouvement'),('baseline/domaines/militaire/20_fonctions-3.sql','militaire_subtiliser_tenter'),('baseline/domaines/justice/20_fonctions-2.sql','impact_marquer_traite'),('historique/migrations-appliquees/20261027180000_inventaire_achats_serveur.sql','inventaire_deposer_interne'),('baseline/domaines/socle/20_fonctions.sql','inventaire_place_restante'),('historique/migrations-appliquees/rehorodatees-219/20261031113546_reception_objets_atomique.sql','inventaire_revision_garder')]:q.execute(fonction(f,n))
  q.execute('CREATE TRIGGER zzzz_hg_inventory_revision BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION inventaire_revision_garder()')
  # Vrai déclencheur pa0 livré ; la géographie de l'hôpital est l'unique annexe simulée.
  q.execute("CREATE FUNCTION hospitalisation_lieu_rejoindre_interne(text,text,text,boolean,boolean) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{\"ok\":false,\"raison\":\"fixture_sans_geographie\"}'::jsonb $$")
  q.execute(fonction('migrations/20261101171000_hospitalisation_pa0_luthecia.sql','hospitalisation_pa_epuises_declencheur') if (R/'migrations/20261101171000_hospitalisation_pa0_luthecia.sql').exists() else fonction(next(str(p.relative_to(R))for p in (R/'migrations').glob('20261101171000*.sql')),'hospitalisation_pa_epuises_declencheur'))
  q.execute('CREATE CONSTRAINT TRIGGER trg_hospitalisation_pa_epuises AFTER UPDATE OF pa ON personnages_donnees DEFERRABLE INITIALLY DEFERRED FOR EACH ROW WHEN(NEW.pa=0 AND coalesce(OLD.pa,0)>0) EXECUTE FUNCTION hospitalisation_pa_epuises_declencheur()')
  table(q,'baseline/domaines/socle-PNJ/10_tables.sql','pnj_metiers_profils')
  q.execute((R/'baseline/seeds/90_socle/pnj_metiers_profils.sql').read_text())
  for n in ['employe_metiers_recrutables','employe_recruter']:q.execute(fonction('baseline/domaines/personnage-et-presence/20_fonctions-1.sql',n))
  q.execute("INSERT INTO personnages_donnees(name,country,user_id,current_city,current_building,pa,stats,resources)VALUES('Fixture','republic','00000000-0000-4000-9000-000000000001','caserne','caserne-militaire',10,'{\"DUP\":10}','{\"pop\":10,\"inf\":20,\"dis\":0}'),('AutreFixture','republic','00000000-0000-4000-9000-000000000002','capitale','mairie',10,'{}','{}');INSERT INTO budgets_nationaux VALUES('republic','{\"stockArmurerieMilitaire\":{\"explosif_militaire\":5}}',now());")
  def own(sql,args=()):
   if sql.lstrip().startswith('ROLLBACK'):q.execute(sql);q.execute('RESET ROLE');return None
   q.execute('RESET ROLE');q.execute(sql,args) if args else q.execute(sql);return q.fetchone()[0]if q.description else None
  def rpc(fn,args=(),qui=1,cur=None):
   cc=cur or q;cc.execute("SELECT set_config('role','authenticated',true),set_config('request.path',%s,true),set_config('request.jwt.claim.sub',%s,true)",('/rpc/'+fn,f'00000000-0000-4000-9000-{qui:012d}'));cc.execute('SELECT public.'+fn+'('+','.join(['%s']*len(args))+')',args);return cc.fetchone()[0]
  def photo():return own("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(d)ORDER BY name) FROM personnages_donnees d),(SELECT jsonb_agg(to_jsonb(i)ORDER BY id) FROM impacts_indices_attente i),(SELECT jsonb_agg(to_jsonb(b)) FROM budgets_nationaux b))")
  def case(n,fn):
   own('SAVEPOINT scenario')
   try:fn();cas.append({'cas':n,'ok':True})
   except Exception as e:cas.append({'cas':n,'ok':False,'erreur':str(e),'trace':traceback.format_exc(limit=5)})
   finally:own('ROLLBACK TO SAVEPOINT scenario')
  # Ancien acquittement : il confirme sans appliquer. Une contre-épreuve réelle.
  own("INSERT INTO impacts_indices_attente(id,victime,indice,delta)VALUES('avant','Fixture','pop',5)")
  avant=rpc('impact_marquer_traite',['avant']);assert avant['ok'] and own("SELECT (resources->>'pop')::integer FROM personnages_donnees WHERE name='Fixture'")==10
  own("DELETE FROM impacts_indices_attente")
  for _ in range(2):
   for m in M:own((R/'migrations'/m).read_text())
  if '--contre' in sys.argv:
   own(fonction('baseline/domaines/justice/20_fonctions-2.sql','impact_marquer_traite'))
   own(fonction('baseline/domaines/militaire/20_fonctions-3.sql','militaire_subtiliser_tenter'))
   own("CREATE OR REPLACE FUNCTION impact_marquer_traite(p_id text,p_contrat integer)RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $$ SELECT public.impact_marquer_traite(p_id)||'{\"contrat\":1,\"applique\":true}'::jsonb $$")
  def impact(kind,delta=5,details=None,id='i',qui=1):
   own('INSERT INTO impacts_indices_attente(id,victime,indice,delta,details,palier)VALUES(%s,%s,%s,%s,%s,%s)',(id,'Fixture',kind,delta,Json(details or {}),'partielle'));return rpc('impact_marquer_traite',[id,1],qui)
  for kind in ['pop','inf','dis']:
   def effet(kind=kind):
    v=impact(kind);assert v['ok'] and v['marques']==1;assert own("SELECT (resources->>%s)::int FROM personnages_donnees WHERE name='Fixture'",(kind,))=={'pop':15,'inf':25,'dis':5}[kind]
    p=photo();v=rpc('impact_marquer_traite',['i',1]);assert v['marques']==0 and photo()==p
   case('impact_'+kind+'_serveur_une_fois',effet)
  def carte():
   a=impact('moral_carte_postale',10);b=impact('moral_carte_postale',10,id='j');assert a['applique'] and not b['applique'];assert own("SELECT moral FROM personnages_donnees WHERE name='Fixture'")==85
   assert own("SELECT count(*)FROM impacts_indices_attente WHERE traite") ==2
  case('carte_plafond_expediteur_Paris_et_deux_acquittements',carte)
  def hp():
   v=impact('hp_set',25);assert v['ok'];own('SET CONSTRAINTS trg_hospitalisation_pa_epuises IMMEDIATE')
   assert own("SELECT jsonb_build_array(hp,pa,regen_jour,hospitalisation->>'regime',(SELECT count(*)FROM jsonb_object_keys(stats_affaiblies)))FROM personnages_donnees WHERE name='Fixture'")==[25,0,1,'pa0',2]
  case('hp_set_PA0_et_declencheur_hospitalisation_existant',hp)
  def poison():
   assert impact('poison_start',0,{'poisonType':'ghb','statsTouchees':['INT','DUP']})['ok']
   assert own("SELECT poison_actif->>'poisonType' FROM personnages_donnees WHERE name='Fixture'")=='ghb'
   assert own("SELECT stats_affaiblies->>'INT' FROM personnages_donnees WHERE name='Fixture'")=='true'
  case('poison_details_conserves_sans_tirage_client',poison)
  for kind,details,delta in [('inconnu',{},5),('poison_start',{'statsTouchees':'INT'},0),('hp_set',{},101),('moral_carte_postale',{},999)]:
   def refuse(kind=kind,details=details,delta=delta):
    v=impact(kind,delta,details);assert not v['ok'];assert own("SELECT traite FROM impacts_indices_attente WHERE id='i'")is False;assert own("SELECT hp FROM personnages_donnees WHERE name='Fixture'")==100
   case('impact_invalide_'+kind+str(delta),refuse)
  def autre():
   v=impact('pop',qui=2);assert not v['ok'];assert own("SELECT traite FROM impacts_indices_attente WHERE id='i'")is False
  case('autre_identite_ne_consomme_pas',autre)
  def vieux():
   own("INSERT INTO impacts_indices_attente(id,victime,indice,delta)VALUES('i','Fixture','pop',5)");p=photo();assert rpc('impact_marquer_traite',['i'])['raison']=='client_obsolete';assert photo()==p
  case('ancien_contrat_refuse_sans_effet_ni_marque',vieux)
  def inactive():
   p=photo();v=rpc('employe_recruter',['codetenu','NomFixture',None,None,None,None]);assert v['raison']=='metier_non_recrutable'and photo()==p
  case('codetenu_refuse_par_commande_canonique_sans_paiement',inactive)
  def sub():
   issues=set()
   for k in range(100):
    own('SAVEPOINT tirage');own('SELECT setseed(%s)',((k-50)/51,));v=rpc('militaire_subtiliser_tenter',['republic',1]);assert v['pa']==8 and v['contrat']==1 and isinstance(v['revision'],int)
    if v.get('reussite'):
     issues.add('succes');assert len(v['inventory'])==1 and v['revision']==1;assert own("SELECT (data->'stockArmurerieMilitaire'->>'explosif_militaire')::int FROM budgets_nationaux WHERE id='republic'")==4
    else:issues.add('detecte'if v.get('detecte')else'echec')
    own('ROLLBACK TO SAVEPOINT tirage')
    if len(issues)==3:break
   assert len(issues)==3,issues
  case('subtilisation_succes_refus_jet_et_detection_PA_officiels',sub)
  def vide():
   own("UPDATE budgets_nationaux SET data='{}'")
   for k in range(100):
    own('SAVEPOINT tirage');own('SELECT setseed(%s)',((k-50)/51,));v=rpc('militaire_subtiliser_tenter',['republic',1]);own('ROLLBACK TO SAVEPOINT tirage')
    if v.get('raison')=='stock_insuffisant':assert v['pa']==8 and v['revision']==0 and v['inventory']==[];return
   raise AssertionError('branche stock insuffisant non atteinte')
  case('subtilisation_stock_vide_cout_tentative_preserve',vide)
  def horslieu():
   own("UPDATE personnages_donnees SET current_building='mairie'WHERE name='Fixture'");p=photo();assert rpc('militaire_subtiliser_tenter',['republic',1])['raison']=='pas_sur_place'and photo()==p
  case('subtilisation_hors_caserne_sans_mutation',horslieu)
  def manque():
   own("UPDATE personnages_donnees SET pa=1 WHERE name='Fixture'");p=photo();assert rpc('militaire_subtiliser_tenter',['republic',1])['raison']=='pa_insuffisants'and photo()==p
  case('subtilisation_PA_insuffisants_sans_mutation',manque)
  def rollback():
   own("CREATE FUNCTION fixture_refuser_marque() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.traite THEN RAISE EXCEPTION 'panne_marque_fixture';END IF;RETURN NEW;END $$;CREATE TRIGGER fixture_refuser_marque BEFORE UPDATE ON impacts_indices_attente FOR EACH ROW EXECUTE FUNCTION fixture_refuser_marque()")
   own("INSERT INTO impacts_indices_attente(id,victime,indice,delta)VALUES('i','Fixture','pop',5)");p=photo();own('SAVEPOINT panne')
   try:rpc('impact_marquer_traite',['i',1]);raise AssertionError('panne non détectée')
   except psycopg2.Error as e:assert 'panne_marque_fixture'in str(e);own('ROLLBACK TO SAVEPOINT panne')
   assert photo()==p
  case('panne_acquittement_annule_effet_impact',rollback)
  def prevol():
   own("CREATE OR REPLACE FUNCTION impact_marquer_traite(p_id text)RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$");own('SAVEPOINT garde')
   try:own((R/'migrations'/M[1]).read_text());raise AssertionError('corps non examiné écrasé')
   except psycopg2.Error as e:assert '379_definition_non_examinee'in str(e);own('ROLLBACK TO SAVEPOINT garde')
  case('prevol_refuse_definition_serveur_inconnue',prevol)
  def acl():
   for f in ['impact_marquer_traite(text,integer)','militaire_subtiliser_tenter(text,integer)']:
    assert own("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",(f,))
    for role in ['anon','service_role']:assert not own("SELECT has_function_privilege(%s,%s,'EXECUTE')",(role,f))
  case('droits_nouveaux_contrats_authentifies_seulement',acl)
  def depot_panne():
   own("CREATE OR REPLACE FUNCTION inventaire_deposer_interne(p_nom text,p_objet jsonb,p_automatique boolean DEFAULT false)RETURNS jsonb LANGUAGE sql AS $$ SELECT '{\"ok\":false}'::jsonb $$")
   for k in range(100):
    own('SAVEPOINT depot');p=photo();own('SELECT setseed(%s)',((k-50)/51,))
    try:rpc('militaire_subtiliser_tenter',['republic',1])
    except psycopg2.Error as e:
     assert 'subtilisation_depot_refuse'in str(e);own('ROLLBACK TO SAVEPOINT depot');assert photo()==p;return
    own('ROLLBACK TO SAVEPOINT depot')
   raise AssertionError('panne de depot non observee')
  case('panne_depot_annule_PA_et_stock_dans_meme_transaction',depot_panne)
  def precision():
   own("UPDATE personnages_donnees SET resources='{\"pop\":0.5}'WHERE name='Fixture'");assert impact('pop',5)['ok'];assert own("SELECT (resources->>'pop')::numeric FROM personnages_donnees WHERE name='Fixture'")==5.5
  case('impact_conserve_fraction_indice_historique',precision)
  for fn,args in [('impact_marquer_traite',['i',0]),('militaire_subtiliser_tenter',['republic',0])]:
   def contrat(fn=fn,args=args):
    p=photo();assert rpc(fn,args)['raison']=='contrat_invalide'and photo()==p
   case('version_refusee_avant_mutation_'+fn,contrat)

  # Réponse perdue/rejeu réellement concurrents : seul décor fictif committé.
  own("INSERT INTO impacts_indices_attente(id,victime,indice,delta)VALUES('concurrent','Fixture','pop',5)");c.commit()
  un=psycopg2.connect(srv.get_uri());deux=psycopg2.connect(srv.get_uri())
  try:
   v=rpc('impact_marquer_traite',['concurrent',1],cur=un.cursor());assert v['marques']==1
   with ThreadPoolExecutor(1)as pool:
    fut=pool.submit(rpc,'impact_marquer_traite',['concurrent',1],1,deux.cursor());limite=time.monotonic()+3;bloque=False
    while time.monotonic()<limite:
     q.execute('SELECT pg_stat_clear_snapshot()');q.execute('SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s',(deux.get_backend_pid(),));bloque=q.fetchone()[0]=='Lock'
     if bloque or fut.done():break
     time.sleep(.01)
    assert bloque,'attente concurrente non observée';un.commit();rejeu=fut.result(timeout=5);assert rejeu['marques']==0
   deux.rollback();assert own("SELECT (resources->>'pop')::int FROM personnages_donnees WHERE name='Fixture'")==15
   cas.append({'cas':'acquittements_concurrents_reponse_perdue_un_effet','ok':True})
  except Exception as e:cas.append({'cas':'acquittements_concurrents_reponse_perdue_un_effet','ok':False,'erreur':str(e),'trace':traceback.format_exc(limit=5)})
  finally:un.rollback();deux.rollback();un.close();deux.close()
  rapport={'production':False,'moteur':version,'icu':icu,'role':'authenticated, request.path /rpc/<fonction>, JWT fictifs','tests':cas,'limites':['Géographie hospitalière simulée, déclencheur pa0 réel.','Pas un clone du catalogue vivant.','Un acquittement fictif committé pour la concurrence ; cluster détruit.'],'migrations':M}
  print(json.dumps(rapport,ensure_ascii=False,indent=2));return 0 if all(x['ok']for x in cas)else 1
 finally:
  if c:c.rollback();c.close()
  srv.cleanup()
if __name__=='__main__':sys.exit(main())
