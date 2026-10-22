#!/usr/bin/env python3
"""RLS et decisions successorales reelles sur PostgreSQL jetable, aucune donnee distante."""
from pathlib import Path
import re,tempfile,json
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 s=pgserver.get_server(tempfile.mkdtemp(prefix='hg-successions95-'),cleanup_mode='delete');db=psycopg2.connect(s.get_uri());db.autocommit=True;c=db.cursor();n=0
 def ok(v,m):
  nonlocal n
  assert v,m;n+=1;print('OK',m)
 def refus(sql,args=None):
  try:c.execute(sql,args)
  except psycopg2.Error:return True
  return False
 def acteur(nom):c.execute("RESET ROLE;SELECT set_config('hg.acteur',%s,false);SET ROLE authenticated",(nom,))
 def fn(nom):
  src=(R/'baseline/domaines/personnage-et-presence/20_fonctions.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);c.execute(src[a:a+m.end()])
 try:
  c.execute("CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT nullif(current_setting('hg.acteur',true),'')$$;CREATE FUNCTION acteur_identifie() RETURNS boolean LANGUAGE sql AS $$SELECT mon_personnage() IS NOT NULL$$;CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,id uuid DEFAULT gen_random_uuid());GRANT SELECT ON personnages_donnees TO authenticated;INSERT INTO personnages_donnees(name,country) VALUES('Defunt','republic'),('Heritier','republic'),('Tiers','republic'),('Remplacant','republic'),('Conjoint','republic')")
  src=(R/'baseline/domaines/personnage-et-presence/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public.successions \(.*?\n\);',src,re.S)[0]);c.execute('ALTER TABLE successions ADD PRIMARY KEY(id);ALTER TABLE successions ENABLE ROW LEVEL SECURITY;GRANT INSERT,SELECT,UPDATE ON successions TO authenticated;GRANT ALL ON successions TO service_role')
  pol=(R/'baseline/domaines/personnage-et-presence/60_rls-policies.sql').read_text()
  for x in re.findall(r'CREATE POLICY[^;]* ON public\.successions[^;]*;',pol,re.S):c.execute(x)
  fn('succession_regler')
  d={'id':'part','type':'argent','part_nette':0,'chaine':[{'beneficiaire':'Heritier','role':'principal','reponse':None,'expires_at':'2099-01-01'}],'remplacant_prevu':'Remplacant','resultat':None,'regle':False}
  def dossier(id='d',disp=None):
   c.execute("RESET ROLE;SELECT set_config('hg.acteur','Defunt',false)");c.execute("INSERT INTO successions(id,defunt,country,conjoint,dispositions) VALUES(%s,'Defunt','republic','Conjoint',%s)",(id,json.dumps([disp or d])))
  dossier();acteur('Tiers');c.execute("UPDATE successions SET conjoint='Tiers' WHERE id='d'");ok(c.rowcount==1,'ancienne faille reproduite avant correctif');c.execute("RESET ROLE;UPDATE successions SET conjoint='Conjoint' WHERE id='d'")
  c.execute("CREATE SCHEMA auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT '00000000-0000-4000-8000-000000000095'::uuid$$;ALTER TABLE personnages_donnees ADD user_id uuid DEFAULT '00000000-0000-4000-8000-000000000095';CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT current_user='postgres' AND current_setting('hg.serveur',true)='on'$$;CREATE TABLE comptes_bancaires(id text PRIMARY KEY,personnage text,solde numeric);CREATE TABLE terrains_etat(id text,country text,building_id text,data text);CREATE TABLE entreprises(id text,data jsonb)")
  sql=(R/'migrations/20261022184500_successions_decisions_autorisees.sql').read_text();c.execute(sql);c.execute(sql)
  c.execute((R/'migrations/20261022184501_successions_creation_verifiee.sql').read_text())
  acteur('Heritier');ok(refus("INSERT INTO successions(id,defunt,country,argent_brut_total) VALUES('montant-forge','Heritier','republic',999999)"),'un acteur ne cree pas de faux solde successoral meme pour lui-meme')
  ok(refus("INSERT INTO successions(id,defunt,country,dispositions) VALUES('decision-forgee','Heritier','republic','[{\"id\":\"x\",\"type\":\"argent\",\"part_nette\":0,\"resultat\":{\"beneficiaire\":\"Tiers\"}}]')"),'resultat initial fabrique refuse')
  c.execute("RESET ROLE;INSERT INTO comptes_bancaires VALUES('compte-fixture','Heritier',100)");acteur('Heritier')
  c.execute("INSERT INTO successions(id,defunt,country,argent_brut_total,droits_total,part_etat,part_notaire,argent_net_total,dispositions) VALUES('vrai-dossier','Heritier','republic',100,33,29,4,67,'[{\"id\":\"argent-1\",\"type\":\"argent\",\"part_nette\":67,\"chaine\":[]}]')")
  ok(c.rowcount==1,'vraie photographie bancaire et fiscalite historique acceptees')
  acteur('Tiers');ok(refus("UPDATE successions SET conjoint='Tiers' WHERE id='d'"),'UPDATE direct tiers refuse');ok(refus("DELETE FROM successions WHERE id='d'"),'DELETE direct refuse');ok(refus("SELECT succession_regler('d')"),'reglement privilegie inaccessible au client')
  ok(refus("SELECT succession_repondre('d','part','accepte')"),'tiers ne repond pas a la place du legataire');ok(refus("INSERT INTO successions(id,defunt,country) VALUES('forge','Defunt','republic')"),'creation au nom du defunt tiers refusee');ok(refus("SELECT succession_repondre('d','part','autre')"),'reponse non autorisee refusee')
  acteur('Heritier');c.execute("SELECT succession_repondre('d','part','accepte')");ok(c.fetchone()[0]['ok'],'heritier accepte');c.execute("SELECT succession_repondre('d','part','accepte')");ok(c.fetchone()[0]['deja_repondu'],'rejeu apres reponse perdue sans nouvelle decision');c.execute("SELECT succession_repondre('d','part','renonce')");ok(not c.fetchone()[0]['ok'],'decision opposee refusee');ok(refus("UPDATE successions SET dispositions='[]' WHERE id='d'"),'meme heritier ne remplace pas le dossier')
  dossier('r');acteur('Heritier');c.execute("SELECT succession_repondre('r','part','renonce')");ok(c.fetchone()[0]['nouveauConvoque']=='Remplacant','cascade immediate vers remplacant');acteur('Remplacant');c.execute("SELECT succession_repondre('r','part','renonce')");ok(c.fetchone()[0]['nouveauConvoque']=='Conjoint','cascade immediate vers conjoint');acteur('Conjoint');c.execute("SELECT succession_repondre('r','part','renonce')");ok(c.fetchone()[0]['ok'],'dernier refus');c.execute("SELECT dispositions->0->'resultat' FROM successions WHERE id='r'");ok(c.fetchone()[0]['statut']=='devolution_etat','sans heritier : devolution existante conservee')
  expire=json.loads(json.dumps(d));expire['chaine'][0]['expires_at']='2000-01-01';dossier('expire',expire);acteur('Heritier');c.execute("SELECT succession_repondre('expire','part','accepte')");ok(c.fetchone()[0]['raison']=='convocation_expiree','delai controle par serveur')
  dossier('concurrent')
  def repondre(rep):
   with psycopg2.connect(s.get_uri()) as cx:
    q=cx.cursor();q.execute("SELECT set_config('hg.acteur','Heritier',true);SET LOCAL ROLE authenticated");
    try:
     q.execute("SELECT succession_repondre('concurrent','part',%s)",(rep,));return q.fetchone()[0]
    except psycopg2.errors.InsufficientPrivilege:
     cx.rollback();return {'ok':False}
  with ThreadPoolExecutor(max_workers=2) as ex:a,b=list(ex.map(repondre,['accepte','renonce']))
  ok(sum(x.get('ok',False) and not x.get('deja_repondu',False) for x in [a,b])==1,'une seule decision concurrente')
  c.execute('RESET ROLE');c.execute("SELECT has_function_privilege('service_role','succession_regler(text)','EXECUTE')");ok(c.fetchone()[0],'cron conserve le droit de reglement')
  print(f'{n}/{n} assertions locales ; identites fictives, aucun appel Supabase.')
 finally:db.close();s.cleanup()
if __name__=='__main__':main()
