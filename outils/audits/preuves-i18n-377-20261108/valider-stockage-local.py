import pgserver,psycopg2,tempfile,subprocess,os,json
from pathlib import Path
root=Path(__file__).resolve().parents[3]; srv=pgserver.get_server(tempfile.mkdtemp(prefix='audit377-pg-'),cleanup_mode='delete')
try:
 c=psycopg2.connect(srv.get_uri());q=c.cursor();q.execute('SHOW server_version');version=q.fetchone()[0];params=c.get_dsn_parameters();c.close()
 env=os.environ.copy();env.update({'PGHOST':params['host'],'PGPORT':params['port'],'PGUSER':params['user'],'PGDATABASE':params['dbname'],'PATH':str(Path(pgserver.__file__).parent/'pginstall/bin')+':'+env['PATH']})
 for cmd in [['psql','-X','-v','ON_ERROR_STOP=1','-f','historique/i18n/banc-stockage-prive-jetable.sql'],['bash','outils/bancs/i18n/banc-concurrence-jetable.sh']]:
  r=subprocess.run(cmd,cwd=root,env=env,text=True,capture_output=True);print(r.stdout);print(r.stderr);assert r.returncode==0
 denies=0
 for role in ['anon','authenticated']:
  for query in [
   'SELECT * FROM public.rp_i18n_'+t for t in ['cache','usage','configuration','reservations']
  ]+[
   "SELECT public.rp_i18n_cache_lire(repeat('a',64))",
   "SELECT public.rp_i18n_cache_ecrire(repeat('a',64),'fixture')",
   "SELECT public.rp_i18n_budget_reserver('33333333-3333-4333-8333-333333333333',repeat('a',64),1)"
  ]:
   c=psycopg2.connect(srv.get_uri());q=c.cursor()
   try:
    q.execute('SET LOCAL ROLE '+role);q.execute(query)
   except psycopg2.Error as err:
    assert err.pgcode=='42501',err.pgcode;denies+=1
   else:raise AssertionError('accès privé non refusé : '+role)
   finally:c.rollback();c.close()
 assert denies==14
 print(json.dumps({'refus_reels_anon_authenticated':denies,'postgresql':version,'banc_stockage':True,'concurrence_deux_processus':True,'production':False}))
finally:srv.cleanup()
