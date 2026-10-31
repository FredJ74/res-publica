#!/usr/bin/env python3
"""Vrais moteurs SQL sur PostgreSQL jetable ; paiement/fiscalite/auth de fixture seulement."""
import argparse, importlib.util, json, tempfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[2]
ORIGINAL=ROOT/'migrations/20261031113608_luthecia_cartes_et_diners.sql'
CORRECTIF=ROOT/'migrations/20261031113609_reservation_republica_accueil.sql'
def charger(nom,f):
 spec=importlib.util.spec_from_file_location(nom,ROOT/f);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--local-jetable',action='store_true',required=True);p.parse_args()
 import pgserver,psycopg2
 fixture=charger('boire','outils/bancs/banc-offrir-boire-local.py');restaurant=charger('restaurant','outils/bancs/banc-restaurant-luthecia-local.py')
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-reservation-'),cleanup_mode='delete');uri=server.get_uri()
 db=psycopg2.connect(uri);db.autocommit=True;c=db.cursor();c.execute(fixture.SCHEMA)
 c.execute("ALTER TABLE personnages_donnees ADD COLUMN reservation_hotel jsonb; CREATE TABLE pa_bonus_hotel(building_id text PRIMARY KEY,montant integer); INSERT INTO pa_bonus_hotel VALUES('hotel-republica',2)")
 for nom in ['restaurant_luthecia_est_commerce','restaurant_luthecia_carte','restaurant_luthecia_vente_verifier','commerce_vendre_produit_interne']:c.execute(restaurant.definition(nom,ORIGINAL))
 c.execute(restaurant.definition('commerce_vendre_produit',ROOT/'migrations/20261031113607_catalogue_et_offrir_a_boire.sql'))
 c.execute('REVOKE ALL ON FUNCTION commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric) FROM PUBLIC,anon,authenticated,service_role')
 for nom in ['pa_bonus_chambre','pa_crediter_interne']:c.execute(restaurant._sources.entree_historique(nom))
 # Le moteur appelle une fois le paiement, qui refuse sans mutation si le tarif/fonds sont invalides.
 c.execute('''CREATE TABLE paiements(acteur text,montant integer);
 CREATE OR REPLACE FUNCTION payer_ordre(text,text,integer,integer) RETURNS jsonb LANGUAGE plpgsql AS $$ BEGIN
 IF $2='reserver_chambre_hotel' AND ($3<>0 OR $4<>80) THEN RETURN '{"ok":false,"raison":"cout_non_declare"}'; END IF;
 IF (SELECT refus FROM reglages) THEN RETURN '{"ok":false,"raison":"paiement_refuse"}'; END IF;
 UPDATE personnages_donnees SET liquide=liquide-$4,arg=arg-$4,pa=pa-$3 WHERE name=$1 AND liquide>=$4 AND pa>=$3;
 IF NOT FOUND THEN RETURN '{"ok":false,"raison":"fonds_insuffisants"}'; END IF;
 INSERT INTO paiements VALUES($1,$4);
 RETURN '{"ok":true}'; END $$;
 CREATE FUNCTION reservation_panne() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF NEW.reservation_hotel IS NOT NULL AND (SELECT erreur FROM reglages) THEN RAISE EXCEPTION 'panne_persistance_fixture'; END IF; RETURN NEW; END $$;
 CREATE TRIGGER reservation_panne BEFORE UPDATE OF reservation_hotel ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION reservation_panne();''')
 n=0
 def check(v,msg):
  nonlocal n;n+=1;assert v,msg
 def q(sql,args=()):c.execute(sql,args);return c.fetchone()[0]
 base={'type':'brasserie','country':'republic','city':'capitale','buildingId':'hotel-republica','versionGastronomieLuthecia':1,'carte':['biere'],'cartesParPiece':{'bar':['biere'],'restaurant':['biere']},'parametres':{'prixVente':{'biere':25}},'stockProduits':{'biere':10},'caisse':100}
 def reset(room='accueil'):
  c.execute('DELETE FROM paiements; DELETE FROM taxes; DELETE FROM entreprises; DELETE FROM personnages_donnees; UPDATE reglages SET refus=false,erreur=false')
  c.execute('INSERT INTO entreprises VALUES(%s,%s,now())',('hotel',json.dumps(base)))
  c.execute("INSERT INTO personnages_donnees(name,country,current_city,current_building,current_room,arg,liquide,pa,day) VALUES('Alice','republic','capitale','hotel-republica',%s,1000,1000,10,1)",(room,))
  q("SELECT set_config('test.acteur','Alice',false)");q("SELECT set_config('rp.diner_luthecia','off',false)")
 def reserver():return q("SELECT commerce_vendre_produit('Alice','hotel','[]','service','reserver_chambre_hotel',0,80)")
 def photo():return q("SELECT jsonb_build_array((SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='Alice'),(SELECT data FROM entreprises WHERE id='hotel'),(SELECT jsonb_agg(t) FROM taxes t),(SELECT jsonb_agg(p) FROM paiements p))")
 reset();avant=photo();check(reserver()['raison']=='pas_sur_place','contre-epreuve : ancien refus accueil reproduit');check(photo()==avant,'ancien refus sans debit')
 c.execute("UPDATE personnages_donnees SET current_room='bar'");check(reserver()['raison']=='service_par_invitation_requis','deuxieme garde historique bloquait aussi la prestation')
 reset();avant=photo();c.execute(CORRECTIF.read_text());check(photo()==avant,'migration sans mutation de donnees');c.execute(CORRECTIF.read_text());check(photo()==avant,'rejeu migration idempotent sans mutation')
 r=reserver();check(r['ok'],'reservation accueil acceptee');check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==920,'un seul debit 80 FR');check(q('SELECT count(*) FROM paiements')==1,'un seul appel paiement');check(q('SELECT sum(montant) FROM taxes')==8,'une seule taxation');check(q("SELECT (data->>'caisse')::numeric FROM entreprises WHERE id='hotel'")==172,'caisse creditee une fois');check(q("SELECT reservation_hotel->>'buildingId' FROM personnages_donnees WHERE name='Alice'")=='hotel-republica','reservation dans meme transaction')
 # Nouvelle connexion = aucune dependance a une sauvegarde du navigateur.
 autre=psycopg2.connect(uri);cc=autre.cursor();cc.execute("SELECT reservation_hotel FROM personnages_donnees WHERE name='Alice'");check(cc.fetchone()[0]=={'buildingId':'hotel-republica','bonus':{'moral':3,'paBonus':2}},'reservation payee retrouvee apres reconnexion');autre.close()
 c.execute("UPDATE personnages_donnees SET current_room='chambres'");r=q("SELECT pa_bonus_chambre('Alice','hotel-republica')");check(r['ok'] and r['montant']==2 and r['pa']==12,'vrai bonus SQL +2 PA');check(q("SELECT reservation_hotel IS NULL FROM personnages_donnees WHERE name='Alice'"),'reservation consommee');check(not q("SELECT pa_bonus_chambre('Alice','hotel-republica')")['ok'],'pas de second bonus')
 for room in [None,'rue','bar','restaurant','chambres']:
  reset(room);avant=photo();check(reserver()['raison']=='pas_sur_place','reservation refusee hors accueil '+str(room));check(photo()==avant,'refus sans argent/taxe/stock/reservation '+str(room))
 for champ,valeur in [('country','narco'),('current_city','ville_a'),('current_building','hotel-port')]:
  reset();c.execute('UPDATE personnages_donnees SET '+champ+'=%s',(valeur,));avant=photo();check(not reserver()['ok'],'territoire/batiment exact requis');check(photo()==avant,'mauvais territoire sans mutation')
 reset();avant=photo();r=q("SELECT commerce_vendre_produit('Alice','hotel','[{\"produit\":\"biere\",\"qte\":1}]','service','reserver_chambre_hotel',0,80)");check(r['raison']=='reservation_invalide','pas achat gratuit deguise en reservation');check(photo()==avant,'panier deguise sans debit')
 for room in ['bar','restaurant']:
  reset(room);check(q("SELECT commerce_vendre_produit('Alice','hotel','[{\"produit\":\"biere\",\"qte\":1}]')")['ok'],'achats conserves '+room)
  check(q("SELECT restaurant_luthecia_vente_verifier((SELECT data FROM entreprises LIMIT 1),'Alice','[]','service')")['raison']=='service_par_invitation_requis','ancien appel quatre arguments conserve garde diner')
 reset();check(not q("SELECT commerce_vendre_produit('Alice','hotel','[{\"produit\":\"biere\",\"qte\":1}]')")['ok'],'aucune boisson depuis accueil')
 reset('restaurant');q("SELECT set_config('rp.diner_luthecia','on',false)");check(q("SELECT restaurant_luthecia_vente_verifier((SELECT data FROM entreprises LIMIT 1),'Alice','[]','service','diner_affaires')")['ok'],'porte privee diner conservee')
 reset();c.execute("UPDATE personnages_donnees SET liquide=0,arg=0");avant=photo();check(not reserver()['ok'],'fonds insuffisants');check(photo()==avant,'fonds insuffisants sans mutation')
 reset();c.execute('UPDATE reglages SET erreur=true');avant=photo()
 try:reserver();raise AssertionError('panne non levee')
 except psycopg2.Error:pass
 check(photo()==avant,'panne persistance annule debit taxe caisse et reservation')
 reset();c.execute("UPDATE personnages_donnees SET liquide=80,arg=80")
 def concurrent(_):
  d=psycopg2.connect(uri);d.autocommit=True;cc=d.cursor();cc.execute("SELECT set_config('test.acteur','Alice',false)");cc.execute("SELECT commerce_vendre_produit('Alice','hotel','[]','service','reserver_chambre_hotel',0,80)");r=cc.fetchone()[0];d.close();return r
 with ThreadPoolExecutor(2) as pool:rs=list(pool.map(concurrent,range(2)))
 check(sum(bool(r['ok']) for r in rs)==1,'fonds concurrents un seul succes');check(q('SELECT count(*) FROM paiements')==1,'concurrence pas de double depense')
 reset();c.execute("UPDATE entreprises SET data=jsonb_set(data,'{buildingId}','\"hotel-port\"'); UPDATE personnages_donnees SET current_building='hotel-port'");check(reserver()['ok'],'autre hotel conserve son ancien circuit');check(q("SELECT reservation_hotel IS NULL FROM personnages_donnees WHERE name='Alice'"),'pas de nouvelle persistance imposee ailleurs')
 for signature in ['jsonb,text,jsonb,text','jsonb,text,jsonb,text,text']:
  check(not q("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",('restaurant_luthecia_vente_verifier('+signature+')',)),'controle prive '+signature)
 # Un moteur inconnu est refuse avant tout remplacement.
 c.execute("CREATE OR REPLACE FUNCTION restaurant_luthecia_vente_verifier(d jsonb,acteur text,produits jsonb,mode_vente text) RETURNS jsonb LANGUAGE plpgsql AS $$ BEGIN RETURN '{}'::jsonb; END $$")
 try:c.execute(CORRECTIF.read_text());raise AssertionError('definition inconnue ecrasee')
 except psycopg2.Error as e:c.execute('ROLLBACK');check('precondition_controle_vente_modifie' in str(e),'prevol refuse definition divergente')
 print(f'{n}/{n} assertions PostgreSQL locales reussies ; aucun acces Supabase, aucune donnee reelle.')
 db.close()
if __name__=='__main__':main()
