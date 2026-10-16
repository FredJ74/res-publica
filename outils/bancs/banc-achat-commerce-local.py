#!/usr/bin/env python3
"""PostgreSQL local jetable UNIQUEMENT, jamais une URL distante.

Usage : python3 outils/bancs/banc-achat-commerce-local.py --local-jetable
Dependances de test : pgserver, psycopg2-binary. Aucun secret utilise.
La vraie fonction SQL est chargee ; ses services annexes sont des fixtures.
Cela eprouve l'atomicite de la livraison, PAS l'authentification Supabase.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import re
from pathlib import Path
import tempfile
import threading

RACINE = Path(__file__).resolve().parents[2]

SCHEMA = """
CREATE TABLE personnages (name text PRIMARY KEY, arg numeric);
CREATE TABLE organisations (id text PRIMARY KEY, data jsonb);
CREATE TABLE entreprises (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE TABLE catalogue_generiques (id text,libelle text,regime text,est_service boolean,
 empilable boolean,individualise boolean,encombrement numeric,famille_id text);
CREATE TABLE recettes_commerce (id text,generique_id text);
CREATE TABLE catalogue_variantes (id text,libelle text,generique_id text);
CREATE TABLE catalogue_types (id text,libelle text,ordre integer);
CREATE TABLE catalogue_generique_type (generique_id text,type_id text);
CREATE TABLE objets_recus (id text PRIMARY KEY,destinataire text,expediteur text,data jsonb);
CREATE TABLE ventes_snapshots (id bigserial PRIMARY KEY,requete text UNIQUE,jour_paris text,
 acheteur text,vendeur text,fonds_id text,pays text,reference_id text,nom_commercial text,
 description_commerciale text,generique_id text,recette_id text,variante_id text,famille text,
 types jsonb,quantite integer,prix_unitaire numeric,montant_total numeric,fiche_officielle jsonb);
CREATE TABLE reglages_test (refuser_debit boolean,erreur_fiche boolean,ralentir boolean);
INSERT INTO reglages_test VALUES (false,false,false);
CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN END $$;
CREATE FUNCTION fonds_acteur_present(text,jsonb) RETURNS boolean LANGUAGE sql AS $$ SELECT true $$;
CREATE FUNCTION fonds_generiques_accessibles(text) RETURNS TABLE(generique_id text,famille text)
 LANGUAGE sql AS $$ SELECT 'produit'::text,'commerce'::text $$;
CREATE FUNCTION fonds_cout_revient_reference(text,text) RETURNS jsonb LANGUAGE sql AS
 $$ SELECT '{"disponible":true,"prixMaximum":100,"coutUnitaire":5}'::jsonb $$;
CREATE FUNCTION appliquer_taxe_transaction(text,text,integer) RETURNS jsonb LANGUAGE sql AS
 $$ SELECT jsonb_build_object('net',$3,'taxeLocale',0,'taxeNationale',0) $$;
CREATE FUNCTION objet_fiche_officielle(jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
 BEGIN
  IF (SELECT erreur_fiche FROM reglages_test) THEN RAISE EXCEPTION 'erreur_fiche_test'; END IF;
  RETURN $1;
 END $$;
CREATE FUNCTION mouvement_titulaire(text,numeric) RETURNS boolean LANGUAGE plpgsql AS $$
 DECLARE solde numeric;
 BEGIN
  IF $2 < 0 AND (SELECT refuser_debit FROM reglages_test) THEN RETURN false; END IF;
  IF $2 < 0 AND (SELECT ralentir FROM reglages_test) THEN PERFORM pg_sleep(0.15); END IF;
  SELECT arg INTO solde FROM personnages WHERE name=$1 FOR UPDATE;
  IF NOT FOUND OR solde+$2<0 THEN RETURN false; END IF;
  UPDATE personnages SET arg=arg+$2 WHERE name=$1;
  RETURN true;
 END $$;
INSERT INTO catalogue_generiques VALUES ('produit','Produit','legal',false,true,false,1,'objet');
"""

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--local-jetable', action='store_true', required=True)
    p.parse_args()
    import pgserver
    import psycopg2
    serveur = pgserver.get_server(tempfile.mkdtemp(prefix='hg-achat-test-'), cleanup_mode='delete')
    uri = serveur.get_uri()  # ne pas afficher, ne provient d'aucune variable d'environnement
    connexion = psycopg2.connect(uri)
    connexion.autocommit = True
    cur = connexion.cursor()
    cur.execute(SCHEMA)
    source = (RACINE/'baseline/domaines/economie/20_fonctions-1.sql').read_text()
    debut = source.index('CREATE OR REPLACE FUNCTION public.acheter_produit_commerce(')
    fin = source.index('$function$;', debut) + len('$function$;')
    cur.execute(source[debut:fin])
    fonds = {'version':2,'statut':'actif','proprietaire':'Vendeur',
        'implantation':{'country':'republic','city':'capitale'},'caisse':0,
        'references':{'ref':{'active':True,'prixVente':10,'generique_id':'produit','nom':'Produit'}},
        'stockReferences':{'ref':5},'coutMoyenReferences':{'ref':5}}

    def reset(solde=100):
        cur.execute('TRUNCATE personnages,entreprises,objets_recus,ventes_snapshots')
        cur.execute('INSERT INTO personnages VALUES (%s,%s)', ('Temoin',solde))
        for id in ['fonds-a','fonds-b']:
            cur.execute('INSERT INTO entreprises VALUES (%s,%s,now())',(id,json.dumps(fonds)))
        cur.execute('UPDATE reglages_test SET refuser_debit=false,erreur_fiche=false,ralentir=false')

    def achat(requete='achat-temoin-001',fonds_id='fonds-a'):
        cur.execute('SELECT acheter_produit_commerce(%s,%s,%s,%s,%s)',(requete,'Temoin',fonds_id,'ref',1))
        return cur.fetchone()[0]

    def quantite(table):
        assert table in ('objets_recus','ventes_snapshots')
        cur.execute('SELECT count(*) FROM '+table)
        return cur.fetchone()[0]

    reset();cur.execute('UPDATE reglages_test SET refuser_debit=true')
    assert achat()['ok'] is False
    assert quantite('objets_recus') == 1, 'Le defaut historique doit etre reproduit avant correction'
    print('REPRODUCTION : ancienne definition, debit refuse mais une livraison creee.')
    reset()
    migration=(RACINE/'migrations/20261016070541_achat_commerce_debit_avant_livraison.sql').read_text()
    # Aucun coefficient, filtre ni effet n'a change : seul ce bloc est deplace.
    bloc = "IF NOT public.mouvement_titulaire(p_acheteur, -v_montant) THEN\n    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');\n  END IF;"
    def normaliser(corps):
        return re.sub(r'\s+', ' ', re.sub(r'--[^\n]*', '', corps)).strip()
    ancien=source[debut:fin].split('AS $function$',1)[1].split('$function$;',1)[0]
    nouveau=migration.split('AS $function$',1)[1].split('$function$;',1)[0]
    assert normaliser(ancien.replace(bloc,'')) == normaliser(nouveau.replace(bloc,'')), 'Autre regle modifiee'
    cur.execute(migration);cur.execute(migration)
    print('OK : migration compilee et rejouee dans PostgreSQL local jetable.')
    cur.execute('UPDATE reglages_test SET refuser_debit=true')
    assert achat()['ok'] is False
    assert quantite('objets_recus') == 0 and quantite('ventes_snapshots') == 0
    cur.execute("SELECT arg FROM personnages WHERE name='Temoin'");assert cur.fetchone()[0]==100
    cur.execute("SELECT data->'stockReferences'->>'ref' FROM entreprises WHERE id='fonds-a'");assert cur.fetchone()[0]=='5'
    print('OK : debit refuse, aucun objet, vente, prelevement ou stock modifie.')
    reset();assert achat()['ok'] is True
    assert quantite('objets_recus') == 1 and quantite('ventes_snapshots') == 1
    cur.execute("SELECT arg FROM personnages WHERE name='Temoin'");assert cur.fetchone()[0]==90
    assert achat()['rejeu'] is True
    cur.execute("SELECT arg FROM personnages WHERE name='Temoin'");assert cur.fetchone()[0]==90
    assert quantite('objets_recus') == 1
    print('OK : achat nominal et rejeu, un seul debit et une seule livraison.')
    reset();cur.execute('UPDATE reglages_test SET erreur_fiche=true')
    try:
        achat()
        raise AssertionError('Exception attendue')
    except psycopg2.Error as e:
        assert 'erreur_fiche_test' in str(e)
    cur.execute("SELECT arg FROM personnages WHERE name='Temoin'");assert cur.fetchone()[0]==100
    assert quantite('objets_recus')==0 and quantite('ventes_snapshots')==0
    print('OK : erreur apres debit, transaction entiere annulee.')
    reset(10);cur.execute('UPDATE reglages_test SET ralentir=true')
    barriere=threading.Barrier(2)
    def concurrent(i):
        c=psycopg2.connect(uri);c.autocommit=True
        try:
            with c.cursor() as q:
                barriere.wait(timeout=10)
                q.execute('SELECT acheter_produit_commerce(%s,%s,%s,%s,1)',
                    ('achat-concurrent-'+str(i),'Temoin','fonds-'+('a' if i==0 else 'b'),'ref'))
                return q.fetchone()[0]
        finally: c.close()
    with ThreadPoolExecutor(max_workers=2) as pool:
        resultats=list(pool.map(concurrent,[0,1]))
    assert sum(r['ok'] is True for r in resultats)==1
    assert quantite('objets_recus')==1 and quantite('ventes_snapshots')==1
    cur.execute("SELECT arg FROM personnages WHERE name='Temoin'");assert cur.fetchone()[0]==0
    print('OK : deux connexions, deux commerces, un solde commun : une vente et une livraison.')
    # La garde doit refuser une definition inconnue plutot que l'ecraser.
    cur.execute("CREATE OR REPLACE FUNCTION acheter_produit_commerce(p_requete text,p_acheteur text,p_fonds_id text,p_reference_id text,p_quantite integer) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$")
    try:
        cur.execute(migration)
        raise AssertionError('Garde attendue')
    except psycopg2.Error as e:
        assert 'definition_a_reexaminer' in str(e)
    print('OK : une definition serveur differente est refusee par la garde.')
    connexion.close()
    print('7 scenarios PostgreSQL locaux reussis ; aucune connexion Supabase ni joueur reel.')

if __name__ == '__main__':
    main()
