#!/usr/bin/env python3
"""Contrat naval PSM sur PostgreSQL jetable. Aucune ecriture en production."""
from pathlib import Path
import tempfile
import json
import pgserver
import psycopg2

ROOT=Path(__file__).resolve().parents[2]
MODELES=ROOT/'migrations/20261104223000_chantier_naval_modeles_devis.sql'
MOTEUR=ROOT/'migrations/20261104224500_chantier_naval_construction_transactionnelle.sql'
INIT=r"""
CREATE ROLE authenticated;
CREATE ROLE anon;
CREATE ROLE service_role;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
CREATE TABLE public.personnages_donnees(
  user_id uuid PRIMARY KEY, name text UNIQUE, country text,
  current_city text,current_building text,liquide integer,arg integer,
  updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.batiments_etat(id text PRIMARY KEY,data jsonb,updated_at timestamptz DEFAULT now());
CREATE TABLE public.ressources_economie(cle text PRIMARY KEY,prix_base numeric);
CREATE TABLE public.ordres_couts(fn text,pa integer,cost integer, UNIQUE(fn,pa,cost));
CREATE TABLE public.entrepot_journal(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 entrepot_id text NOT NULL,operation text NOT NULL,sens text NOT NULL,
 ressource text,quantite numeric,prix_unitaire numeric,montant numeric,
 acteur text,jour date DEFAULT current_date,horodatage timestamptz DEFAULT now()
);
CREATE TABLE public.caisses_batiments(id text PRIMARY KEY,data jsonb,updated_at timestamptz DEFAULT now());
CREATE FUNCTION public.batiment_etat_lire(p jsonb) RETURNS jsonb
LANGUAGE sql STABLE AS $$ SELECT CASE WHEN jsonb_typeof(p)='string'
 THEN (p#>>'{}')::jsonb ELSE p END $$;
CREATE FUNCTION public.est_appel_serveur() RETURNS boolean
LANGUAGE sql STABLE AS $$ SELECT true $$;
CREATE FUNCTION public.helvetia_debiter_fonds_ordinaires(n text,m numeric)
RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM personnages_donnees WHERE name=n AND liquide>=m)
 THEN RETURN false;END IF;
 UPDATE personnages_donnees SET liquide=liquide-m,arg=arg-m WHERE name=n;
 RETURN true;
END $$;
CREATE FUNCTION public.entrepot_caisse_mouvement(e text,m numeric)
RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO caisses_batiments(id,data) VALUES(e,jsonb_build_object('solde',m))
 ON CONFLICT(id) DO UPDATE SET data=jsonb_build_object('solde',
  (caisses_batiments.data->>'solde')::numeric+m);
 RETURN '{"ok":true}'::jsonb;
END $$;
CREATE FUNCTION public.caisse_institution_mouvement(e text,m numeric,b boolean)
RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO caisses_batiments(id,data) VALUES(e,jsonb_build_object('solde',m))
 ON CONFLICT(id) DO UPDATE SET data=jsonb_build_object('solde',
  (caisses_batiments.data->>'solde')::numeric+m);
 RETURN '{"ok":true}'::jsonb;
END $$;
INSERT INTO ressources_economie VALUES ('bois',6),('metal',12),('derives_petrochimiques',20);
INSERT INTO personnages_donnees VALUES
 ('00000000-0000-4000-8000-0000000004c9','NAVAL-FIXTURE','republic','ville_a','chantier-naval',200000,200000,now());
INSERT INTO batiments_etat(id,data) VALUES
 ('republic_ville_a_entrepot-logistique-psm',
 '{"entrepot":{"stock":{"bois":100,"metal":100,"derives_petrochimiques":0},"prixManuel":{}}}');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-0000000004c9',false);
"""
def check(ok,msg):
    assert ok,msg
