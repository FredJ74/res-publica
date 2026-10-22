#!/usr/bin/env python3
"""Moteurs de vente et repos archives reels ; fiscalite/paiement/auth de fixture, aucune production."""
from pathlib import Path
import re,json,tempfile,importlib.util
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
def fonction(f,nom):
 s=(R/f).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 import pgserver,psycopg2
 spec=importlib.util.spec_from_file_location('boire',R/'outils/bancs/banc-offrir-boire-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-hotel63-'),cleanup_mode='delete');uri=server.get_uri();n=0
 try:
  with psycopg2.connect(uri) as db:
   db.autocommit=True;c=db.cursor();c.execute(m.SCHEMA)
   c.execute("""ALTER TABLE personnages_donnees ADD COLUMN reservation_hotel jsonb,ADD COLUMN detention_qhs jsonb,ADD COLUMN bonus_pa_differe integer DEFAULT 0,ADD COLUMN pa_repos_le date,ADD COLUMN inventory jsonb DEFAULT '[]';CREATE TABLE pa_bonus_hotel(building_id text PRIMARY KEY,montant integer);INSERT INTO pa_bonus_hotel VALUES('hotel-republica',2),('hotel-port',2),('hotel-mineur',2);CREATE FUNCTION militaire_grade_effectif(text) RETURNS text LANGUAGE sql AS $$SELECT NULL::text$$;CREATE TABLE paiements(montant integer);CREATE TABLE recettes_structures(caisse text,montant numeric);
   CREATE OR REPLACE FUNCTION payer_ordre(text,text,integer,integer) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN IF (SELECT refus FROM reglages) THEN RETURN '{\"ok\":false,\"raison\":\"refus_fixture\"}';END IF;UPDATE personnages_donnees SET liquide=liquide-$4,arg=arg-$4,pa=pa-$3 WHERE name=$1 AND liquide>=$4 AND pa>=$3;IF NOT FOUND THEN RETURN '{\"ok\":false,\"raison\":\"fonds_insuffisants\"}';END IF;INSERT INTO paiements VALUES($4);RETURN '{\"ok\":true}';END$$;
   CREATE OR REPLACE FUNCTION caisse_institution_mouvement(text,numeric,boolean) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO recettes_structures VALUES($1,$2);RETURN '{\"ok\":true}';END$$;""")
   for fn in ['restaurant_luthecia_est_commerce','restaurant_luthecia_carte','restaurant_luthecia_vente_verifier','commerce_vendre_produit_interne']:c.execute(fonction('migrations/20261019221500_luthecia_cartes_et_diners.sql',fn))
   c.execute(fonction('migrations/20261019213444_catalogue_et_offrir_a_boire.sql','commerce_vendre_produit'))
   for fn in ['pa_bonus_chambre','pa_crediter_interne','pa_repos_nocturne']:c.execute(fonction('baseline/domaines/finances-publiques/20_fonctions-1.sql',fn))
   c.execute(fonction('baseline/domaines/finances-publiques/20_fonctions-2.sql','vente_structure_encaisser'))
   c.execute('REVOKE ALL ON FUNCTION commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric) FROM PUBLIC,anon,authenticated,service_role')
   c.execute((R/'migrations/20261020114246_reservation_republica_accueil.sql').read_text())
   hotel={'type':'brasserie','country':'republic','city':'capitale','buildingId':'hotel-republica','versionGastronomieLuthecia':1,'carte':['biere'],'cartesParPiece':{'bar':['biere'],'restaurant':['biere']},'parametres':{'prixVente':{'biere':25}},'stockProduits':{'biere':10},'caisse':100}
   c.execute("INSERT INTO entreprises VALUES('hotel',%s,now())",(json.dumps(hotel),))
   c.execute("INSERT INTO personnages_donnees(name,country,current_city,current_building,current_room,arg,liquide,pa,hp,moral,reservation_hotel) VALUES('Alice','republic','capitale','hotel-republica','accueil',2000,2000,5,80,50,'{\"buildingId\":\"hotel-republica\",\"bonus\":{\"paBonus\":2,\"moral\":3}}');SET test.acteur='Alice'")
   migration=(R/'migrations/20261021214324_reservations_hotel_cumulables.sql').read_text();c.execute(migration);c.execute(migration)
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def q(sql,args=()):c.execute(sql,args);return c.fetchone()[0]
   def nuits():return q("SELECT reservation_hotel->'nuits' FROM personnages_donnees WHERE name='Alice'")
   def photo():return q("SELECT jsonb_build_array((SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='Alice'),(SELECT jsonb_agg(p) FROM paiements p),(SELECT jsonb_agg(t) FROM taxes t),(SELECT jsonb_agg(r) FROM hotel_requetes r),(SELECT jsonb_agg(e) FROM entreprises e),(SELECT jsonb_agg(r) FROM recettes_structures r),(SELECT jsonb_agg(h) FROM hotel_repos h))")
   def reserver(id,bat='hotel-republica',cur=c):cur.execute('SELECT hotel_reserver(%s,%s)',(id,bat));return cur.fetchone()[0]
   ok(len(nuits())==1 and nuits()[0]['source']=='legacy','ancien droit conserve sans ville inventee')
   ok(reserver('nuit-1')['ok'] and reserver('nuit-2')['ok'],'deux nuits payees dans le meme hotel')
   ok(len(nuits())==3,'aucun ecrasement du droit ancien ni des achats successifs')
   avant=photo();ok(reserver('nuit-1')['rejeu'],'reponse perdue reprise par meme recu');ok(photo()==avant,'rejeu aucun paiement taxe ou nuit en plus')
   c.execute("UPDATE personnages_donnees SET current_city='ville_a',current_building='hotel-port',current_room='hall_port' WHERE name='Alice'")
   ok(reserver('nuit-port','hotel-port')['ok'],'autre hotel utilise encaissement structure existant')
   ok(len(nuits())==4,'droits multi villes conserves')
   ok(q('SELECT count(*) FROM paiements')==3,'trois achats exactement')
   ok(q('SELECT sum(montant) FROM taxes')==22,'taxes existantes sur 80+80+60')
   ok(q("SELECT sum(montant) FROM recettes_structures WHERE caisse='republic_hotel_ville_a'")==54,'bonne caisse hotel du Port')
   d=psycopg2.connect(uri);cc=d.cursor();cc.execute("SELECT jsonb_array_length(reservation_hotel->'nuits') FROM personnages_donnees WHERE name='Alice'");ok(cc.fetchone()[0]==4,'F5 nouvelle connexion retrouve tous les droits');d.close()
   c.execute("UPDATE personnages_donnees SET reservation_hotel=NULL WHERE name='Alice'");ok(len(nuits())==4,'ancienne sauvegarde ne peut effacer les nuits')
   c.execute("UPDATE personnages_donnees SET current_room='rue' WHERE name='Alice'");avant=photo();ok(not reserver('rue','hotel-port')['ok'],'achat rue refuse');ok(photo()==avant,'refus rue sans mutation')
   c.execute("UPDATE personnages_donnees SET current_city='capitale',current_building='hotel-republica',current_room='chambres' WHERE name='Alice'")
   ok(not q("SELECT pa_bonus_chambre('Alice','hotel-republica')")['ok'],'bonus refuse sans repos atteste')
   ok(q("SELECT pa_repos_nocturne('Alice')")['ok'],'meme repos commun atteste la chambre et une nuit disponible')
   ok(len(nuits())==4,'attestation seule ne consomme pas la nuit')
   r=q("SELECT pa_bonus_chambre('Alice','hotel-republica')");ok(r['ok'] and r['montant']==2 and r['moral']==53,'bonus et consommation serveur atomiques')
   ok(len(nuits())==3,'exactement une nuit consommee')
   avant=photo();ok(q("SELECT pa_bonus_chambre('Alice','hotel-republica')")['rejeu'],'double bonus recu idempotent');ok(photo()==avant,'aucun second bonus ni perte de droit')
   c.execute("UPDATE personnages_donnees SET current_room='accueil' WHERE name='Alice'");ok(reserver('apres-sommeil')['ok'],'achat possible apres sommeil du jour');ok(len(nuits())==4,'nouvelle nuit reste disponible sans echeance')
   c.execute("UPDATE personnages_donnees SET current_room='chambres' WHERE name='Alice'");ok(not q("SELECT pa_repos_nocturne('Alice')")['ok'],'second repos refuse')
   q("SELECT pa_bonus_chambre('Alice','hotel-republica')");ok(len(nuits())==4,'repos deja effectue ne consomme pas une seconde nuit')
   c.execute("UPDATE hotel_repos SET jour=jour-1;UPDATE personnages_donnees SET pa_repos_le=pa_repos_le-1,pa=5 WHERE name='Alice'")
   ok(len(nuits())==4,'changement de jour ne perime aucun droit')
   q("SELECT pa_repos_nocturne('Alice')");q("SELECT pa_bonus_chambre('Alice','hotel-republica')");ok(len(nuits())==3,'consommation suivante un jour global different')
   c.execute("UPDATE personnages_donnees SET current_room='accueil',liquide=80,arg=80 WHERE name='Alice'")
   def conc(_):
    with psycopg2.connect(uri) as d:
     d.autocommit=True;cur=d.cursor();cur.execute("SET test.acteur='Alice'");return reserver('concurrent',cur=cur)
   with ThreadPoolExecutor(2) as pool:rs=list(pool.map(conc,range(2)))
   ok(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'achats concurrents meme requete : paiement et droit uniques')
   avant=photo();ok(not reserver('pauvre')['ok'],'fonds insuffisants');ok(photo()==avant,'aucune nuit ou contrepartie partielle')
   ok(not q("SELECT commerce_vendre_produit('Alice','hotel','[]','service','reserver_chambre_hotel',0,80)")['ok'],'ancien paiement de chambre sans recu ferme avant debit')
   ok(not q("SELECT vente_structure_encaisser('reserver_chambre_hotel',0,60,'republic_hotel_capitale','capitale')")['ok'],'ancienne vente structure sans droit atomique fermee')
   c.execute("UPDATE personnages_donnees SET liquide=80,arg=80 WHERE name='Alice';CREATE FUNCTION panne_nuit() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_fixture';END$$;CREATE TRIGGER panne_nuit BEFORE UPDATE OF reservation_hotel ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION panne_nuit()")
   avant=photo()
   try:reserver('panne');raise AssertionError('panne non levee')
   except psycopg2.Error:pass
   ok(photo()==avant,'panne attribution annule paiement, taxes, caisse et recu');c.execute('DROP TRIGGER panne_nuit ON personnages_donnees');ok(reserver('panne')['ok'],'reprise meme cle apres rollback')
   c.execute("DELETE FROM hotel_repos;UPDATE personnages_donnees SET current_room='chambres',pa_repos_le=NULL,pa=5 WHERE name='Alice'")
   q("SELECT pa_repos_nocturne('Alice')");nb_avant=len(nuits());moral_avant=q("SELECT moral FROM personnages_donnees WHERE name='Alice'")
   def bonus_concurrent(_):
    with psycopg2.connect(uri) as d:
     d.autocommit=True;cur=d.cursor();cur.execute("SET test.acteur='Alice';SELECT pa_bonus_chambre('Alice','hotel-republica')");return cur.fetchone()[0]
   with ThreadPoolExecutor(2) as pool:rs=list(pool.map(bonus_concurrent,range(2)))
   ok(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'bonus concurrent : un recu de consommation')
   ok(len(nuits())==nb_avant-1 and q("SELECT pa FROM personnages_donnees WHERE name='Alice'")==19,'une nuit et deux PA de bonus seulement')
   ok(q("SELECT moral FROM personnages_donnees WHERE name='Alice'")==min(100,moral_avant+3),'moral accorde une fois')
   c.execute("INSERT INTO personnages_donnees(name,reservation_hotel) VALUES('Bob','{\"version\":2,\"nuits\":[{\"id\":\"forge\"}]}')")
   ok(q("SELECT jsonb_array_length(reservation_hotel->'nuits') FROM personnages_donnees WHERE name='Bob'")==0,'creation de personnage ne peut fabriquer de nuitee')
   c.execute("SELECT has_table_privilege('authenticated','hotel_requetes','SELECT'),has_function_privilege('authenticated','hotel_reservation_ajouter(text)','EXECUTE'),has_function_privilege('anon','hotel_reserver(text,text)','EXECUTE')");ok(c.fetchone()==(False,False,False),'moteurs prives, aucun droit anonyme')
  print(f'{n}/{n} assertions PostgreSQL locales ; services annexes simules, aucune production.')
 finally:server.cleanup()
if __name__=='__main__':main()
