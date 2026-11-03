#!/usr/bin/env python3
"""Ordres POP/INF, vrais corps payer_ordre et périmètre militaire, cluster détruit.
Aucune connexion distante, aucun joueur réel. Cas annulés sauf concurrence fictive.
"""
import importlib.util,json,os,sys,tempfile,traceback
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('reliquats',R/'outils/bancs/banc-reliquats-379-local.py');h=importlib.util.module_from_spec(sp);sp.loader.exec_module(h)
def main():
 if os.environ.get('HG219_POSTGRES_BIN'):
  s=importlib.util.spec_from_file_location('pg17',R/'outils/baseline/epreuve-postgresql.py');p=importlib.util.module_from_spec(s);s.loader.exec_module(p);p.configurer_binaires(Path(os.environ['HG219_POSTGRES_BIN']))
 import pgserver,psycopg2
 from psycopg2.extras import Json
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-jauges-379-'),cleanup_mode='delete');c=None;cas=[]
 try:
  c=psycopg2.connect(srv.get_uri());q=c.cursor();q.execute('SHOW server_version_num');version=q.fetchone()[0]
  q.execute("CREATE ROLE authenticated;CREATE ROLE anon;CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;GRANT USAGE ON SCHEMA public,auth TO authenticated")
  for f,n in [('personnage-et-presence','personnages_donnees'),('economie','ordres_couts'),('economie','ordres_couts_inconnus'),('economie','ordres_couts_ecarts'),('banque','comptes_bancaires'),('politique-et-elections','presidence_memoire_ordres'),('immobilier-et-territoire','acquisitions_transactions_internes'),('immobilier-et-territoire','permis_transactions_internes'),('militaire','compagnies_militaires')]:h.table(q,'baseline/domaines/'+f+'/10_tables.sql',n)
  q.execute('ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE personnages_donnees ENABLE ROW LEVEL SECURITY;CREATE VIEW personnages AS SELECT * FROM personnages_donnees;ALTER TABLE ordres_couts_inconnus ADD PRIMARY KEY(fn);ALTER TABLE ordres_couts_ecarts ADD PRIMARY KEY(fn,pa,cost)')
  for n in ['mon_personnage','est_appel_serveur','est_mon_personnage','exiger_acteur']:q.execute(h.fonction('baseline/domaines/socle/20_fonctions.sql',n))
  q.execute(h.fonction('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre'))
  q.execute(h.fonction('baseline/domaines/militaire/20_fonctions-2.sql','militaire_inspection_perimetre'))
  q.execute((R/'baseline/seeds/95_a-regenerer/ordres_couts.sql').read_text())
  q.execute("INSERT INTO personnages_donnees(name,country,user_id,current_city,current_building,career,pa,hp,moral,resources,arg,liquide,stats)VALUES('Fixture','republic','00000000-0000-4000-9000-000000000001','capitale','assemblee','press',20,70,60,'{\"pop\":10,\"inf\":10,\"dis\":42}',100,100,'{\"INT\":12}');")
  migration=(R/'migrations/20261103004219_jauges_ordres_transactionnels.sql').read_text();q.execute('SAVEPOINT installation');q.execute(migration);q.execute('ROLLBACK TO SAVEPOINT installation');q.execute("SELECT to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)')IS NULL");assert q.fetchone()[0]
  q.execute(migration);q.execute(migration);cas.append({'cas':'installation_rollback_double_rejeu','ok':True})
  def own(sql,args=None):
   if sql.startswith('ROLLBACK'):q.execute(sql);q.execute('RESET ROLE');return
   q.execute('RESET ROLE');q.execute(sql,args)if args else q.execute(sql);return q.fetchone()[0]if q.description else None
  def rpc(ordre,ident=1,ctx=None,cur=None):
   cc=cur or q;cc.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/rpc/jauges_ordre_executer',true),set_config('request.jwt.claim.sub','00000000-0000-4000-9000-000000000001',true)");cc.execute('SELECT public.jauges_ordre_executer(%s,%s,%s)',(ordre,f'00000000-0000-4000-9000-{ident:012d}',Json(ctx or {})));return cc.fetchone()[0]
  def photo():return own("SELECT to_jsonb(d)FROM personnages_donnees d WHERE name='Fixture'")
  def case(n,fn):
   own('SAVEPOINT scenario')
   try:fn();cas.append({'cas':n,'ok':True})
   except Exception as e:cas.append({'cas':n,'ok':False,'erreur':str(e),'trace':traceback.format_exc(limit=4)})
   finally:own('ROLLBACK TO SAVEPOINT scenario')
  def journaliste():
   a=photo();v=rpc('observer_debats');b=photo();assert v['ok']and v['inf']==11 and b['pa']==19
   for k in a:
    if k not in ['resources','pa']:assert a[k]==b[k],k
   assert b['resources']==dict(a['resources'],inf=11)
  case('observer_paiement_et_gain_sans_autre_mutation',journaliste)
  def deux():
   assert rpc('observer_debats')['inf']==11;assert rpc('observer_debats',2)['inf']==12;assert photo()['pa']==18
  case('deux_gains_legitimes_deux_requetes',deux)
  def perdu():
   rpc('observer_debats');v=rpc('observer_debats');assert v['rejeu']and v['inf']==11 and photo()['pa']==19
   rpc('observer_debats',2);v=rpc('observer_debats');assert v['rejeu']and v['inf']==12
  case('reponse_perdue_rejeu_et_recu_ancien_ne_retablit_pas_snapshot',perdu)
  def triche():
   p=photo();v=rpc('observer_debats',ctx={'inf':500});assert v['raison']=='contexte_invalide'and photo()==p
  case('delta_falsifie_refuse_sans_paiement',triche)
  def manque():
   own("UPDATE personnages_donnees SET pa=0");p=photo();assert rpc('observer_debats')['raison']=='pa_insuffisants'and photo()==p
  case('fonds_PA_refus_sans_effet',manque)
  def rue():
   own("UPDATE personnages_donnees SET current_building=NULL");p=photo();assert rpc('observer_debats')['raison']=='pas_sur_place'and photo()==p
  case('presence_serveur',rue)
  def autre():
   own("UPDATE personnages_donnees SET career='craft'");v=rpc('observer_debats');assert v['inf']==10 and v['pa']==19
  case('non_journaliste_observe_sans_bonus',autre)
  def haut():
   own("UPDATE personnages_donnees SET resources='{\"pop\":100,\"inf\":99.5}'");v=rpc('observer_debats');assert v['inf']==100 and v['pop']==100
  case('plafond_et_fraction_historique',haut)
  def inspection():
   own("UPDATE personnages_donnees SET poste='{\"id\":\"min_def\"}'")
   a=rpc('inspecter_troupes',ctx={'niveau':'revue'});b=rpc('inspecter_troupes',2,{'niveau':'detaillee'});assert a['inf']==13 and b['inf']==18 and b['pa']==17
  case('inspection_meme_perimetre_revue_et_detaillee',inspection)
  def refuse():
   p=photo();assert rpc('inspecter_troupes',ctx={'niveau':'revue'})['ok']is False and photo()==p
  case('inspection_citoyen_refuse',refuse)
  def faim():
   p=photo();assert rpc('greve_faim')['raison']=='detention_requise'and photo()==p
   own("UPDATE personnages_donnees SET current_building='qhs-prison',est_emprisonne='{\"motif\":\"fixture\"}',hp=3")
   v=rpc('greve_faim');assert v['hp']==1 and v['pop']==13 and v['pa']==20;assert rpc('greve_faim')['pop']==13
  case('faim_detention_HP_plancher_et_rejeu',faim)
  def dossier():
   own("UPDATE personnages_donnees SET current_building='palais-gouvernement'");p=photo();assert rpc('consulter_dossiers_gouv')['raison']=='poste_requis'and photo()==p
   own("UPDATE personnages_donnees SET poste='{\"id\":\"min_info\"}'");v=rpc('consulter_dossiers_gouv');assert v['inf']==12 and v['pa']==18
  case('dossier_poste_serveur',dossier)
  def lie():
   rpc('observer_debats');p=photo();assert rpc('inspecter_troupes',ctx={'niveau':'revue'})['raison']=='requete_reutilisee'and photo()==p
  case('requete_liee_a_intention',lie)
  def panne():
   own("CREATE FUNCTION fixture_panne_recu()RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_recu';END$$;CREATE TRIGGER fixture_panne_recu BEFORE INSERT ON jauges_actions_recus FOR EACH ROW EXECUTE FUNCTION fixture_panne_recu()")
   p=photo();own('SAVEPOINT panne')
   try:rpc('observer_debats');raise AssertionError('panne absente')
   except psycopg2.Error as e:assert 'panne_recu'in str(e);own('ROLLBACK TO SAVEPOINT panne')
   assert photo()==p
  case('panne_recu_annule_PA_et_gain',panne)
  def droits():
   assert own("SELECT has_function_privilege('authenticated','jauges_ordre_executer(text,uuid,jsonb)','EXECUTE')")
   assert not own("SELECT has_function_privilege('anon','jauges_ordre_executer(text,uuid,jsonb)','EXECUTE')")
   assert not own("SELECT has_table_privilege('authenticated','jauges_actions_recus','INSERT')")
  case('recu_non_fabricable_par_client',droits)
  c.commit()
  def agir():
   cc=psycopg2.connect(srv.get_uri())
   try:
    v=rpc('observer_debats',777,cur=cc.cursor());cc.commit();return v
   finally:cc.close()
  with ThreadPoolExecutor(2)as pool:a,b=list(pool.map(lambda _:agir(),range(2)))
  assert a['inf']==b['inf']==11 and own("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==19
  cas.append({'cas':'deux_connexions_un_gain_un_paiement','ok':True})
  print(json.dumps({'production':False,'moteur':version,'tests':cas,'limites':['Payer_ordre et inspection réels du baseline ; pas un clone du catalogue vivant ni son interception blocus ajoutée ensuite.','Concurrence committée seulement dans le cluster détruit.']},ensure_ascii=False,indent=2));return 0 if all(t['ok']for t in cas)else 1
 finally:
  if c:c.rollback();c.close()
  srv.cleanup()
if __name__=='__main__':sys.exit(main())
