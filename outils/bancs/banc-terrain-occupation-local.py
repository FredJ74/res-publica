#!/usr/bin/env python3
"""#94 : visites et tirage reels sur PostgreSQL jetable, identite simulee."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import re,tempfile,json
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-terrain-'),cleanup_mode='delete')
 try:
  c=psycopg2.connect(srv.get_uri());c.autocommit=True;q=c.cursor()
  q.execute('''CREATE ROLE anon;CREATE ROLE authenticated;
  CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,current_building text);
  CREATE TABLE terrains_etat(id text PRIMARY KEY,country text,building_id text,proprietaire text,data text,updated_at timestamptz);
  CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT coalesce(nullif(current_setting('hg.fixture',true),''),'Fixture')$$;
  INSERT INTO personnages_donnees VALUES('Fixture','republic','capitale','terrain-a-batir-1'),('Autre','republic','capitale','terrain-a-batir-1');
  INSERT INTO terrains_etat VALUES('republic_terrain-a-batir-1','republic','terrain-a-batir-1',NULL,'{"city":"capitale","surface":1234,"prix":5678}',now());''')
  source=(R/'baseline/domaines/immobilier-et-territoire/20_fonctions.sql').read_text()
  for fn in ['terrain_etat_lire','terrain_etat_fusionner_interne']:
   a=source.index('CREATE OR REPLACE FUNCTION public.'+fn+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',source[a:],re.S);q.execute(source[a:a+m.end()])
  sql=(R/'migrations/20261022222907_terrain_occupation_visites.sql').read_text();q.execute(sql)
  n=0
  def check(v):
   nonlocal n
   assert v;n+=1
  q.execute("SELECT prosrc FROM pg_proc WHERE oid='terrain_occupation_tirer_interne()'::regprocedure");corps=q.fetchone()[0]
  expression=corps.strip().removeprefix('SELECT ').removesuffix(';').replace('random()','x.valeur')
  q.execute('WITH x(valeur) AS (VALUES(0::numeric),(.249999),(.25),(.499999),(.5),(.749999),(.75),(.999999)) SELECT '+expression+' FROM x')
  check([r[0] for r in q.fetchall()]==[None,None,'squatter_cool','squatter_cool','squatter_agr','squatter_agr','cadavre','cadavre'])
  def appel(cur=q):
   cur.execute("SELECT terrain_occupation_lire('terrain-a-batir-1')");return cur.fetchone()[0]
  def lire():
   q.execute('SELECT data::jsonb FROM terrains_etat');return q.fetchone()[0]
  r=appel();check(r['ok']);avant=lire();check(avant['surface']==1234 and avant['prix']==5678)
  check(appel()['etat']==avant)
  q.execute("UPDATE personnages_donnees SET current_city=current_city WHERE name='Fixture'");check(appel()['etat']==avant)
  # Aucune nouvelle generation si un autre visiteur est encore sur le terrain.
  q.execute("SET hg.fixture='Autre'");check(appel()['etat']==avant)
  q.execute("UPDATE personnages_donnees SET current_building=NULL WHERE name='Fixture'")
  q.execute('SELECT count(*) FROM terrain_visites_actives');check(q.fetchone()[0]==1)
  check(appel()['etat']==avant)
  q.execute("UPDATE personnages_donnees SET current_building=NULL WHERE name='Autre'")
  q.execute('SELECT count(*) FROM terrain_visites_actives');check(q.fetchone()[0]==0)
  check(appel()['raison']=='pas_sur_place')
  q.execute("SET hg.fixture='Fixture';UPDATE personnages_donnees SET current_building='terrain-a-batir-1' WHERE name='Fixture'")
  # Forcer le fournisseur de hasard seulement pour observer la fermeture/reouverture de visite.
  q.execute("CREATE OR REPLACE FUNCTION terrain_occupation_tirer_interne() RETURNS text LANGUAGE sql AS $$SELECT 'cadavre'::text$$")
  check(appel()['etat']['pnj']=='cadavre')
  def sortir():q.execute("UPDATE personnages_donnees SET current_building=NULL WHERE name='Fixture';UPDATE personnages_donnees SET current_building='terrain-a-batir-1' WHERE name='Fixture'")
  def patch(d):q.execute('UPDATE terrains_etat SET data=(data::jsonb||%s::jsonb)::text',(json.dumps(d),))
  for protection in [{'compromis':True},{'proprietaire':'pj:Fixture'},{'occupationScellee':True},{'succession_gel':'succession'},{'policeAppellee':'legale'},{'enqueteJusqua':4102444800000}]:
   q.execute("UPDATE terrains_etat SET data='{\"city\":\"capitale\",\"surface\":1234,\"prix\":5678,\"pnj\":\"squatter_agr\",\"occupationInitialisee\":true}'")
   patch(protection);sortir();check(appel()['etat']['pnj']=='squatter_agr')
  # Pays et ville doivent provenir de la position serveur.
  sortir();q.execute("UPDATE personnages_donnees SET country='soviet' WHERE name='Fixture'");check(appel()['raison']=='terrain_introuvable')
  q.execute("UPDATE personnages_donnees SET country='republic',current_city='autre' WHERE name='Fixture'");check(appel()['raison']=='terrain_incoherent')
  q.execute("UPDATE personnages_donnees SET current_city='capitale' WHERE name='Fixture'")
  q.execute("SELECT has_table_privilege('authenticated','terrain_visites_actives','INSERT'),has_function_privilege('authenticated','terrain_occupation_tirer_interne()','EXECUTE'),has_function_privilege('anon','terrain_occupation_lire(text)','EXECUTE')");check(q.fetchone()==(False,False,False))
  def concurrent(_):
   with psycopg2.connect(srv.get_uri()) as cc:return appel(cc.cursor())
  with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(concurrent,range(2)))
  check(all(x['ok'] for x in rr));check(rr[0]['etat']==rr[1]['etat'])
  # Contre-epreuve : retirer le verrou de visite doit changer le terrain au rechargement.
  q.execute("UPDATE terrains_etat SET data='{\"city\":\"capitale\",\"occupationInitialisee\":true,\"pnj\":null}'")
  avant=lire();check(appel()['etat']==avant)
  q.execute('DELETE FROM terrain_visites_actives');check(appel()['etat']!=avant)
  print(json.dumps({'ok':True,'assertions':n,'production':False,'identite':'simulee'}))
 finally:srv.cleanup()
if __name__=='__main__':main()