def test():
    with tempfile.TemporaryDirectory(prefix='hg-naval-') as d:
        srv=pgserver.get_server(Path(d)/'db',cleanup_mode='delete')
        try:
            c=psycopg2.connect(srv.get_uri())
            c.autocommit=True
            q=c.cursor()
            q.execute(INIT)
            q.execute(MODELES.read_text(encoding='utf8'))
            q.execute(MOTEUR.read_text(encoding='utf8'))
            q.execute("SELECT has_function_privilege('authenticated','public.chantier_naval_avancer_jour()','EXECUTE'),has_function_privilege('authenticated','public.chantier_naval_avancer_interne(uuid)','EXECUTE')")
            check(q.fetchone()==(False,False),'RPC serveur exposées aux joueurs')
            q.execute("SELECT chantier_naval_devis()")
            d0=q.fetchone()[0]
            check(len(d0)==2 and d0[0]['recette']['derives_petrochimiques']==600,'devis')
            requete='10000000-0000-4000-8000-000000000001'
            q.execute("SELECT chantier_naval_commander(%s,%s)",('bateau_3',requete))
            premiere=q.fetchone()[0]
            check(premiere['ok'] is True and premiere['acompte']==31500,'acompte')
            commande=premiere['commande']
            q.execute("SELECT chantier_naval_commander(%s,%s)",('bateau_3',requete))
            check(q.fetchone()[0].get('rejeu') is True,'commande dupliquée')
            q.execute("SELECT liquide FROM personnages_donnees WHERE name='NAVAL-FIXTURE'")
            check(q.fetchone()[0]==168500,'acompte débité deux fois')
            q.execute("SELECT chantier_naval_avancer_interne(%s)",(commande,))
            check(q.fetchone()[0]['raison']=='matieres_insuffisantes','blocage sans dérivés')
            q.execute("SELECT liquide FROM personnages_donnees WHERE name='NAVAL-FIXTURE'")
            check(q.fetchone()[0]==168500,'débit malgré blocage')
            q.execute("SELECT batiment_etat_lire(data)#>>'{entrepot,stock,bois}' FROM batiments_etat")
            check(q.fetchone()[0]=='100','prélèvement malgré blocage')
            q.execute("""UPDATE batiments_etat SET data='{"entrepot":{"stock":{"bois":2200,"metal":2200,"derives_petrochimiques":1200},"prixManuel":{}}}'::jsonb
             WHERE id='republic_ville_a_entrepot-logistique-psm'""")
            q.execute("SELECT chantier_naval_avancer_interne(%s)",(commande,))
            r=q.fetchone()[0]
            check(r['ok'] is True and r['jours']==1,'premier jour')
            q.execute("SELECT chantier_naval_avancer_interne(%s)",(commande,))
            check(q.fetchone()[0].get('rejeu') is True,'doublon journalier')
            for i in range(2,8):
                q.execute("UPDATE chantier_naval_commandes SET dernier_jour=current_date-1 WHERE id=%s",(commande,))
                q.execute("SELECT chantier_naval_avancer_interne(%s)",(commande,))
                r=q.fetchone()[0]
                check(r['ok'] is True and r['jours']==i,'jour '+str(i)+':'+str(r))
            q.execute("SELECT jours_faits,somme_versee,depense_matieres,etat FROM chantier_naval_commandes WHERE id=%s",(commande,))
            jours,verse,mat,etat=q.fetchone()
            check((jours,int(verse),int(mat),etat)==(7,90000,33600,'acheve'),'bilan commande')
            q.execute("SELECT liquide FROM personnages_donnees WHERE name='NAVAL-FIXTURE'")
            check(q.fetchone()[0]==110000,'double paiement ou échéance erronée')
            q.execute("SELECT count(*),min(passagers),min(capacite_fret),bool_and(navigation_active=false) FROM chantier_naval_bateaux")
            check(q.fetchone()==(1,3,300,True),'bateau physique sécurisé')
            q.execute("SELECT count(*) FROM entrepot_journal")
            check(q.fetchone()[0]==21,'traçabilité des 3 ressources et 7 jours')
            q.execute("SELECT id,(data->>'solde')::numeric FROM caisses_batiments")
            soldes=dict(q.fetchall())
            check(int(soldes['republic_ville_a_entrepot-logistique-psm'])==33600,'contrepartie entrepôt')
            check(int(soldes['republic_ville_a_chantier-naval'])==56400,'constructeur payé une seule fois')
            check(int(soldes['republic_ville_a_chantier-naval-commande-'+str(commande)])==0,'séquestre non soldé ou fonds disparus')
            check(sum(int(v) for v in soldes.values())==90000,'conservation des 90 000 FR versés')
            q.execute("SELECT chantier_naval_avancer_interne(%s)",(commande,))
            check(q.fetchone()[0]['etat']=='acheve','livraison rejouable')
            q.execute("SELECT count(*) FROM chantier_naval_bateaux")
            check(q.fetchone()[0]==1,'bateau livré deux fois')
            # Second modèle : 5 places, 500 fret, 10 jours, 150 000 FR, 600 dérivés.
            q.execute("UPDATE personnages_donnees SET liquide=250000,arg=250000 WHERE name='NAVAL-FIXTURE'")
            q.execute("""UPDATE batiments_etat SET data='{"entrepot":{"stock":{"bois":3000,"metal":3000,"derives_petrochimiques":1500},"prixManuel":{}}}'::jsonb
              WHERE id='republic_ville_a_entrepot-logistique-psm'""")
            q.execute("SELECT chantier_naval_commander(%s,%s)",('bateau_5','10000000-0000-4000-8000-000000000002'))
            grand=q.fetchone()[0]
            check(grand['ok'] is True and grand['acompte']==52500,'acompte grand bateau')
            commande_grand=grand['commande']
            for i in range(1,11):
                if i>1:
                    q.execute("UPDATE chantier_naval_commandes SET dernier_jour=current_date-1 WHERE id=%s",(commande_grand,))
                q.execute("SELECT chantier_naval_avancer_interne(%s)",(commande_grand,))
                r=q.fetchone()[0]
                check(r['ok'] is True and r['jours']==i,'grand bateau jour '+str(i)+':'+str(r))
            q.execute("SELECT somme_versee,depense_matieres,etat FROM chantier_naval_commandes WHERE id=%s",(commande_grand,))
            verse_grand,mat_grand,etat_grand=q.fetchone()
            check((int(verse_grand),int(mat_grand),etat_grand)==(150000,44400,'acheve'),'bilan grand bateau')
            q.execute("SELECT count(*),sum(capacite_fret),bool_and(navigation_active=false) FROM chantier_naval_bateaux")
            check(q.fetchone()==(2,800,True),'deux bateaux physiques et navigation privée inactive')
            q.execute("SELECT liquide FROM personnages_donnees WHERE name='NAVAL-FIXTURE'")
            check(q.fetchone()[0]==100000,'exactement 150 000 FR pour le grand bateau')
            q.execute("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id=%s",
              ('republic_ville_a_chantier-naval-commande-'+str(commande_grand),))
            check(int(q.fetchone()[0])==0,'séquestre du grand bateau non soldé')
            q.execute("SELECT sum((data->>'solde')::numeric) FROM caisses_batiments")
            check(int(q.fetchone()[0])==240000,'conservation financière des deux contrats')
            print(json.dumps({'ok':True,'jours':7,'cout_matieres':33600,
                              'caisse_constructeur':56400,'debit_pj':90000,
                              'bateaux':2,'rejeu':True,'production':False}))
            c.close()
        finally:
            srv.cleanup()
if __name__=='__main__':
    test()
