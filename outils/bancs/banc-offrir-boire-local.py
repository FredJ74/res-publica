#!/usr/bin/env python3
"""PostgreSQL jetable : vrais moteurs SQL, services fiscaux/bancaires de fixture.
Aucune URL distante, aucun personnage reel. --local-jetable obligatoire.
"""
import argparse, tempfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[2]
SCHEMA="""
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE TABLE entreprises(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,current_building text,current_room text,arg numeric,liquide numeric,pa integer,hp integer,moral integer,resources jsonb,stats jsonb,day integer,updated_at timestamptz);
CREATE TABLE recettes_commerce(id text PRIMARY KEY,categorie text,label text,effets jsonb,icone text,image text,description text,famille_produit_marche text,bonus_integration_ville integer);
CREATE TABLE entreprises_constantes(cle text PRIMARY KEY,valeur numeric);
CREATE TABLE reglages(refus boolean,erreur boolean); INSERT INTO reglages VALUES(false,false);
CREATE TABLE taxes(montant numeric);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('test.acteur',true),'') $$;
CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF $1 IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'acteur_invalide'; END IF; END $$;
CREATE FUNCTION helvetia_debiter_fonds_ordinaires(text,numeric) RETURNS boolean LANGUAGE plpgsql AS $$
 BEGIN
 IF (SELECT refus FROM reglages) THEN RETURN false; END IF;
 UPDATE personnages_donnees SET arg=arg-$2,liquide=liquide-$2 WHERE name=$1 AND liquide >= $2;
 IF NOT FOUND THEN RETURN false; END IF;
 IF (SELECT erreur FROM reglages) THEN RAISE EXCEPTION 'erreur_banc_test'; END IF;
 RETURN true; END $$;
CREATE FUNCTION appliquer_taxe_transaction(text,text,numeric) RETURNS jsonb LANGUAGE plpgsql AS $$ BEGIN INSERT INTO taxes VALUES ($3*0.1); RETURN jsonb_build_object('net',$3*0.9); END $$;
CREATE FUNCTION entreprise_ajouter_historique(jsonb,numeric,text,integer) RETURNS jsonb LANGUAGE sql AS $$ SELECT $1 $$;
CREATE FUNCTION caisse_institution_mouvement(text,numeric,boolean) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true}'::jsonb $$;
CREATE FUNCTION payer_ordre(text,text,integer,integer) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true}'::jsonb $$;
INSERT INTO entreprises_constantes VALUES('pa_tournee',1);
INSERT INTO recettes_commerce VALUES('biere','boisson','Biere','{}',NULL,NULL,NULL,NULL,NULL);
"""
def extraire(nom,fichier):
 s=(ROOT/fichier).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');b=s.index('$function$;',a)+len('$function$;');return s[a:b]
