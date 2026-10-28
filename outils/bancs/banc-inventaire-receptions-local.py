#!/usr/bin/env python3
"""Vrais corps SQL sur PostgreSQL jetable, transaction annulee ; aucun compte reel.
Les appels sont faits comme authenticated avec request.path, jamais comme postgres.
Identite JWT, schema minimal et lois (sans loi/avec loi) sont des fixtures explicites.
"""
from pathlib import Path
import importlib.util,json,re,tempfile
R=Path(__file__).resolve().parents[2]
MIGS=['20261027210800_inventaire_depot_piles_historiques.sql','20261027210810_inventaire_sels_objets_trouves.sql']
def fonction(path,name):
 s=(R/path).read_text(); a=re.search(r'CREATE OR REPLACE FUNCTION public\.'+name+r'\(',s).start()
 m=re.search(r'AS\s+(\$\w*\$).*?\1;',s[a:],re.S)
 return s[a:a+m.end()]
def initialiser(q):
 spec=importlib.util.spec_from_file_location('ced',R/'outils/bancs/banc-ced-football-local.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
 q.execute(mod.setup_sql())
 q.execute('CREATE VIEW personnages AS SELECT * FROM personnages_donnees; ALTER TABLE personnages_donnees ADD COLUMN dernier_objet_trouve_jour integer;')
 for fn in ['est_appel_serveur','est_mon_personnage','exiger_acteur','mon_personnage']:
  q.execute(fonction('baseline/domaines/socle/20_fonctions.sql',fn))
 q.execute(fonction('baseline/domaines/banque/20_fonctions.sql','helvetia_debiter_fonds_ordinaires'))
 q.execute(fonction('migrations/20261027180000_inventaire_achats_serveur.sql','inventaire_deposer_interne'))
 q.execute('''CREATE TABLE objets_modeles(id text PRIMARY KEY,objet jsonb NOT NULL); ALTER TABLE objets_modeles ENABLE ROW LEVEL SECURITY;
  CREATE TABLE caisses_batiments(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
  CREATE TABLE souvenirs_accueil(id text PRIMARY KEY,pj_nom text,objet_nom text,jour_creation integer,jour_expiration integer,revele boolean);
  CREATE TABLE fixture_lois(interdit boolean); INSERT INTO fixture_lois VALUES(false);
  CREATE FUNCTION assemblee_verifier_vente(jsonb,text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT jsonb_build_object('ok',NOT interdit,'raison','vente_interdite') FROM fixture_lois $$;
  GRANT USAGE ON SCHEMA public,auth TO authenticated;
  INSERT INTO caisses_batiments VALUES('republic_usine-pharmaceutique-luthecia','{"solde":0}',now());
  INSERT INTO ordres_couts VALUES('acheter_sels_ammoniaque',0,0),('objet_trouve',1,0);
  UPDATE personnages_donnees SET current_building='usine-pharmaceutique-luthecia',current_room='salle_ventes';
  INSERT INTO rp_epoques VALUES('republic','2026-09-13');''')
 q.execute(fonction('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_institution_mouvement'))
 for _ in range(2):
  for m in MIGS:q.execute((R/'migrations'/m).read_text())
def main(extra=None):
 import pgserver,psycopg2
 from psycopg2.extras import Json
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-inventaire-'),cleanup_mode='delete')
 try:
  c=psycopg2.connect(srv.get_uri());q=c.cursor()
  initialiser(q)
  n=0
  def check(value,msg):
   nonlocal n
   assert value,msg;n+=1;print('OK',n,msg,flush=True)
  def own(sql,params=()):
   q.execute('RESET ROLE');q.execute(sql,params) if params else q.execute(sql)
   return q.fetchone()[0] if q.description else None
  def call(fn,args):
   q.execute("SELECT set_config('role','authenticated',true),set_config('request.path',%s,true)",('/rpc/'+fn,))
   q.execute('SELECT public.'+fn+'('+','.join(['%s']*len(args))+')',args);return q.fetchone()[0]
  def snapshot():return own("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(d)) FROM personnages_donnees d),(SELECT jsonb_agg(to_jsonb(c)) FROM comptes_bancaires c),(SELECT jsonb_agg(to_jsonb(b)) FROM caisses_batiments b),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r),(SELECT jsonb_agg(to_jsonb(s)) FROM souvenirs_accueil s))")
  def uid(k):return f'00000000-0000-4000-9000-{k:012d}'
  before=snapshot();v=call('sels_ammoniaque_acheter',[uid(1),2,0]);check(v['ok'] and v['qte']==2 and v['total']==60,'depot et debit exacts de deux sels');check(v['revision']==1,'revision serveur avancee')
  check(own("SELECT (data->>'solde')::integer FROM caisses_batiments")==60,'recette dans la seule caisse pharma')
  after=snapshot();v=call('sels_ammoniaque_acheter',[uid(1),2,0]);check(v['rejeu'] and snapshot()==after,'reponse perdue : aucun second debit ni depot')
  check(call('sels_ammoniaque_acheter',[uid(1),3,0]).get('raison')=='requete_reutilisee','nonce lie aux parametres')
  for quantity in [0,21,None]:
   before=snapshot();check(not call('sels_ammoniaque_acheter',[uid(2),quantity,0])['ok'] and snapshot()==before,'quantite invalide sans mutation')
  for col,val in [('current_room','bureau'),('current_building','assemblee'),('country','soviet')]:
   old=own('SELECT '+col+" FROM personnages_donnees WHERE name='Fixture'");own('UPDATE personnages_donnees SET '+col+'=%s WHERE name=\'Fixture\'',(val,));before=snapshot()
   check(call('sels_ammoniaque_acheter',[uid(2),1,0]).get('raison')=='pas_sur_place' and snapshot()==before,'lieu reel requis : '+col);own('UPDATE personnages_donnees SET '+col+'=%s WHERE name=\'Fixture\'',(old,))
  own('UPDATE fixture_lois SET interdit=true');before=snapshot();check(not call('sels_ammoniaque_acheter',[uid(2),1,0])['ok'] and snapshot()==before,'loi controlee dans la transaction');own('UPDATE fixture_lois SET interdit=false')
  before=snapshot();check(call('sels_ammoniaque_acheter',[uid(2),1,9]).get('raison')=='cout_non_declare','faux cout refuse');check(own("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==30,'aucune perte de PA sur refus')
  before=snapshot();check(call('sels_ammoniaque_acheter',[uid(2),20,0]).get('raison')=='fonds_insuffisants' and snapshot()==before,'fonds insuffisants avant toute contrepartie')
  # 28/10 (Claude) : la caisse de l'usine n'existe pas encore en production ; elle est creee au
  # premier achat, comme le faisait l'ecran. Essai annule ensuite pour garder la suite inchangee.
  own('DELETE FROM caisses_batiments');q.execute('SAVEPOINT caisse_absente')
  check(call('sels_ammoniaque_acheter',[uid(2),1,0])['ok'] and own("SELECT (data->>'solde')::integer FROM caisses_batiments WHERE id='republic_usine-pharmaceutique-luthecia'")==30,'caisse absente creee avec la recette')
  q.execute('ROLLBACK TO SAVEPOINT caisse_absente')
  own("INSERT INTO caisses_batiments VALUES('republic_usine-pharmaceutique-luthecia','{\"solde\":60}',now())")
  stacks=[{'name':'sels ancien','stackKey':'sels_ammoniaque','stackable':True,'qty':3,'id':'a','memoire':'conservee'},{'name':'autre pile','stackKey':'sels_ammoniaque','stackable':True,'qty':2,'id':'b'}]
  own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json(stacks),));v=call('sels_ammoniaque_acheter',[uid(2),1,0]);check(sum(i['qty'] for i in v['inventory'])==6 and v['inventory'][1]==stacks[1],'piles historiques : une seule unite ajoutee, metadonnees intactes')
  own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json([{'stackable':True,'stackKey':'bois','qty':99}]),));v=call('sels_ammoniaque_acheter',[uid(3),2,0]);check(v['qte']==1 and v['total']==30,'plafond : seule la quantite reellement deposee est facturee')
  before=snapshot();check(call('sels_ammoniaque_acheter',[uid(4),1,0]).get('raison')=='inventaire_plein' and snapshot()==before,'inventaire plein : aucun cout')
  own("UPDATE personnages_donnees SET inventory='[]',current_building='mairie-capitale',current_room='hall_mairie' WHERE name='Fixture'")
  v=call('objet_trouve_reclamer',[uid(5),1,0]);check(v['ok'] and isinstance(v['trouve'],bool) and 'revision' in v,'tirage objets trouves par le serveur')
  after=snapshot();check(call('objet_trouve_reclamer',[uid(5),1,0])['rejeu'] and snapshot()==after,'rejeu objet trouve sans nouveau jet ni PA')
  check(call('objet_trouve_reclamer',[uid(6),1,0]).get('raison')=='deja_fait_aujourdhui','limite quotidienne serveur meme si aucun objet')
  # Forcer uniquement le RNG PostgreSQL pour couvrir les deux branches sans changer le moteur.
  own("SELECT setseed(0.1234)");outcomes=set()
  for k in range(20):
   own("DELETE FROM objets_trouves_jours");own("UPDATE personnages_donnees SET dernier_objet_trouve_jour=NULL,inventory='[]',pa=30 WHERE name='Fixture'")
   v=call('objet_trouve_reclamer',[uid(20+k),1,0]);outcomes.add(v['trouve'])
   if v['trouve']:
    check(v['inventory'][0]['origine']=='objets_trouves' and v['inventory'][0]['id'].startswith('obj-'),'modele serveur et identifiant unique')
   if len(outcomes)==2:break
  check(len(outcomes)==2,'succes et rien trouve executes')
  own("UPDATE personnages_donnees SET current_room=NULL,dernier_objet_trouve_jour=NULL WHERE name='Fixture'");own('DELETE FROM objets_trouves_jours');before=snapshot()
  check(call('objet_trouve_reclamer',[uid(50),1,0]).get('raison')=='pas_sur_place' and snapshot()==before,'lieu absent refuse sans mutation')
  for fn in ['inventaire_deposer_interne(text,jsonb,boolean)','inventaire_action_rejouer_interne(text,uuid,text,jsonb)']:
   check(not own("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",(fn,)),'primitive interne inaccessible : '+fn)
  # Meme si les DEFAULT PRIVILEGES distants accordent INSERT, RLS doit refuser l'acte.
  own('GRANT SELECT,INSERT ON inventaire_actions_recus TO authenticated')
  q.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/inventaire_actions_recus',true)")
  q.execute('SELECT count(*) FROM inventaire_actions_recus');check(q.fetchone()[0]==0,'registre invisible au navigateur meme avec privilege SELECT')
  q.execute('SAVEPOINT rls')
  try:q.execute("INSERT INTO inventaire_actions_recus VALUES('Fixture',gen_random_uuid(),'forge','{}','{}',now())");raise AssertionError('RLS contournee')
  except psycopg2.Error as erreur:
   assert erreur.pgcode=='42501';q.execute('ROLLBACK TO SAVEPOINT rls')
  check(True,'registre non forgeable avec privilege INSERT mais sans politique RLS')
  own('SAVEPOINT politique_inconnue');own('CREATE POLICY fixture_mauvaise ON inventaire_actions_recus FOR ALL TO authenticated USING(true) WITH CHECK(true)')
  try:own((R/'migrations'/MIGS[1]).read_text());raise AssertionError('politique ignoree')
  except psycopg2.Error as erreur:
   assert 'politique preexistante' in str(erreur);q.execute('ROLLBACK TO SAVEPOINT politique_inconnue')
  check(True,'migration refuse un registre preexistant expose plutot que reutiliser ses politiques')
  # Un depot automatique ne doit jamais effacer un ancien inventaire de format inconnu.
  own("CREATE FUNCTION fixture_depot_objet(p_q numeric) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT public.inventaire_deposer_interne('Fixture',jsonb_build_object('name','Fixture','stackable',true,'stackKey','fixture','qty',p_q),true) $$")
  before=snapshot();check(call('fixture_depot_objet',[1.5]).get('raison')=='quantite_invalide' and snapshot()==before,'depot commun refuse la fraction sans arrondi')
  own("UPDATE personnages_donnees SET inventory='{\"ancien\":\"a examiner\"}' WHERE name='Fixture'");before=snapshot()
  check(call('fixture_depot_objet',[1]).get('raison')=='inventaire_format_a_examiner' and snapshot()==before,'depot automatique ne remplace pas un inventaire historique illisible')
  own("UPDATE personnages_donnees SET inventory='[]' WHERE name='Fixture'")
  if extra:extra(q,own,call,check,uid,snapshot,Json)
  c.rollback();q.execute("SELECT to_regclass('public.inventaire_actions_recus')");check(q.fetchone()[0] is None,'transaction de banc entierement annulee')
  print(json.dumps({'assertions':n,'production':False,'role_appels':'authenticated','schema_et_jwt':'fixtures','rollback':True}))
 finally:srv.cleanup()
if __name__=='__main__':main()
