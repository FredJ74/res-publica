#!/usr/bin/env python3
"""Ordres rattaches a chaque batiment de Republia, pour la garde serveur du blocus syndical.

Decision de Fred (02/11/2026, GAME-DESIGN-BLOCUS.md) : pendant un blocus, les ordres du batiment
sont inaccessibles. Le serveur ne connait pas data.js : il lit la table blocus_ordres_batiments,
remplie a partir du catalogue effectif (inventaire de l'audit global, piece par piece).

« Faire intervenir les forces de l'ordre » releve du commissaire, pas du batiment : exclu.

Usage : python3 outils/generateurs/generer_blocus_ordres_batiments.py [inventaire.json]
Imprime le bloc INSERT a coller dans une migration (idempotent, ON CONFLICT DO NOTHING).
"""
import json
import sys

HORS_BATIMENT = {'mobiliser_police'}


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else 'outils/audits/AUDIT-GLOBAL-REPUBLIA-20261102.json'
    d = json.load(open(source, encoding='utf-8'))
    lignes = sorted({(o['ville'], o['batiment'], o['fn']) for o in d['ordres']
                     if o.get('fn') and o['fn'] not in HORS_BATIMENT})
    q = lambda s: "'" + s.replace("'", "''") + "'"
    print('-- Source : %s (commit %s), %d ordres.' % (source, d.get('source_git', '?'), len(lignes)))
    par_batiment = {}
    for v, b, f in lignes:
        par_batiment.setdefault((v, b), []).append(f)
    print('INSERT INTO public.blocus_ordres_batiments (pays, ville, batiment, fn)')
    print("SELECT 'republic', x.v, x.b, unnest(string_to_array(x.f, ' ')) FROM (VALUES")
    print(',\n'.join("(%s,%s,%s)" % (q(v), q(b), q(' '.join(fs))) for (v, b), fs in sorted(par_batiment.items())))
    print(') AS x(v, b, f)')
    print('ON CONFLICT DO NOTHING;')


if __name__ == '__main__':
    main()