def main():
 p=argparse.ArgumentParser();p.add_argument('--local-jetable',action='store_true',required=True);p.parse_args()
 import pgserver,psycopg2
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-boire-'),cleanup_mode='delete');uri=server.get_uri()
 db=psycopg2.connect(uri);db.autocommit=True;c=db.cursor();c.execute(SCHEMA)
 for nom,f in [('tournees','baseline/domaines/personnage-et-presence/10_tables.sql'),('invitations_diner','baseline/domaines/personnage-et-presence/10_tables.sql')]:
  s=(ROOT/f).read_text();a=s.index('CREATE TABLE public.'+nom+' (');b=s.index('\n);',a)+3;c.execute(s[a:b]);c.execute('ALTER TABLE '+nom+' ADD PRIMARY KEY(id)')
 for nom,f in [('commerce_vendre_produit','baseline/domaines/economie/20_fonctions-1.sql'),('commerce_produire','baseline/domaines/economie/20_fonctions-1.sql'),('fonds_reference_produire_lots','baseline/domaines/finances-publiques/20_fonctions-1.sql'),('tournee_cloturer','baseline/domaines/personnage-et-presence/20_fonctions.sql')]:c.execute(extraire(nom,f))
 # Le prevol exige le moteur electronique reel deja installe en production, non le baseline ancien.
 c.execute(extraire('fonds_reference_produire_lots','migrations/20261031113552_assemblage_composants_stocks_reels.sql'))
 migration=(ROOT/'migrations/20261031113607_catalogue_et_offrir_a_boire.sql').read_text()
 c.execute(migration)
 c.execute(migration)  # Meme migration rejouee : idempotence structurelle obligatoire.
 c.execute("SELECT set_config('test.acteur','Alice',false)")
 n=0
 def check(v,msg):
  nonlocal n;n+=1;assert v,msg
 def reset():
  c.execute("DELETE FROM invitations_diner; DELETE FROM tournees; DELETE FROM entreprises; DELETE FROM personnages_donnees; DELETE FROM taxes; UPDATE reglages SET refus=false,erreur=false")
  c.execute("INSERT INTO entreprises VALUES('bar','{\"type\":\"bar\",\"country\":\"republic\",\"city\":\"capitale\",\"buildingId\":\"hotel\",\"roomId\":\"bar\",\"carte\":[\"biere\"],\"proprietaire\":\"Alice\",\"caisse\":100,\"stockProduits\":{\"biere\":20},\"parametres\":{\"prixVente\":{\"biere\":77}}}',now())")
  for nom in ['Alice','Bob','Claire','Denis']:c.execute("INSERT INTO personnages_donnees VALUES(%s,'republic','capitale','hotel','bar',1000,1000,10,50,50,'{\"inf\":5}','{\"ENT\":5}',1,now())",(nom,))
 def rpc(sql,args=()):c.execute(sql,args);return c.fetchone()[0]
 def creer(id='tournee-test-000001',invites=None):return rpc('SELECT tournee_creer(%s,%s,%s,%s)',(id,'bar','biere',invites or ['Bob']))
 def repondre(nom,oui,id='tournee-test-000001'):
  rpc("SELECT set_config('test.acteur',%s,false)",(nom,));v=rpc('SELECT tournee_repondre((SELECT id FROM invitations_diner WHERE invite=%s AND tournee_id=%s),%s)',(nom,id,oui));rpc("SELECT set_config('test.acteur','Alice',false)");return v
 def clore(id='tournee-test-000001'):return rpc('SELECT tournee_cloturer(%s,true)',(id,))
 reset();check(creer()['ok'],'creation');check(creer().get('rejeu'),'creation rejeu');check(not creer(invites=['Claire'])['ok'],'cle incompatible');check(repondre('Bob',True)['ok'],'accepter');check(repondre('Bob',True).get('rejeu'),'double acceptation');check(not repondre('Bob',False)['ok'],'reponse opposee refusee')
 v=clore();check(v['total']==50 and v['verres']==2,'prix fixe');check(clore().get('rejeu'),'cloture rejouee');check(rpc("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==950,'debit unique');check(rpc("SELECT pa FROM personnages_donnees WHERE name='Alice'")==9,'un PA');check(rpc("SELECT count(*) FROM personnages_donnees WHERE name IN ('Alice','Bob') AND hp=55 AND resources->>'inf'='7' AND stats->>'ENT'='7'")==2,'bonus non cumules');check(rpc("SELECT data->'parametres'->'prixVente'->>'biere' FROM entreprises WHERE id='bar'")=='77','prix carte preserve');check(rpc('SELECT sum(montant) FROM taxes')==5,'taxation moteur unique')
 reset();creer(invites=['Bob','Claire','Denis']);repondre('Bob',True);repondre('Claire',False);repondre('Denis',True);v=clore();check(v['total']==75 and v['acceptants']==2,'mixte');check(rpc("SELECT hp FROM personnages_donnees WHERE name='Alice'")==55,'bonus organisateur une seule fois');check(rpc("SELECT hp FROM personnages_donnees WHERE name='Claire'")==50,'refus aucun gain')
 reset();creer();repondre('Bob',False);v=clore();check(v['seul'] and v['total']==25,'aucun acceptant');check(rpc("SELECT moral FROM personnages_donnees WHERE name='Alice'")==45,'malus seul');check(rpc("SELECT hp FROM personnages_donnees WHERE name='Alice'")==50,'aucun bonus seul')
 for condition in ['liquide=0,arg=0','pa=0']:
  reset();creer();repondre('Bob',True);c.execute('UPDATE personnages_donnees SET '+condition+" WHERE name='Alice'");v=clore();check(not v['ok'],'ressource insuffisante');check(rpc("SELECT data->'stockProduits'->>'biere' FROM entreprises WHERE id='bar'")=='20','stock intact');check(rpc('SELECT count(*) FROM taxes')==0,'pas taxe partielle');check(rpc("SELECT hp FROM personnages_donnees WHERE name='Bob'")==50,'pas gain partiel')
 reset();creer();repondre('Bob',True);c.execute('UPDATE reglages SET refus=true');v=clore();check(not v['ok'],'debit refuse');check(rpc("SELECT pa FROM personnages_donnees WHERE name='Alice'")==10,'PA rollback apres refus debit')
 reset();creer();repondre('Bob',True);c.execute('UPDATE reglages SET erreur=true')
 try:clore();raise AssertionError('panne non levee')
 except psycopg2.Error:pass
 check(rpc("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==1000,'panne rollback argent');check(rpc("SELECT pa FROM personnages_donnees WHERE name='Alice'")==10,'panne rollback PA');c.execute('UPDATE reglages SET erreur=false');check(clore()['ok'],'reprise apres panne')
 reset();creer();check(clore()['raison']=='reponses_en_attente','attente sans debit');c.execute("UPDATE tournees SET expires_at=now()-interval '1 second'");check(clore()['seul'],'expiration sert organisateur');check(not repondre('Bob',True)['ok'],'reponse tardive refusee')
 reset();c.execute("UPDATE personnages_donnees SET current_room='dehors' WHERE name='Bob'");check(not creer()['ok'],'absent refuse');c.execute("UPDATE personnages_donnees SET current_room='bar' WHERE name='Bob'");creer();repondre('Bob',True);c.execute("UPDATE personnages_donnees SET current_room='dehors' WHERE name='Alice'");check(clore()['raison']=='action_obsolete','organisateur parti')
 reset();creer();repondre('Bob',True)
 def concurrent(_):
  d=psycopg2.connect(uri);d.autocommit=True;cc=d.cursor();cc.execute("SELECT set_config('test.acteur','Alice',false)");cc.execute("SELECT tournee_cloturer('tournee-test-000001',true)");v=cc.fetchone()[0];d.close();return v
 with ThreadPoolExecutor(2) as pool:vs=list(pool.map(concurrent,range(2)))
 check(all(v['ok'] for v in vs) and sum(bool(v.get('rejeu')) for v in vs)==1,'concurrence idempotente');check(rpc("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==950,'concurrence un debit')
 reset();rpc("SELECT set_config('test.acteur','Bob',false)");check(rpc("SELECT commerce_produire('Bob','bar','biere',NULL)")['raison']=='production_non_autorisee','production client refusee');check(rpc("SELECT fonds_reference_produire_lots('prod-test-000001','Bob','bar','ref',1)")['raison']=='production_non_autorisee','lots client refuse')
 check(not rpc("SELECT has_function_privilege('authenticated','public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)','EXECUTE')"),'tarif prive');check(not rpc("SELECT has_function_privilege('authenticated','public.tournee_cloturer_boire(text)','EXECUTE')"),'cloture interne privee')
 # Les RPC sont SECURITY DEFINER ; les ecritures REST directes, meme proprietaire, sont interdites.
 rpc("SELECT set_config('test.acteur','Alice',false)");creer();c.execute('GRANT SELECT,UPDATE ON tournees TO authenticated');c.execute('SET ROLE authenticated')
 try:c.execute("UPDATE tournees SET contrat=NULL");raise AssertionError('contournement REST')
 except psycopg2.Error:pass
 c.execute('RESET ROLE');check(rpc("SELECT contrat FROM tournees LIMIT 1")=='boire_v1','contrat non falsifiable')
 # Deux actes distincts en concurrence : les fonds ne peuvent pas etre depenses deux fois.
 reset();creer();creer('tournee-test-000002');repondre('Bob',True);repondre('Bob',True,'tournee-test-000002');c.execute("UPDATE personnages_donnees SET liquide=50,arg=50 WHERE name='Alice'")
 def autre(id):
  d=psycopg2.connect(uri);d.autocommit=True;cc=d.cursor();cc.execute("SELECT set_config('test.acteur','Alice',false)");cc.execute('SELECT tournee_cloturer(%s,true)',(id,));v=cc.fetchone()[0];d.close();return v
 with ThreadPoolExecutor(2) as pool:vs=list(pool.map(autre,['tournee-test-000001','tournee-test-000002']))
 check(sum(v['ok'] for v in vs)==1,'deux actes fonds partages');check(rpc("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==0,'aucun decouvert concurrent');check(rpc("SELECT pa FROM personnages_donnees WHERE name='Alice'")==9,'aucun PA sur acte refuse')
 reset();creer();repondre('Bob',True);rpc("SELECT set_config('test.acteur','Claire',false)");check(clore()['raison']=='pas_mon_offre','tiers ne clot pas');rpc("SELECT set_config('test.acteur','',false)");check(not clore()['ok'],'session absente');rpc("SELECT set_config('test.acteur','Alice',false)");clore();rpc("SELECT set_config('test.acteur','Bob',false)");check(rpc("SELECT tournee_repondre((SELECT id FROM invitations_diner WHERE invite='Bob'),NULL)")['ok'],'accuse apres relecture');check(rpc("SELECT statut FROM invitations_diner WHERE invite='Bob'")=='vue','ne pas afficher de nouveau le bonus');rpc("SELECT set_config('test.acteur','Alice',false)")
 reset();creer();repondre('Bob',True);c.execute("UPDATE entreprises SET data=jsonb_set(data,'{stockProduits,biere}','1')");check(not clore()['ok'],'stock insuffisant');check(rpc("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==1000,'pas de debit partiel stock')
 # Le contrat ancien est conserve pour une invitation deja en cours avant la bascule.
 reset();c.execute("INSERT INTO tournees(id,country,ville,offreur,building_id,room_id,commerce_type,recette_id,prix_unitaire_reference,statut,expires_at) VALUES('ancien','republic','capitale','Alice','hotel','bar','bar','biere',77,'en_resolution',now()+interval '5 minutes')");c.execute("INSERT INTO invitations_diner(inviteur,invite,country,city,building_id,room_id,statut,tournee_id) VALUES('Alice','Bob','republic','capitale','hotel','bar','acceptee','ancien')");check(clore('ancien')['ok'],'ancienne tournee cloturable');check(rpc("SELECT moral FROM personnages_donnees WHERE name='Bob'")==52,'ancienne regle preservee pour acte existant')
 reset();creer();repondre('Bob',True);c.execute("UPDATE personnages_donnees SET hp=99,resources='{\"inf\":99}',stats='{\"ENT\":19}'");clore();check(rpc("SELECT count(*) FROM personnages_donnees WHERE name IN ('Alice','Bob') AND hp=100 AND resources->>'inf'='100' AND stats->>'ENT'='20'")==2,'plafonds conserves')
 check(rpc("SELECT commerce_production_autorisee('{\"proprietaire\":\"Alice\",\"salaries\":[{\"ref\":\"pj:Bob\",\"actif\":true}]}','Bob')"),'salarie actif habilite a produire')
 check(not rpc("SELECT commerce_production_autorisee('{\"proprietaire\":\"Alice\",\"salaries\":[{\"ref\":\"pj:Bob\",\"actif\":false}]}','Bob')"),'salarie inactif refuse')
 check(not rpc("SELECT commerce_production_autorisee('{\"proprietaire\":\"Alice\",\"salaries\":[{\"ref\":\"pj:Claire\",\"actif\":true}]}','Bob')"),'emploi ailleurs ne vaut pas droit ici')
 # Une definition vivante inconnue ne doit jamais etre ecrasee par le fichier prepare.
 c.execute("CREATE OR REPLACE FUNCTION commerce_produire(p_acteur text,p_entreprise text,p_recette text,p_ordre text DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$")
 try:c.execute(migration);raise AssertionError('definition inconnue ecrasee')
 except psycopg2.Error as e:
  c.execute('ROLLBACK');check('precondition_definition_differente' in str(e),'garde definition vivante')
 print(f'{n}/{n} assertions PostgreSQL locales reussies ; services annexes de fixture, aucune preuve de production.')
 db.close()
if __name__=='__main__':main()
