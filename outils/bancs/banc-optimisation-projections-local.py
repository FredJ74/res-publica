#!/usr/bin/env python3
"""Projections sur les DDL archives, PostgreSQL jetable. Aucun DSN distant accepte.
Ne certifie ni le catalogue vivant, ni PostgREST, ni les triggers/RLS de production.
"""
import argparse
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DOMAINE = ROOT / 'baseline/domaines/personnage-et-presence'
UID = '11111111-1111-1111-1111-111111111111'

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--local-jetable', required=True, action='store_true')
    args = p.parse_args()
    import pgserver
    import psycopg2
    serveur = pgserver.get_server(tempfile.mkdtemp(prefix='hg-projections-'), cleanup_mode='delete')
    db = psycopg2.connect(serveur.get_uri())
    try:
        q = db.cursor()
        q.execute("CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT '" + UID + "'::uuid $$; CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;")
        ddl = (DOMAINE / '10_tables.sql').read_text()
        for nom in ['personnages_donnees', 'presences', 'invitations_diner']:
            debut = ddl.index('CREATE TABLE public.' + nom + ' (')
            q.execute(ddl[debut:ddl.index('\n);', debut) + 3])
        contraintes = (DOMAINE / '30_contraintes.sql').read_text()
        for ligne in contraintes.splitlines():
            if ('presences_pkey PRIMARY KEY' in ligne or 'invitations_diner_pkey PRIMARY KEY' in ligne):
                q.execute(ligne)
        vues = (DOMAINE / '40_vues.sql').read_text()
        debut = vues.index('CREATE OR REPLACE VIEW public.personnages AS')
        q.execute(vues[debut:vues.index(';', debut) + 1])
        q.execute("INSERT INTO personnages_donnees(name,country,user_id,poste,photo_url,arg,liquide) VALUES ('Fixture','republic',%s,'{\"id\":\"maire\"}','portrait',10,0)", (UID,))
        q.execute('SELECT name,poste FROM personnages WHERE poste IS NOT NULL')
        assert q.fetchall() == [('Fixture', {'id': 'maire'})]
        print('OK projection des titulaires sur la vue archivee')
        q.execute('SELECT name,photo_url FROM personnages WHERE name IN (%s)', ('Fixture',))
        assert q.fetchall() == [('Fixture', 'portrait')]
        print('OK projection et filtre des portraits')
        q.execute("UPDATE personnages SET updated_at=now() WHERE name='Fixture' RETURNING name,updated_at")
        assert len(q.description) == 2 and q.fetchone()[0] == 'Fixture'
        q.execute("SELECT arg,liquide,inventory FROM personnages_donnees WHERE name='Fixture'")
        assert q.fetchone() == (10, 0, [])
        print('OK metadonnees RETURNING de la vue sans modification financiere/inventaire')
        q.execute("INSERT INTO presences(name,country,building_id,room_id,groupe_pnj) VALUES ('Fixture','republic','mairie','accueil','[{\"nom\":\"Agent\",\"photoUrl\":\"portrait\"}]') ON CONFLICT(name) DO UPDATE SET room_id=EXCLUDED.room_id RETURNING name")
        assert q.fetchone() == ('Fixture',) and len(q.description) == 1
        q.execute("SELECT groupe_pnj FROM presences WHERE name='Fixture'")
        assert q.fetchone()[0][0]['photoUrl'] == 'portrait'
        print('OK presence : reponse reduite et groupe conserve')
        q.execute("INSERT INTO invitations_diner(inviteur,invite,country,city,building_id,room_id,statut,tournee_id) SELECT 'Emetteur','Fixture','republic','capitale','bar','bar',CASE WHEN n>1100 THEN 'acceptee' ELSE 'attente' END,CASE WHEN n>1100 THEN 't' ELSE NULL END FROM generate_series(1,1200) n")
        base = "FROM invitations_diner WHERE invite='Fixture' AND (statut='attente' OR (tournee_id IS NOT NULL AND statut='acceptee'))"
        dernier = None
        resultat = []
        while True:
            q.execute('SELECT id,tournee_id,statut ' + base + (' AND id>%s' if dernier is not None else '') + ' ORDER BY id ASC LIMIT 100', (() if dernier is None else (dernier,)))
            rows = q.fetchall()
            resultat.extend(rows)
            if not rows or len(rows) < 100:
                break
            dernier = rows[-1][0]
        assert len(resultat) == 1200
        q.execute("SELECT id FROM invitations_diner WHERE invite='Fixture' AND statut='attente' AND tournee_id IS NULL ORDER BY id")
        assert [r[0] for r in resultat if r[1] is None and r[2] == 'attente'] == [r[0] for r in q.fetchall()]
        q.execute("SELECT id FROM invitations_diner WHERE invite='Fixture' AND statut IN ('attente','acceptee') AND tournee_id IS NOT NULL ORDER BY id")
        assert [r[0] for r in resultat if r[1] is not None] == [r[0] for r in q.fetchall()]
        print('OK union paginee : 1200 invitations, equivalence exacte des deux anciens filtres')
        print('5/5 scenarios PostgreSQL locaux ; aucune verification distante')
    finally:
        db.rollback()
        db.close()

if __name__ == '__main__':
    main()
