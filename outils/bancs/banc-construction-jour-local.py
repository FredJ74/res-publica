#!/usr/bin/env python3
"""Progression et appels de fonds, vrais moteurs financiers/approvisionnement, base jetable."""
from pathlib import Path
import re,tempfile,json
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
def fn(f,nom):
 s=(R/f).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-construction-jour-'),cleanup_mode='delete');n=0
 try:
  with psycopg2.connect(server.get_uri()) as db:
   db.autocommit=True;c=db.cursor()
   c.execute("""CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
   CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,arg integer,liquide integer,updated_at timestamptz);
   CREATE TABLE comptes_bancaires(personnage text,banque text,solde numeric,updated_at timestamptz);
   CREATE TABLE organisations(id text PRIMARY KEY,data text);
   CREATE TABLE caisses_batiments(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
   CREATE TABLE cycles_electoraux(country text,poste_id text,city text,data text);
   CREATE TABLE terrains_etat(id text PRIMARY KEY,country text,building_id text,proprietaire text,data text,updated_at timestamptz);
   CREATE TABLE batiments_etat(id text PRIMARY KEY,country text,city text,data jsonb,updated_at timestamptz);
   CREATE TABLE villes(pays text,ville text);INSERT INTO villes VALUES('republic','capitale');
   CREATE TABLE chantiers_besoins_jour(position_cycle integer,bois numeric,minerai numeric,metal numeric);
   CREATE TABLE entrepots_par_ville(ville text,building_id text);INSERT INTO entrepots_par_ville VALUES('capitale','entrepot');
   CREATE TABLE ressources_economie(cle text PRIMARY KEY,prix_base numeric);INSERT INTO ressources_economie VALUES('bois',5),('minerai',10),('metal',15);
   CREATE TABLE entreprises_constantes(cle text PRIMARY KEY,valeur numeric);INSERT INTO entreprises_constantes VALUES('chantier_taux_horaire',70);
   CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT current_setting('test.serveur',true)='on'$$;
   CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF NOT est_appel_serveur() THEN RAISE EXCEPTION 'interdit_fixture';END IF;END$$;
   CREATE TABLE notifications(destinataire text,sujet text,corps text);
   CREATE FUNCTION mail_systeme_poser_interne(text,text,text,text,text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO notifications VALUES($2,$3,$4);RETURN '{"ok":true}';END$$;
   SET test.serveur='on';""")
   for f,nom in [('migrations/20261020222029_construction_lancement_priorite_bancaire.sql','helvetia_debiter_fonds_ordinaires'),('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_institution_mouvement'),('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','batiment_etat_lire'),('baseline/domaines/economie/20_fonctions-1.sql','entrepot_caisse_id'),('baseline/domaines/economie/20_fonctions-1.sql','entrepot_caisse_mouvement'),('baseline/domaines/economie/20_fonctions-1.sql','approvisionner_chantier')]:c.execute(fn(f,nom))
   for f in ['chantiers_besoins_jour']:
    s=(R/f'baseline/seeds/90_socle/{f}.sql').read_text();c.execute(s)
   for f in sorted((R/'migrations').glob('202610221233*.sql')):c.execute(f.read_text());c.execute(f.read_text())
   c.execute("INSERT INTO personnages_donnees VALUES('Alice','republic',60000,30000,now());INSERT INTO comptes_bancaires VALUES('Alice','nationale',30000,now());INSERT INTO caisses_batiments VALUES('republic_gouvernement-min_fin','{\"solde\":0}',now()),('republic_entrepot_capitale','{\"solde\":0}',now()),('republic_mairie_capitale','{\"solde\":60000}',now());INSERT INTO organisations VALUES('orga','{\"chef\":\"Chef\",\"caisse\":60000}');INSERT INTO cycles_electoraux VALUES('republic','maire','capitale','{\"eluId\":\"Maire1\"}');INSERT INTO batiments_etat VALUES('republic_capitale_entrepot','republic','capitale','{\"entrepot\":{\"stock\":{\"bois\":10000,\"minerai\":10000,\"metal\":10000}}}',now())")
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def q(sql,args=()):c.execute(sql,args);return c.fetchone()[0]
   def creer(id,owner='Alice',progress=0,verse=10500,tre=10500):
    ch={'type':'construction','niveau':'hangar','dureeJours':6,'coutTotal':30000,'coutTravail':21000,'progressionJours':progress,'totalVerse':verse,'tresorerie':tre,'heuresFaites':0,'stockMateriaux':{},'evenements':[]}
    etat={'city':'capitale','proprietaire':owner,'surface':741,'prixAchat':23000,'chantier':ch}
    c.execute('INSERT INTO terrains_etat VALUES(%s,\'republic\',%s,%s,%s,now())',(id,id,owner,json.dumps(etat)));return etat
   def traiter(id,cur=c):cur.execute('SELECT chantier_jour_traiter(%s)',(id,));return cur.fetchone()[0]
   def prochain(id):c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,jourTraite}','null')::text WHERE id=%s",(id,))
   def photo():return q("SELECT jsonb_build_array((SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t),(SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c),(SELECT jsonb_agg(c) FROM comptes_bancaires c),(SELECT jsonb_agg(b) FROM batiments_etat b),(SELECT jsonb_agg(n) FROM notifications n),(SELECT jsonb_agg(o) FROM organisations o))")
   creer('normal');r=traiter('normal');ch=r['etat']['chantier'];ok(ch['progressionJours']==1 and ch['tresorerie']==5505,'journee reelle, matieres et PNJ payes')
   ok(q("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_entrepot_capitale'")=='1495','recette entrepot dans seule caisse canonique')
   ok(q("SELECT batiment_etat_lire(data)->'entrepot' ? 'caisse' FROM batiments_etat")==False,'aucune caisse parasite dans le blob')
   avant=photo();ok(traiter('normal')['rejeu'] and photo()==avant,'reponse perdue : meme jour aucun double achat travail debit mail')
   prochain('normal');r=traiter('normal');ch=r['etat']['chantier'];ok(ch['progressionJours']==2 and ch['totalVerse']==21000,'premier tiers : appel automatique 35 pour cent')
   ok(q("SELECT solde FROM comptes_bancaires WHERE personnage='Alice'")==19500,'appel banque prioritaire, liquide preserve')
   ok(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==30000,'liquide inchange quand banque suffit')
   for jour in range(3,7):prochain('normal');r=traiter('normal')
   ok(r['etat']['chantier']['progressionJours']==6 and r['etat']['chantier']['totalVerse']==30000,'deux tiers : 30 pour cent puis 6 jours incompressibles')
   ok(r['attenteReception'] and not r['etat'].get('niveau_construction') and not r['etat'].get('subdivisions'),'achevement sans livraison ni locaux avant reception')
   ok(q("SELECT count(*) FROM notifications WHERE sujet='Chantier acheve — reception sur place'")==1,'invitation reception unique')
   avant=photo();prochain('normal');traiter('normal');ok(q("SELECT count(*) FROM notifications WHERE sujet='Chantier acheve — reception sur place'")==1,'lendemain acheve : aucun nouvel achat salaire ni invitation')
   creer('pauvre',progress=2,tre=0);c.execute("UPDATE personnages_donnees SET liquide=2,arg=3;UPDATE comptes_bancaires SET solde=1")
   r=traiter('pauvre');ok(r['etat']['chantier']['arrete']=='financement' and r['etat']['chantier']['progressionJours']==2,'fonds insuffisants : pause sans progression')
   ok(q('SELECT liquide FROM personnages_donnees')==2 and q('SELECT solde FROM comptes_bancaires')==1,'aucun debit partiel en refus')
   nb=q("SELECT count(*) FROM notifications WHERE sujet='Chantier en pause — financement'");prochain('pauvre');traiter('pauvre');ok(q("SELECT count(*) FROM notifications WHERE sujet='Chantier en pause — financement'")==nb,'manque persistant : pas de mail duplique')
   c.execute('UPDATE comptes_bancaires SET solde=10500');prochain('pauvre');r=traiter('pauvre');ok(r['etat']['chantier']['progressionJours']==3 and r['etat']['chantier']['totalVerse']==21000,'fonds arrives : reprise automatique, temps utile conserve')
   # Meme moteur et memes seuils pour les deux personnes morales, pas de branche de progression municipale.
   for id,owner in [('organisation','orga:orga'),('commune','ville:republic:capitale')]:
    creer(id,owner,progress=2,tre=0);r=traiter(id);ok(r['etat']['chantier']['progressionJours']==3 and r['etat']['proprietaire']==owner,'financeur et propriete stables '+owner)
   ok(q("SELECT data::jsonb->>'caisse' FROM organisations")=='49500','caisse organisation reelle debitee')
   ok(q("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_mairie_capitale'")=='49500','caisse municipale reelle debitee')
   c.execute("UPDATE cycles_electoraux SET data='{\"eluId\":\"Maire2\"}'");prochain('commune');r=traiter('commune');ok(r['etat']['chantier']['progressionJours']==4 and r['etat']['proprietaire']=='ville:republic:capitale','changement de maire : chantier autonome et communal')
   creer('concurrent',owner='orga:orga')
   def concurrent(_):
    with psycopg2.connect(server.get_uri()) as d:
     cc=d.cursor();cc.execute("SET test.serveur='on'");return traiter('concurrent',cc)
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,range(2)))
   ok(all(x['ok'] for x in rs) and sum(bool(x.get('rejeu')) for x in rs)==1,'deux cron concurrents : une seule journee')
   creer('rollback',owner='orga:orga',progress=2,tre=0)
   c.execute("CREATE FUNCTION panne() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.id='rollback' THEN RAISE EXCEPTION 'panne_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne BEFORE UPDATE ON terrains_etat FOR EACH ROW EXECUTE FUNCTION panne()")
   avant=photo()
   try:traiter('rollback');raise AssertionError('panne attendue')
   except psycopg2.Error as e:db.rollback();assert 'panne_fixture' in str(e)
   ok(photo()==avant,'panne finale : rollback fonds stocks caisses notifications et temps')
   c.execute("SET test.serveur='off'");avant=photo();ok(traiter('normal')['raison']=='reserve_au_serveur' and photo()==avant,'appel navigateur refuse sans mutation')
   c.execute("SELECT has_function_privilege('authenticated','chantier_jour_traiter(text)','EXECUTE'),has_function_privilege('service_role','chantier_jour_traiter(text)','EXECUTE'),has_function_privilege('service_role','chantier_financeur_debiter_interne(jsonb,numeric)','EXECUTE')")
   ok(c.fetchone()==(False,True,False),'droits : cron seul, primitives financieres privees')
  print(f'{n}/{n} assertions, PostgreSQL jetable ; authentification et notifications de fixture, aucun acces production.')
 finally:server.cleanup()
if __name__=='__main__':main()
