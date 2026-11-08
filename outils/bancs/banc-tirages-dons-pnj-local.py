#!/usr/bin/env python3
"""Corps réels de débit et de dispatcher, PostgreSQL jetable détruit, aucun accès distant."""
import importlib.util,json,re,tempfile,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
s=importlib.util.spec_from_file_location('h',R/'outils/bancs/banc-reliquats-379-local.py');h=importlib.util.module_from_spec(s);s.loader.exec_module(h)
def main():
 import pgserver,psycopg2
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-tirages-dons-'),cleanup_mode='delete');c=None
 try:
  c=psycopg2.connect(srv.get_uri());q=c.cursor()
  q.execute("CREATE ROLE authenticated;CREATE ROLE anon;CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;GRANT USAGE ON SCHEMA auth,public TO authenticated")
  for d,n in [('personnage-et-presence','personnages_donnees'),('banque','comptes_bancaires'),('finances-publiques','fonds_debits'),('socle-PNJ','pnj_membres'),('socle-PNJ','pnj_employes_metier')]:h.table(q,'baseline/domaines/'+d+'/10_tables.sql',n)
  q.execute('ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE personnages_donnees ENABLE ROW LEVEL SECURITY;CREATE VIEW personnages AS SELECT * FROM personnages_donnees')
  for n in ['mon_personnage','est_appel_serveur','est_mon_personnage','exiger_acteur']:q.execute(h.fonction('baseline/domaines/socle/20_fonctions.sql',n))
  src=(R/'baseline/domaines/banque/20_fonctions.sql').read_text();defs=list(re.finditer(r'CREATE OR REPLACE FUNCTION public.helvetia_debiter_fonds_ordinaires\(',src))
  for m in reversed(defs):
   end=re.search(r'AS\s+(\$\w*\$).*?\1;',src[m.start():],re.S).end();q.execute(src[m.start():m.start()+end])
  q.execute(h.fonction('baseline/domaines/finances-publiques/20_fonctions-1.sql','debiter_fonds_ordinaires'))
  q.execute(h.fonction('baseline/domaines/socle-PNJ/20_fonctions.sql','pnj_caracteristiques_base'))
  q.execute(h.fonction('baseline/domaines/personnage-et-presence/20_fonctions-1.sql','employe_mes_employes'))
  base=(R/'migrations/20261103004219_jauges_ordres_transactionnels.sql').read_text()
  q.execute(re.search(r'CREATE TABLE IF NOT EXISTS public.jauges_actions_recus \(.*?\n\);',base,re.S)[0]);q.execute('ALTER TABLE jauges_actions_recus ENABLE ROW LEVEL SECURITY')
  q.execute(h.fonction('migrations/20261103203000_inspection_cargaisons_jauges_serveur_379.sql','jauges_ordre_executer'))
  dons=(R/'migrations/20261103235500_pop_inf_dons_pnj_379.sql').read_text()
  q.execute(re.search(r'CREATE TABLE IF NOT EXISTS public.pnj_lieux_metiers\(.*?\)\);',dons,re.S)[0])
  q.execute(h.fonction('migrations/20261103235500_pop_inf_dons_pnj_379.sql','pnj_don_metier_interne'))
  q.execute(re.search(r'DO \$patch\$.*?END \$patch\$;',dons,re.S)[0])
  q.execute('REVOKE ALL ON FUNCTION jauges_ordre_executer(text,uuid,jsonb) FROM PUBLIC,anon;GRANT EXECUTE ON FUNCTION jauges_ordre_executer(text,uuid,jsonb) TO authenticated')
  migration=(R/'migrations/20261108130723_dons_pnj_dis_serveur.sql').read_text()
  q.execute('SAVEPOINT avant_patch');q.execute(migration);q.execute('ROLLBACK TO SAVEPOINT avant_patch');q.execute("SELECT to_regprocedure('public.don_pnj_dup_interne(text)')IS NULL");assert q.fetchone()[0];q.execute(migration);q.execute(migration)
  if '--contre-sans-jet' in sys.argv:
   q.execute("SELECT pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure)");d=q.fetchone()[0]
   assert d.count('don_jet:=floor(random()*100)::integer+1;')==1
   q.execute(d.replace('don_jet:=floor(random()*100)::integer+1;','don_jet:=1;'))
  if '--contre-sans-dis' in sys.argv:
   q.execute("SELECT pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure)");d=q.fetchone()[0]
   assert d.count('IF don_delta<>0 THEN')==1
   q.execute(d.replace('IF don_delta<>0 THEN','IF false THEN'))
  q.execute("SELECT set_config('hg.banc_jetable','tirages_dons',false)");c.commit()
  # Le banc se termine par ROLLBACK ; aucune fixture ne survit.
  sql=(R/'outils/bancs/banc-tirages-dons-pnj.sql').read_text();q.execute(sql)
  q.execute("SELECT count(*)FROM public.personnages_donnees");assert q.fetchone()[0]==0
  bilan=next(json.loads(n.split('BILAN_TIRAGES_DONS ',1)[1].strip()) for n in c.notices if 'BILAN_TIRAGES_DONS 'in n)
  from concurrent.futures import ThreadPoolExecutor
  from psycopg2.extras import Json
  q.execute("INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,pa,hp,arg,liquide,stats,resources)VALUES('Course','00000000-0000-4000-9000-000000008002','republic','capitale','banc','salle',30,100,1000,1000,'{\"DUP\":8}','{\"pop\":50,\"inf\":50,\"dis\":50}');INSERT INTO pnj_lieux_metiers(pays,ville,building_id,room_id,nom,job,rel)VALUES('republic','capitale','banc','salle','HG-Course','commissaire','neutral')");c.commit()
  def appel(cle,montant):
   cc=psycopg2.connect(srv.get_uri())
   try:
    cur=cc.cursor();cur.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/rpc/jauges_ordre_executer',true),set_config('request.jwt.claim.sub','00000000-0000-4000-9000-000000008002',true)")
    cur.execute('SELECT jauges_ordre_executer(%s,%s,%s)',('don_argent_pnj',cle,Json({'nom':'HG-Course','montant':montant,'contrat_dis':1})));v=cur.fetchone()[0];cc.commit();return v
   finally:cc.close()
  with ThreadPoolExecutor(2) as ex:v=list(ex.map(lambda _:appel('00000000-0000-4000-9000-000000009001',100),range(2)))
  assert all(x.get('ok')for x in v) and sum(bool(x.get('rejeu'))for x in v)==1 and v[0]['dis_jet']==v[1]['dis_jet']
  q.execute("SELECT liquide,(SELECT count(*)FROM fonds_debits WHERE acteur='Course')FROM personnages_donnees WHERE name='Course'");assert q.fetchone()==(900,1)
  q.execute("UPDATE personnages_donnees SET liquide=1000,arg=1000 WHERE name='Course'");c.commit()
  with ThreadPoolExecutor(2) as ex:v=list(ex.map(lambda i:appel('00000000-0000-4000-9000-'+str(9002+i).zfill(12),600),range(2)))
  assert sum(x.get('ok',False)for x in v)==1 and sum(x.get('raison')=='fonds_insuffisants'for x in v)==1
  q.execute("SELECT liquide FROM personnages_donnees WHERE name='Course'");assert q.fetchone()[0]==400
  print(json.dumps({'resultats':bilan,'banc':'tirages-dons','sql_annule':True,'installation_rollback_rejeu':True,'courses_authentifiees':2,'ok':True}))
 finally:
  if c:c.close()
  srv.cleanup()
if __name__=='__main__':main()
