"""Certification locale uniquement : cluster PostgreSQL jetable, aucune cible externe."""
import json,os,subprocess,tempfile,re
from pathlib import Path
import psycopg2
R=Path(__file__).resolve().parents[3]
BIN=Path(os.environ.get('HG_I18N_PG_BIN','/workspace/hg-postgresql-17/bin'))
# Le processus de test ignore toute configuration PostgreSQL héritée.
for key in tuple(os.environ):
 if key.startswith('PG'):os.environ.pop(key)
def run(cmd,env=None):
 p=subprocess.run([str(x) for x in cmd],cwd=R,env=env,text=True,capture_output=True)
 if p.returncode:raise RuntimeError(p.stderr+p.stdout)
 return p.stdout
with tempfile.TemporaryDirectory(prefix='hg-i18n-cert17-') as tmp:
 base=Path(tmp);data=base/'data';sock=base/'socket';sock.mkdir()
 run([BIN/'initdb','-D',data,'-A','trust','-U','fixture','--locale=C','--encoding=UTF8'])
 started=False
 try:
  run([BIN/'pg_ctl','-D',data,'-l',base/'log','-o',f"-k {sock} -p 55499 -h ''",'-w','start']);started=True
  env={**os.environ,'PGHOST':str(sock),'PGPORT':'55499','PGUSER':'fixture','PGDATABASE':'postgres','PATH':str(BIN)+':'+os.environ['PATH']}
  print(run([BIN/'psql','-X','-v','ON_ERROR_STOP=1','-f','historique/i18n/banc-stockage-prive-jetable.sql'],env))
  print(run(['bash','outils/bancs/i18n/banc-concurrence-jetable.sh'],env))
  c=psycopg2.connect(host=str(sock),port=55499,user='fixture',dbname='postgres');q=c.cursor()
  for domain,name in [('personnage-et-presence','personnages_donnees'),('personnage-et-presence','organisations'),('communication','forum_topics'),('communication','forum_posts'),('communication','messages_chat'),('communication','salons_membres')]:
   src=(R/'baseline/domaines'/domain/'10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.'+name+r' \(.*?\n\);',src,re.S)[0])
  q.execute("CREATE SCHEMA auth;CREATE FUNCTION auth.uid()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;CREATE VIEW personnages AS SELECT * FROM personnages_donnees;GRANT USAGE ON SCHEMA auth TO authenticated")
  for file,name in [('baseline/domaines/socle/20_fonctions.sql','mon_personnage'),('migrations/20261103222000_forums_territoires_et_adhesions.sql','forum_lecture_autorisee'),('baseline/domaines/communication/20_fonctions.sql','chat_est_membre_salon'),('baseline/domaines/communication/20_fonctions.sql','chat_participe')]:
   src=(R/file).read_text();a=re.search(r'CREATE OR REPLACE FUNCTION public\.'+name+r'\(',src).start();m=re.search(r'AS\s+(\$\w*\$).*?\1;',src[a:],re.S);q.execute(src[a:a+m.end()])
  for table,policy in [('forum_topics','forum_lecture_autorisee(forum_id,country)'),('forum_posts','EXISTS(SELECT 1 FROM forum_topics t WHERE t.id=forum_posts.topic_id)'),('messages_chat','chat_participe(conversation_id,salon)')]:
   q.execute('ALTER TABLE '+table+' ENABLE ROW LEVEL SECURITY;GRANT SELECT ON '+table+' TO authenticated;CREATE POLICY fixture_i18n_lecture ON '+table+' FOR SELECT TO authenticated USING('+policy+')')
  q.execute("UPDATE rp_i18n_configuration SET enabled=true,daily_requests=20,daily_characters=10000 WHERE singleton=1")
  for i,name in enumerate(['Alpha','Beta','Gamma'],1):q.execute("INSERT INTO personnages_donnees(name,user_id,country,current_city)VALUES(%s,%s,%s,'capitale')",(name,'00000000-0000-4000-9000-'+str(i).zfill(12),'narco' if name=='Gamma'else'republic'))
  q.execute("INSERT INTO organisations(id,country_origine,data)VALUES('prive','republic','{\"chef\":\"Alpha\",\"membres\":[\"Alpha\",\"Beta\"]}')")
  for ident,forum in [('org-topic','org_prive'),('national-topic','national'),('local-topic','local_capitale')]:q.execute("INSERT INTO forum_topics(id,forum_id,country,title,author)VALUES(%s,%s,'republic','Bonjour sujet','Alpha')",(ident,forum))
  q.execute("INSERT INTO forum_posts(id,topic_id,author,content)VALUES('org-post','org-topic','Alpha','Bonjour contenu privé');INSERT INTO salons_membres(id,salon_id,membre)VALUES('fixture-a','prive','Alpha'),('fixture-b','prive','Beta')")
  for ident,conv,salon in [('salon-message','prive',True),('direct-message','Alpha__Beta',False),('timeout-message','Alpha__Beta',False)]:q.execute("INSERT INTO messages_chat(id,conversation_id,auteur,message,salon)VALUES(%s,%s,'Alpha','Bonjour message',%s)",(ident,conv,salon))
  c.commit();c.close()
  print(run(['node','outils/audits/preuves-i18n-377-cloture-20261108/chaines-rls.mjs'],env))
  connection=lambda:psycopg2.connect(host=str(sock),port=55499,user='fixture',dbname='postgres')
  denies=0
  for role in ['anon','authenticated']:
   for sql in [*['SELECT * FROM rp_i18n_'+t for t in ['cache','usage','configuration','reservations']],"SELECT rp_i18n_cache_lire(repeat('a',64))","SELECT rp_i18n_cache_ecrire(repeat('a',64),'fixture')","SELECT rp_i18n_budget_reserver('33333333-3333-4333-8333-333333333333',repeat('a',64),1)"]:
    c=connection()
    try:
     q=c.cursor();q.execute('SET LOCAL ROLE '+role);q.execute(sql)
    except psycopg2.Error as e:assert e.pgcode=='42501';denies+=1
    else:raise AssertionError('accès privé non refusé')
    finally:c.rollback();c.close()
  c=connection();q=c.cursor();q.execute('SHOW server_version');version=q.fetchone()[0];c.close()
  assert version.startswith('17.6') and denies==14
  print(json.dumps({'postgresql':version,'stockage':True,'concurrence_deux_processus':True,'refus_anon_authenticated':denies,'production':False}))
 finally:
  if started:run([BIN/'pg_ctl','-D',data,'-m','immediate','-w','stop'])
