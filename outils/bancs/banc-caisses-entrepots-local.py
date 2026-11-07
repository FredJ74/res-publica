#!/usr/bin/env python3
"""Corps réels + patch sur PostgreSQL jetable ; transaction annulée, appels authenticated.
Décor minimal explicite : identité, paiement PA et lois simulés ; aucune donnée réelle.
Primitives de caisse, lecture, achat et reçus chargés depuis le baseline, non réécrits.
"""
from pathlib import Path
import re,tempfile,json
R=Path(__file__).resolve().parents[2]
M=R/'migrations/20261107001000_achat_entrepot_caisse_canonique.sql'
M_EFFORT=R/'migrations/20261107081631_effort_ravitaillement_caisse_canonique.sql'
def fonction(path,name,indice=0):
 s=(R/path).read_text();matches=list(re.finditer(r'CREATE OR REPLACE FUNCTION public\.'+name+r'\(',s));a=matches[indice].start()
 m=re.search(r'AS\s+(\$\w*\$).*?\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 import pgserver,psycopg2
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-caisse-entrepots-'),cleanup_mode='delete')
 c=None;n=0
 try:
  c=psycopg2.connect(srv.get_uri());q=c.cursor();q.execute('SHOW server_version');print('PostgreSQL',q.fetchone()[0])
  q.execute('''CREATE ROLE authenticated; CREATE ROLE anon; CREATE ROLE service_role;
   CREATE TABLE personnages_donnees(name text PRIMARY KEY,inventory jsonb DEFAULT '[]',inventory_revision bigint DEFAULT 0,liquide numeric,arg numeric,pa integer,country text);
   CREATE TABLE comptes_bancaires(id text,personnage text,banque text,solde numeric,updated_at timestamptz);
   CREATE TABLE batiments_etat(id text PRIMARY KEY,country text,city text,building_id text,data jsonb,updated_at timestamptz);
   CREATE TABLE villes(pays text,ville text);
   CREATE TABLE caisses_batiments(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
   CREATE TABLE budgets_nationaux(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
   CREATE TABLE ressources_economie(cle text,prix_base numeric);
   CREATE TABLE caisses_mouvements_clients(acteur text,caisse text,delta numeric,motif text,accepte boolean,raison text);
   CREATE TABLE inventaire_actions_recus(acteur text,requete uuid,action text,parametres jsonb,resultat jsonb,cree_le timestamptz,PRIMARY KEY(acteur,requete));
   CREATE FUNCTION exiger_acteur(n text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
    IF n IS DISTINCT FROM current_setting('fixture.acteur',true) THEN RAISE EXCEPTION 'pas_votre_personnage';END IF; END $$;
   CREATE FUNCTION matiere_refus_circuit_legal_lot(text,jsonb,text) RETURNS jsonb LANGUAGE sql AS $$ SELECT NULL::jsonb $$;
   CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
   CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT current_setting('fixture.acteur',true) $$;
   CREATE FUNCTION caisse_refus_autorite(text,text) RETURNS text LANGUAGE sql AS $$ SELECT 'refus_fixture'::text $$;
   CREATE FUNCTION payer_ordre(n text,text,integer,integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN
    UPDATE personnages_donnees SET pa=pa-1 WHERE name=n; RETURN '{"ok":true}'::jsonb;END $$;
   INSERT INTO personnages_donnees(name,liquide,arg,pa,country) VALUES('Fixture',100,100,20,'republic');
   INSERT INTO villes VALUES('republic','ville_a'),('soviet','ville_a');
   INSERT INTO ressources_economie VALUES('bois',5);
   INSERT INTO batiments_etat VALUES('republic_ville_a_entrepot-logistique-psm','republic','ville_a','entrepot-logistique-psm','{"entrepot":{"stock":{"bois":50},"caisse":10231}}',now()),
    ('soviet_ville_a_entrepot-logistique-starovka','soviet','ville_a','entrepot-logistique-starovka','{"entrepot":{"stock":{"bois":50}}}',now());
   INSERT INTO caisses_batiments VALUES('republic_entrepot_ville_a','{"solde":2}',now()),('soviet_entrepot_ville_a','{"solde":8}',now());
   GRANT USAGE ON SCHEMA public TO authenticated;
  ''')
  for path,fn,idx in [
   ('baseline/domaines/immobilier-et-territoire/20_fonctions-1.sql','batiment_etat_lire',0),
   *[('baseline/domaines/socle/20_fonctions.sql',f,0) for f in ['inventaire_place_restante','inventaire_action_rejouer_interne','achat_requete_ouvrir_interne','achat_requete_clore_interne']],
   ('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_institution_mouvement',0),
   *[('baseline/domaines/economie/20_fonctions-2.sql',f,0) for f in ['entrepot_caisse_id','entrepot_caisse_lire']],
   ('baseline/domaines/economie/20_fonctions-1.sql','acheter_a_entrepot',0),
   ('baseline/domaines/economie/20_fonctions-1.sql','acheter_a_entrepot',1)]:q.execute(fonction(path,fn,idx))
  def check(x,label):
   nonlocal n
   assert x,label;n+=1;print('OK',label)
  def snap():
   q.execute("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(x)) FROM personnages_donnees x),(SELECT jsonb_agg(to_jsonb(x)) FROM caisses_batiments x),(SELECT jsonb_agg(to_jsonb(x)) FROM batiments_etat x),(SELECT count(*) FROM inventaire_actions_recus),(SELECT jsonb_agg(to_jsonb(x)) FROM comptes_bancaires x),(SELECT jsonb_agg(to_jsonb(x)) FROM budgets_nationaux x))");return q.fetchone()[0]
  def call(k=1,acteur='Fixture',pays='republic',bat='entrepot-logistique-psm',qte=2):
   q.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/rpc/acheter_a_entrepot',true),set_config('fixture.acteur','Fixture',true)")
   try:
    q.execute('SELECT acheter_a_entrepot(%s::uuid,%s,%s,%s,%s,%s::jsonb,1,0)',(f'00000000-0000-4000-8000-{k:012d}',acteur,pays,'ville_a',bat,json.dumps({'bois':qte})));return q.fetchone()[0]
   finally:
    if c.get_transaction_status()!=psycopg2.extensions.TRANSACTION_STATUS_INERROR:q.execute('RESET ROLE')
  q.execute('SAVEPOINT avant_bug');call();q.execute("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_entrepot_ville_a'");check(q.fetchone()[0]=='2','contre-épreuve ancien achat : caisse canonique non créditée');q.execute('ROLLBACK TO avant_bug')
  q.execute("SELECT md5(pg_get_functiondef('acheter_a_entrepot(text,text,text,text,jsonb)'::regprocedure))");original=q.fetchone()[0]
  q.execute('SAVEPOINT avant_patch');q.execute(M.read_text())
  before=snap();r=call();check(r['ok'] and r['caisse_entrepot']==12,'recette canonique +10 et bon retour');q.execute("SELECT batiment_etat_lire(data)->'entrepot'->>'caisse' FROM batiments_etat WHERE country='republic'");check(q.fetchone()[0] is None,'patch Claude : champ inactif retiré, aucun crédit de son montant')
  after=snap();check(call()['rejeu'] and snap()==after,'réponse perdue : même reçu, aucun nouveau débit/crédit')
  check(call(qte=3)['raison']=='requete_reutilisee' and snap()==after,'clé réutilisée avec panier différent refusée')
  r=call(2,pays='soviet',bat='entrepot-logistique-starovka');check(r['ok'] and r['caisse_entrepot']==18,'caisse Sovarka distincte')
  q.execute("DELETE FROM caisses_batiments WHERE id='republic_entrepot_ville_a'");before=snap();q.execute('SAVEPOINT caisse_absente')
  try:call(3);raise AssertionError('caisse absente acceptée')
  except psycopg2.Error as e:check('caisse_entrepot_refusee' in str(e),'patch Claude refuse caisse absente');q.execute('ROLLBACK TO caisse_absente');q.execute('RESET ROLE')
  check(snap()==before,'caisse absente annule PJ, stock, PA et reçu')
  q.execute("INSERT INTO caisses_batiments VALUES('republic_entrepot_ville_a','{\"solde\":0}',now())")
  before=snap();r=call(4,qte=999);check(r['raison']=='stock_insuffisant' and snap()==before,'stock insuffisant : aucun débit')
  q.execute("UPDATE personnages_donnees SET liquide=0,arg=0");before=snap();r=call(5);check(r['raison']=='fonds_insuffisants' and snap()==before,'fonds insuffisants : aucun crédit')
  q.execute('SAVEPOINT identite')
  try:call(6,acteur='Autre');raise AssertionError('usurpation acceptée')
  except psycopg2.Error as e:check('pas_votre_personnage' in str(e),'identité refusée sous authenticated');q.execute('ROLLBACK TO identite');q.execute('RESET ROLE')
  q.execute("UPDATE personnages_donnees SET liquide=100,arg=100,inventory='[{\"qty\":100}]'");before=snap();r=call(7);check(r['raison']=='inventaire_plein' and snap()==before,'inventaire plein : aucun débit PA ni caisse')
  q.execute("UPDATE personnages_donnees SET inventory='[]'")
  q.execute("CREATE FUNCTION fixture_panne() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'panne_stock_fixture';END $$; CREATE TRIGGER fixture_panne BEFORE UPDATE ON batiments_etat FOR EACH ROW EXECUTE FUNCTION fixture_panne();")
  before=snap();q.execute('SAVEPOINT panne')
  try:call(8);raise AssertionError('panne attendue')
  except psycopg2.Error as e:check('panne_stock_fixture' in str(e),'panne après crédit canonique propagée');q.execute('ROLLBACK TO panne');q.execute('RESET ROLE')
  check(snap()==before,'panne tardive annule caisse, PA, argent, inventaire et reçu')
  q.execute('ROLLBACK TO avant_patch');q.execute("SELECT md5(pg_get_functiondef('acheter_a_entrepot(text,text,text,text,jsonb)'::regprocedure))");check(q.fetchone()[0]==original,'rollback du DDL restaure le corps initial')
  # Empêcher un patch contre un corps dont les fragments attendus ont changé.
  q.execute(fonction('baseline/domaines/economie/20_fonctions-1.sql','acheter_a_entrepot').replace('v_idx int; v_ligne jsonb; v_existe boolean;','v_idx integer; v_ligne jsonb; v_existe boolean;'))
  q.execute('SAVEPOINT incompatible')
  try:q.execute(M.read_text());raise AssertionError('corps incompatible accepté')
  except psycopg2.Error as e:check('patch refuse' in str(e),'corps incompatible refusé');q.execute('ROLLBACK TO incompatible')
  # Le ravitaillement est réservé au serveur ; un client authentifié doit être refusé.
  for f in ['eg_etat_id','eg_etat_lire']:q.execute(fonction('baseline/domaines/socle/20_fonctions.sql',f))
  q.execute(fonction('baseline/domaines/militaire/20_fonctions-1.sql','effort_ravitailler'))
  q.execute("REVOKE ALL ON FUNCTION effort_ravitailler(text,jsonb,jsonb,jsonb) FROM PUBLIC; GRANT EXECUTE ON FUNCTION effort_ravitailler(text,jsonb,jsonb,jsonb) TO service_role; INSERT INTO budgets_nationaux VALUES('republic','{}',now()); INSERT INTO caisses_batiments VALUES('republic_caserne-militaire','{\"solde\":100}',now());")
  def ravitailler(qte=2,role='service_role',ent=None):
   q.execute("SELECT set_config('role',%s,true),set_config('request.path','/rpc/effort_ravitailler',true)",(role,))
   try:
    q.execute('SELECT effort_ravitailler(%s,%s::jsonb,%s::jsonb,%s::jsonb)',('republic',json.dumps(ent or [{'city':'ville_a','building':'entrepot-logistique-psm'}]),json.dumps({'bois':qte}),json.dumps({'bois':5})));return q.fetchone()[0]
   finally:
    if c.get_transaction_status()!=psycopg2.extensions.TRANSACTION_STATUS_INERROR:q.execute('RESET ROLE')
  q.execute('SAVEPOINT effort_avant');ravitailler();q.execute("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_entrepot_ville_a'");check(q.fetchone()[0]=='2','contre-épreuve ravitaillement ancien : recette absente');q.execute('ROLLBACK TO effort_avant')
  q.execute(M_EFFORT.read_text());q.execute("SELECT md5(pg_get_functiondef('effort_ravitailler(text,jsonb,jsonb,jsonb)'::regprocedure))");h=q.fetchone()[0];q.execute(M_EFFORT.read_text());q.execute("SELECT md5(pg_get_functiondef('effort_ravitailler(text,jsonb,jsonb,jsonb)'::regprocedure))");check(q.fetchone()[0]==h,'rejeu du patch militaire strictement identique')
  q.execute('SAVEPOINT acces_effort')
  try:ravitailler(role='authenticated');raise AssertionError('client militaire accepté')
  except psycopg2.Error as e:check(e.pgcode=='42501','authenticated interdit sur commande nocturne');q.execute('ROLLBACK TO acces_effort');q.execute('RESET ROLE')
  r=ravitailler();check(r['ok'] and r['total']==10,'ravitaillement existant conservé')
  q.execute("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_entrepot_ville_a'");check(q.fetchone()[0]=='12','recette militaire canonique +10')
  q.execute("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_caserne-militaire'");check(q.fetchone()[0]=='90','contrepartie caserne moins 10')
  q.execute("SELECT data->'caserneMatieres'->>'bois' FROM budgets_nationaux WHERE id='republic'");check(q.fetchone()[0]=='2','stock caserne livré')
  q.execute("SELECT batiment_etat_lire(data)->'entrepot'->>'caisse' FROM batiments_etat WHERE country='republic'");check(q.fetchone()[0]=='10231','ancien champ militaire gelé, pas de régularisation')
  # Premier entrepôt payé puis second sans caisse : tout doit disparaître.
  q.execute("INSERT INTO villes VALUES('republic','ville_b'); INSERT INTO batiments_etat VALUES('republic_ville_b_entrepot-logistique-montrouge','republic','ville_b','entrepot-logistique-montrouge','{\"entrepot\":{\"stock\":{\"bois\":50}}}',now())")
  q.execute("UPDATE caisses_batiments SET data='{\"solde\":1000}' WHERE id='republic_caserne-militaire'");before=snap();q.execute('SAVEPOINT effort_panne')
  try:ravitailler(qte=80,ent=[{'city':'ville_a','building':'entrepot-logistique-psm'},{'city':'ville_b','building':'entrepot-logistique-montrouge'}]);raise AssertionError('caisse absente acceptée')
  except psycopg2.Error as e:check('effort_caisse_credit_refuse' in str(e),'refus de recette militaire propagé');q.execute('ROLLBACK TO effort_panne');q.execute('RESET ROLE')
  check(snap()==before,'rollback de tous les entrepôts, caserne et stocks militaires')
  q.execute('SAVEPOINT effort_altere')
  q.execute(fonction('baseline/domaines/militaire/20_fonctions-1.sql','effort_ravitailler').replace("v_data jsonb; v_commun jsonb;","v_data jsonb; v_commun jsonb := '{}';"))
  q.execute('SAVEPOINT effort_refus')
  try:q.execute(M_EFFORT.read_text());raise AssertionError('corps militaire modifié accepté')
  except psycopg2.Error as e:check('declaration_incompatible' in str(e),'corps militaire différent refusé');q.execute('ROLLBACK TO effort_altere')
  c.rollback();q.execute("SELECT to_regclass('public.caisses_batiments')");check(q.fetchone()[0] is None,'transaction complète annulée, aucune fixture persistée')
  print(f'{n} contrôles PostgreSQL réussis ; identité/lois/paiement PA = fixtures explicites.')
 finally:
  if c:c.close()
  srv.cleanup()
if __name__=='__main__':main()
