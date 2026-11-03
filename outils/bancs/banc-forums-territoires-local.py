#!/usr/bin/env python3
"""Tables/identité/politiques réelles du baseline ; PostgreSQL détruit, aucun PJ réel.
Les scénarios restent sous authenticated/anon et sont annulés. Pas un clone vivant.
"""
import importlib.util,json,os,re,sys,tempfile,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
MIGRATION=ROOT/'migrations/20261103222000_forums_territoires_et_adhesions.sql'
def fonction(f,nom):
 s=(ROOT/f).read_text();a=re.search(r'CREATE OR REPLACE FUNCTION public\.'+nom+r'\(',s).start();m=re.search(r'AS\s+(\$\w*\$).*?\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 if os.environ.get('HG219_POSTGRES_BIN'):
  spec=importlib.util.spec_from_file_location('pg17',ROOT/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.configurer_binaires(Path(os.environ['HG219_POSTGRES_BIN']))
 import pgserver,psycopg2
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-forums422-'),cleanup_mode='delete');db=None;tests=[]
 try:
  db=psycopg2.connect(srv.get_uri());q=db.cursor();q.execute('SHOW server_version_num');version=q.fetchone()[0]
  q.execute("CREATE ROLE authenticated;CREATE ROLE anon;CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;GRANT USAGE ON SCHEMA public,auth TO authenticated,anon")
  for domaine,nom in [('personnage-et-presence','personnages_donnees'),('personnage-et-presence','organisations'),('communication','forum_topics'),('communication','forum_posts')]:
   s=(ROOT/'baseline/domaines'/domaine/'10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
  q.execute(fonction('baseline/domaines/socle/20_fonctions.sql','est_appel_serveur'))
  vue=(ROOT/'baseline/domaines/personnage-et-presence/40_vues.sql').read_text();vue=vue[vue.index('CREATE OR REPLACE VIEW public.personnages AS'):].split(';',1)[0]+';';q.execute(vue)
  q.execute(fonction('baseline/domaines/socle/20_fonctions.sql','mon_personnage'))
  q.execute('ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE organisations ADD PRIMARY KEY(id);ALTER TABLE forum_topics ADD PRIMARY KEY(id);ALTER TABLE forum_posts ADD PRIMARY KEY(id);ALTER TABLE forum_posts ADD FOREIGN KEY(topic_id)REFERENCES forum_topics(id);ALTER TABLE forum_topics ENABLE ROW LEVEL SECURITY;ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;GRANT SELECT ON forum_topics,forum_posts TO anon;GRANT SELECT,INSERT,UPDATE,DELETE ON forum_topics,forum_posts TO authenticated')
  policies=(ROOT/'baseline/domaines/communication/60_rls-policies.sql').read_text()
  for sql in re.findall(r'CREATE POLICY forum_(?:topics|posts)_.*?;',policies,re.S):q.execute(sql)
  for i,nom,pays,ville in [(1,'Alice','republic','capitale'),(2,'Bob','narco','ville_a'),(3,'Chef','republic','ville_a'),(4,'Tiers','republic','ville_a')]:
   q.execute('INSERT INTO personnages_donnees(name,user_id,country,current_city)VALUES(%s,%s,%s,%s)',(nom,f'00000000-0000-4000-9000-{i:012d}',pays,ville))
  q.execute("INSERT INTO organisations(id,country_origine,data)VALUES('club','republic','{\"chef\":\"Chef\",\"membres\":[{\"nom\":\"Alice\"},\"Bob\"]}')")
  for id,forum,pays in [('lc','local_capitale','republic'),('la','local_ville_a','republic'),('na','local_ville_a','narco'),('nr','national','republic'),('nn','national','narco'),('pr','org_club','republic'),('pres','presidence','republic'),('gouv','gouvernement','republic'),('presse','presse','narco'),('inter','international','narco'),('sport','sport','narco')]:
   q.execute("INSERT INTO forum_topics(id,forum_id,country,title,author)VALUES(%s,%s,%s,'Sujet fictif','Alice')",(id,forum,pays));q.execute("INSERT INTO forum_posts(id,topic_id,author,content)VALUES(%s,%s,'Alice','Réponse fictive')",('p-'+id,id))
  q.execute((ROOT/'migrations/20261103010231_forum_publications_jauges_serveur.sql').read_text())
  # Entrée de fixture authentifiée vers le helper privé, comme depuis le moteur
  # existant. Elle n'applique aucun effet POP/INF et n'existe pas en production.
  q.execute("CREATE FUNCTION fixture_publication(p_id uuid,p_message jsonb)RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $$SELECT public.forum_publication_jauges_interne(public.mon_personnage(),p_id,p_message)$$;REVOKE ALL ON FUNCTION fixture_publication(uuid,jsonb)FROM PUBLIC;GRANT EXECUTE ON FUNCTION fixture_publication(uuid,jsonb)TO authenticated")
  migration=MIGRATION.read_text();q.execute('SAVEPOINT installation');q.execute(migration);q.execute('ROLLBACK TO SAVEPOINT installation');q.execute("SELECT to_regprocedure('public.forum_lecture_autorisee(text,text)')IS NULL");assert q.fetchone()[0]
  q.execute(migration);q.execute(migration);tests.append({'cas':'migration_annulation_et_double_rejeu','ok':True})
  q.execute("SELECT prosrc FROM pg_proc WHERE oid='public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure");corps=q.fetchone()[0]
  original=(ROOT/'migrations/20261103010231_forum_publications_jauges_serveur.sql').read_text().split('AS $function$',1)[1].split('$function$;',1)[0]
  assert corps.split('auteur:=a.name;',1)[1]==original.split('auteur:=a.name;',1)[1]
  tests.append({'cas':'publication_ecritures_et_recompense_existantes_inchangees','ok':True})
  if '--contre-publication'in sys.argv:q.execute((ROOT/'migrations/20261103010231_forum_publications_jauges_serveur.sql').read_text())
  if '--contre'in sys.argv:
   q.execute('ALTER POLICY forum_topics_lecture ON forum_topics USING(true);ALTER POLICY forum_posts_lecture ON forum_posts USING(true)')
  def own(sql,args=()):
   if sql.startswith('ROLLBACK'):q.execute(sql);q.execute('RESET ROLE');return
   q.execute('RESET ROLE');q.execute(sql,args);return q.fetchall()if q.description else q.rowcount
  def acteur(i=1,role='authenticated'):
   q.execute('RESET ROLE');q.execute("SELECT set_config('role',%s,true),set_config('request.path','/forum_topics',true),set_config('request.jwt.claim.sub',%s,true)",(role,f'00000000-0000-4000-9000-{i:012d}'if i else''))
  def lire(table='forum_topics',col='id'):
   q.execute('SELECT '+col+' FROM '+table+' ORDER BY '+col);return [r[0]for r in q.fetchall()]
  def cas(n,fn):
   own('SAVEPOINT cas')
   try:fn();tests.append({'cas':n,'ok':True})
   except Exception as e:tests.append({'cas':n,'ok':False,'erreur':str(e),'trace':traceback.format_exc(limit=3)})
   finally:own('ROLLBACK TO SAVEPOINT cas')
  for i,attendus in [(1,['gouv','inter','lc','nr','pr','pres','presse','sport']),(2,['gouv','inter','na','nn','pr','pres','presse','sport']),(3,['gouv','inter','la','nr','pr','pres','presse','sport']),(4,['gouv','inter','la','nr','pres','presse','sport'])]:
   def lecture(i=i,attendus=attendus):acteur(i);assert lire()==sorted(attendus);assert lire('forum_posts')==sorted('p-'+x for x in attendus)
   cas('sujets_et_reponses_identite_'+str(i),lecture)
  def voyage():
   acteur();assert 'lc'in lire()and 'la'not in lire()
   own("UPDATE personnages_donnees SET current_city='ville_a'WHERE name='Alice'");acteur();assert 'la'in lire()and 'lc'not in lire()and 'nr'in lire()
   own("UPDATE personnages_donnees SET current_city='capitale'WHERE name='Alice'");acteur();assert 'lc'in lire()and 'la'not in lire()
  cas('aller_retour_local_et_national_permanent',voyage)
  def territoire():
   own("UPDATE personnages_donnees SET country='narco',current_city='ville_a'WHERE name='Alice'");acteur();ids=lire();assert 'na'in ids and 'nn'in ids and 'nr'not in ids and 'la'not in ids
   q.execute("SELECT count(*)FROM forum_posts WHERE topic_id='la'");assert q.fetchone()[0]==0
   q.execute("SELECT forum_lecture_autorisee('local_ville_a','republic')");assert q.fetchone()[0]is False
  cas('pays_homonyme_et_acces_direct_isoles',territoire)
  def adhesion():
   own("UPDATE organisations SET data='{\"chef\":\"Chef\",\"membres\":[]}'WHERE id='club'");acteur();assert 'pr'not in lire()and 'p-pr'not in lire('forum_posts')
   acteur(3);assert 'pr'in lire()
   own("UPDATE organisations SET data='{\"chef\":\"Chef\",\"membres\":[{\"nom\":\"Tiers\"}]}'WHERE id='club'");acteur(4);assert 'pr'in lire()
  cas('perte_adhesion_chef_et_nouvelle_adhesion',adhesion)
  def organisation_invalide():
   own("UPDATE organisations SET data='invalide'WHERE id='club'");acteur();assert 'pr'not in lire()and 'p-pr'not in lire('forum_posts')
  cas('organisation_invalide_aucune_fuite_ni_panne_globale',organisation_invalide)
  def anonyme():acteur(0,'anon');assert lire()==['gouv','inter','pres','presse','sport'];assert lire('forum_posts')==['p-gouv','p-inter','p-pres','p-presse','p-sport']
  cas('anonyme_territoriaux_prives_fermes_institutions_inchangees',anonyme)
  def rejet(sql):
   own('SAVEPOINT refus');acteur()
   try:q.execute(sql);raise AssertionError('écriture acceptée')
   except psycopg2.errors.InsufficientPrivilege:own('ROLLBACK TO SAVEPOINT refus')
  for nom,sql in [('sujet_pays_etranger',"INSERT INTO forum_topics(id,forum_id,country,title,author)VALUES('x','national','narco','x','Alice')"),('sujet_ville_absente',"INSERT INTO forum_topics(id,forum_id,country,title,author)VALUES('x','local_ville_a','republic','x','Alice')"),('reponse_sujet_etranger',"INSERT INTO forum_posts(id,topic_id,author,content)VALUES('x','na','Alice','x')"),('reponse_usurpation',"INSERT INTO forum_posts(id,topic_id,author,content)VALUES('x','lc','Chef','x')"),('deplacer_sujet',"UPDATE forum_topics SET forum_id='local_ville_a'WHERE id='lc'")]:cas('refus_'+nom,lambda sql=sql:rejet(sql))
  def publication():
   acteur();q.execute("INSERT INTO forum_topics(id,forum_id,country,title,author,author_real)VALUES('officiel','national','republic','x','Auteur institutionnel','Alice')");q.execute("INSERT INTO forum_posts(id,topic_id,author,author_real,content)VALUES('officiel-post','officiel','Auteur institutionnel','Alice','x')");assert 'officiel'in lire()
  cas('publication_institutionnelle_author_real_conservee',publication)
  def suppression():
   own("UPDATE organisations SET data='{\"chef\":\"Chef\",\"membres\":[]}'WHERE id='club'");acteur()
   q.execute("DELETE FROM forum_posts WHERE id='p-pr'");assert q.rowcount==0
   q.execute("DELETE FROM forum_topics WHERE id='pr'");assert q.rowcount==0
   q.execute("UPDATE forum_posts SET content='interdit'WHERE id='p-pr'");assert q.rowcount==0
  cas('ancien_auteur_non_adherent_ne_modifie_ni_supprime',suppression)
  numero_publication=[98]
  def publier(message,i=1):
   numero_publication[0]+=1
   acteur(i);q.execute('SELECT fixture_publication(%s,%s::jsonb)',(f'00000000-0000-4000-9000-{numero_publication[0]:012d}',json.dumps(message)));return q.fetchone()[0]
  def chef_publication():
   v=publier({'forum':'org_club','titre':'Privé','contenu':'x'},3);assert v['ok'],v
   v=publier({'topic':v['topic'],'contenu':'Réponse étrangère adhérente'},2);assert v['ok'],v
  cas('publication_transactionnelle_chef_et_membre_etranger',chef_publication)
  def tiers_publication():
   v=publier({'forum':'org_club','titre':'Intrusion','contenu':'x'},4);assert not v['ok'],v
   v=publier({'topic':'pr','contenu':'Intrusion'},4);assert not v['ok'],v
  cas('publication_transactionnelle_tiers_refuse_sujet_et_reponse',tiers_publication)
  def ancien_local():
   v=publier({'topic':'la','contenu':'Hors ville'});assert not v['ok'],v
   v=publier({'topic':'nn','contenu':'Hors pays'});assert not v['ok'],v
  cas('publication_transactionnelle_hors_ville_et_pays_refusee',ancien_local)
  def garde():
   own('CREATE POLICY fixture_lecture ON forum_topics FOR SELECT USING(true)');own('SAVEPOINT garde')
   try:own(migration);raise AssertionError('politique concurrente acceptée')
   except psycopg2.Error as e:assert 'forum_politique_lecture_non_examinee'in str(e);own('ROLLBACK TO SAVEPOINT garde')
  cas('politique_permissive_concurrente_refusee',garde)
  def garde_definition(sql,motif):
   own(sql);own('SAVEPOINT definition')
   try:own(migration);raise AssertionError('définition non examinée acceptée')
   except psycopg2.Error as e:assert motif in str(e);own('ROLLBACK TO SAVEPOINT definition')
  cas('RLS_inactive_refusee',lambda:garde_definition('ALTER TABLE forum_posts DISABLE ROW LEVEL SECURITY','forum_RLS_inactive'))
  cas('fonction_inconnue_pas_ecrasee',lambda:garde_definition("CREATE OR REPLACE FUNCTION forum_lecture_autorisee(p_forum text,p_pays text)RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT true$$",'forum_definition_non_examinee'))
  cas('publication_inconnue_pas_ecrasee',lambda:garde_definition("CREATE OR REPLACE FUNCTION forum_publication_jauges_interne(p_acteur text,p_requete uuid,p_message jsonb)RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$SELECT '{}'::jsonb$$",'forum_publication_definition_non_examinee'))
  print(json.dumps({'production':False,'moteur':version,'contre':'--contre'in sys.argv,'contre_publication':'--contre-publication'in sys.argv,'tests':tests,'limite':'Tables, vue personnages et mon_personnage du baseline ; auth.uid de fixture. Pas un clone du catalogue vivant, aucun HTTP production.'},ensure_ascii=False,indent=2));return 0 if all(t['ok']for t in tests)else 1
 finally:
  if db:db.rollback();db.close()
  srv.cleanup()
if __name__=='__main__':sys.exit(main())
