#!/usr/bin/env python3
"""Ventes existantes et acquittements exacts, PostgreSQL local jetable."""
from pathlib import Path
import re,tempfile,json
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 s=pgserver.get_server(tempfile.mkdtemp(prefix='hg-ventes96-'),cleanup_mode='delete');db=psycopg2.connect(s.get_uri());db.autocommit=True;c=db.cursor();n=0
 def ok(v,m):
  nonlocal n
  assert v,m;n+=1;print('OK',m)
 try:
  c.execute("CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('test.uid',true),'')::uuid$$;CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT current_setting('test.nom',true)$$")
  for dom,tab in [('economie','ventes_snapshots'),('economie','entreprises'),('personnage-et-presence','personnages_donnees')]:
   src=(R/f'baseline/domaines/{dom}/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public\.'+tab+r' \(.*?\n\);',src,re.S)[0])
  c.execute("ALTER TABLE ventes_snapshots ADD PRIMARY KEY(id);ALTER TABLE ventes_snapshots ADD UNIQUE(requete);ALTER TABLE personnages_donnees ADD PRIMARY KEY(name)")
  src=(R/'baseline/domaines/economie/20_fonctions-2.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.ventes_snapshots_append_only()');b=src.index('$function$;',src.index('AS $function$',a))+len('$function$;');c.execute(src[a:b]);c.execute('CREATE TRIGGER vente_immuable BEFORE UPDATE OR DELETE ON ventes_snapshots FOR EACH ROW EXECUTE FUNCTION ventes_snapshots_append_only()')
  sql=(R/'migrations/20261022203000_journal_ventes_commerces.sql').read_text();c.execute(sql);c.execute(sql)
  c.execute("INSERT INTO personnages_donnees(name,country,user_id,id) VALUES('Proprio','republic','00000000-0000-4000-8000-000000000096','00000000-0000-4000-8000-000000000196'),('Tiers','republic','00000000-0000-4000-8000-000000000097','00000000-0000-4000-8000-000000000197');INSERT INTO entreprises(id,data) VALUES('fonds','{\"proprietaire\":\"Proprio\",\"enseigne\":\"Slava Chocolaterie\"}')")
  def vente(req):c.execute("INSERT INTO ventes_snapshots(requete,jour_paris,acheteur,vendeur,fonds_id,reference_id,nom_commercial,generique_id,quantite,prix_unitaire,montant_total,fiche_officielle) VALUES(%s,'2026-10-22','Arnie','Proprio','fonds','chocolat','Chocolat chaud','chocolat',1,20,20,'{}') ON CONFLICT(requete) DO NOTHING",(req,))
  for i in range(10):vente('vente-'+str(i))
  vente('vente-1');c.execute('SELECT count(*) FROM ventes_snapshots');ok(c.fetchone()[0]==10,'rejeu de la vente : aucun evenement duplique')
  def lire(nom='Proprio',uid='00000000-0000-4000-8000-000000000096',acquit=False):
   c.execute('RESET ROLE');c.execute("SELECT set_config('test.uid',%s,false),set_config('test.nom',%s,false)",(uid,nom));c.execute('SET ROLE authenticated');c.execute('SELECT journal_ventes_lire(%s)',(acquit,));return c.fetchone()[0]
  x=lire();ok(x['nonLues']==10 and len(x['evenements'])==10,'dix ventes hors connexion conservees avec alerte globale');ok(x['evenements'][0]['acheteur']=='Arnie' and x['evenements'][0]['montant']==20 and x['evenements'][0]['enseigne']=='Slava Chocolaterie','veritables donnees transactionnelles')
  x=lire(acquit=True);ok(x['nonLues']==0 and len(x['evenements'])==10,'ouverture acquitte dix ventes sans supprimer historique');ok(lire(acquit=True)['nonLues']==0,'double ouverture idempotente')
  c.execute('RESET ROLE');vente('vente-11');ok(lire()['nonLues']==1,'vente suivante reste non lue')
  x=lire('Tiers','00000000-0000-4000-8000-000000000097');ok(not x['evenements'] and x['nonLues']==0,'tiers ne lit ni acquitte les ventes du proprietaire');ok(lire()['nonLues']==1,'lecture du tiers ne retire pas alerte')
  try:lire('Proprio','00000000-0000-4000-8000-000000000097');raise AssertionError('UID forge accepte')
  except psycopg2.Error:ok(True,'nom seul insuffisant sans bon UID')
  c.execute('RESET ROLE');c.execute('BEGIN');vente('annulee');c.execute('ROLLBACK');ok(len(lire()['evenements'])==11,'vente annulee : aucune notification fantome')
  c.execute('RESET ROLE');c.execute("UPDATE entreprises SET data=jsonb_set(data,'{enseigne}','\"Autre nom\"')");ok(all(e['enseigne']=='Slava Chocolaterie' for e in lire()['evenements']),'enseigne historique preservee apres renommage')
  c.execute('RESET ROLE');c.execute("SELECT has_table_privilege('authenticated','journal_ventes_lectures','UPDATE'),has_function_privilege('anon','journal_ventes_lire(boolean)','EXECUTE')");ok(c.fetchone()==(False,False),'pas de modification directe ni lecture anonyme')
  # Bloquer l'acquittement APRES sa photographie et livrer une nouvelle vente entretemps.
  from concurrent.futures import ThreadPoolExecutor
  import time
  c.execute("CREATE FUNCTION lecture_attendre() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN PERFORM pg_advisory_xact_lock(96);RETURN NEW;END$$;CREATE TRIGGER lecture_attendre BEFORE INSERT ON journal_ventes_lectures FOR EACH ROW EXECUTE FUNCTION lecture_attendre();SELECT pg_advisory_lock(96)")
  def consultation():
   with psycopg2.connect(s.get_uri()) as cx:
    q=cx.cursor();q.execute("SELECT set_config('test.uid','00000000-0000-4000-8000-000000000096',true),set_config('test.nom','Proprio',true);SET LOCAL ROLE authenticated");q.execute('SELECT journal_ventes_lire(true)');return q.fetchone()[0]
  with ThreadPoolExecutor(max_workers=1) as ex:
   futur=ex.submit(consultation);bloque=False
   for _ in range(300):
    c.execute("SELECT EXISTS(SELECT 1 FROM pg_locks WHERE locktype='advisory' AND NOT granted)")
    if c.fetchone()[0]:bloque=True;break
    time.sleep(.01)
   try:
    ok(bloque,'acquittement concurrent effectivement bloque apres photographie');vente('pendant-consultation')
   finally:c.execute('SELECT pg_advisory_unlock(96)')
   resultat=futur.result(timeout=10)
  ok(len(resultat['evenements'])==11 and lire()['nonLues']==1,'vente concurrente non affichee reste non lue')
  print(f'{n}/{n} assertions, aucune transaction reelle.')
 finally:db.close();s.cleanup()
if __name__=='__main__':main()
