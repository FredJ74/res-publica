#!/usr/bin/env python3
"""Contrôle sans écriture : imprime des SELECT pour le connecteur ou lit leur export.

--sql-metadonnees : premier SELECT, noms de tables/colonnes seulement.
--metadonnees colonnes.json --requete N : SELECT N (50 tables), aucun nom de joueur.
--resultats images.json --rapport rapport.json : compare les chemins avec Git/Vercel.
Aucune connexion, clef, fonction métier, commande SQL mutante ou modification de fichier du jeu.
"""
import argparse
import json
import pathlib
import re
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[2]
METADONNEES = """SELECT c.table_name, jsonb_agg(c.column_name ORDER BY c.ordinal_position) AS columns
FROM information_schema.columns c JOIN information_schema.tables t USING(table_schema,table_name)
WHERE c.table_schema='public' AND t.table_type='BASE TABLE'
AND (c.data_type IN ('text','character varying','json','jsonb','ARRAY')
 OR c.column_name ~* '(image|photo|portrait|avatar|illustration)')
GROUP BY c.table_name ORDER BY c.table_name;"""
MOTIF = r'''([^[:space:]"'<>\\]+?\.(?:webp|png|jpe?g|gif|svg|avif|ico)(?:\?[^[:space:]"'<>\\]*)?)'''
# Une colonne image_path peut contenir seulement « dossier/fichier.webp »
# (stockage Supabase), et un avatar peut être une URL sans extension.
MOTIF_COLONNE_IMAGE = r'''(https?://[^[:space:]"'<>\\]+|[^[:space:]"'<>\\]+\.(?:webp|png|jpe?g|gif|svg|avif|ico)(?:\?[^[:space:]"'<>\\]*)?)'''
COLONNE_IMAGE = '(image|photo|portrait|avatar|vignette|visuel|chemin_original|chemin_archive)'


def identifiant(s):
    return '"' + s.replace('"', '""') + '"'


def valeur(s):
    return "'" + s.replace("'", "''") + "'"


def requete(tables):
    parties = []
    for table in tables:
        cols = ','.join('(' + valeur(c) + ',t.' + identifiant(c) + '::text)' for c in table['columns'])
        parties.append('SELECT ' + valeur(table['table_name']) + ' AS table_name, c.column_name, '
                       'm[1] AS image_path, count(*)::integer AS occurrences FROM public.'
                       + identifiant(table['table_name']) + ' AS t CROSS JOIN LATERAL (VALUES '
                       + cols + ') AS c(column_name,value) CROSS JOIN LATERAL regexp_matches(c.value,'
                       + 'CASE WHEN c.column_name ~* ' + valeur(COLONNE_IMAGE)
                       + ' THEN ' + valeur(MOTIF_COLONNE_IMAGE) + ' ELSE ' + valeur(MOTIF)
                       + " END,'gi') AS m GROUP BY c.column_name,m[1]")
    return '\nUNION ALL\n'.join(parties) + ';'


def controler(rows):
    config = json.loads((ROOT / 'vercel.json').read_text())
    aliases = {r['source']: r['destination'] for r in config.get('rewrites', [])}
    sorties = []
    for r in rows:
        url = r['image_path']
        u = urllib.parse.urlsplit(url)
        externe = bool(u.netloc and u.netloc not in ['human-gambit.com', 'www.human-gambit.com'])
        chemin = urllib.parse.unquote(u.path).lstrip('/')
        github = 'https://raw.githubusercontent.com/FredJ74/res-publica/main/'
        if url.startswith(github):
            chemin = url[len(github):].split('?')[0]
        elif externe:
            sorties.append({**r, 'statut': 'externe_a_verifier_http'})
            continue
        if not externe and not chemin.startswith('images/'):
            sorties.append({**r, 'statut': 'stockage_ou_chemin_relatif_a_resoudre'})
            continue
        alias = None if externe else aliases.get('/' + chemin)
        cible = alias.lstrip('/') if alias else chemin
        present = (ROOT / cible).is_file()
        sorties.append({**r, 'chemin': chemin, 'cible': cible, 'alias': alias,
                        'statut': 'presente' if present else 'absente',
                        'webp_existant': (ROOT / pathlib.Path(chemin).with_suffix('.webp')).is_file()})
    return {'colonnes_avec_images': len({(r['table_name'], r['column_name']) for r in rows}),
            'references_agregees': len(rows), 'occurrences': sum(r['occurrences'] for r in rows),
            'urls_distinctes': len({r['image_path'] for r in rows}),
            'references': sorties, 'lecture_seule': True}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--sql-metadonnees', action='store_true')
    p.add_argument('--metadonnees', type=pathlib.Path)
    p.add_argument('--requete', type=int)
    p.add_argument('--resultats', type=pathlib.Path)
    p.add_argument('--rapport', type=pathlib.Path)
    a = p.parse_args()
    if a.sql_metadonnees:
        print(METADONNEES)
    elif a.metadonnees is not None and a.requete is not None:
        tables = json.loads(a.metadonnees.read_text())
        lot = tables[a.requete * 50:(a.requete + 1) * 50]
        if not lot:
            p.error('lot absent')
        print(requete(lot))
    elif a.resultats:
        r = controler(json.loads(a.resultats.read_text()))
        if a.rapport:
            a.rapport.write_text(json.dumps(r, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({**{k: v for k, v in r.items() if k != 'references'},
                          'absentes': [x for x in r['references'] if x['statut'] == 'absente']}, ensure_ascii=False, indent=2))
    else:
        p.error('choisir une collecte SQL ou un export à contrôler')
