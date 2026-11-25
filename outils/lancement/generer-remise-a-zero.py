#!/usr/bin/env python3
"""Génère outils/lancement/remise-a-zero-20261219.sql (mission du soir du 25/11/2026, bloc 4.5).

Sources : baseline/classification-donnees.csv (A, B → garder ; C → vider ; D → réinitialiser ; hors_baseline → garder)
          outils/lancement/classement-complementaire-20261125.csv (tables nouvelles et corrections ; prioritaire).
Usage : python3 outils/lancement/generer-remise-a-zero.py [--verifier]   (--verifier : échoue si le fichier versionné diffère)
"""
import csv, sys, pathlib
R = pathlib.Path(__file__).resolve().parents[2]
base = {x['table']: x for x in csv.DictReader(open(R / 'baseline/classification-donnees.csv', encoding='utf8'), delimiter=';')}
comp = {x['table']: x['decision'] for x in csv.DictReader(open(R / 'outils/lancement/classement-complementaire-20261125.csv', encoding='utf8'), delimiter=';')}
dec = {}
for t, x in base.items():
    if x['strategie'] == 'hors_baseline': dec[t] = 'garder'
    else: dec[t] = {'A': 'garder', 'B': 'garder', 'C': 'vider', 'D': 'reinitialiser'}[x['categorie']]
dec.update(comp)
assert set(dec.values()) <= {'garder', 'vider', 'reinitialiser', 'a_verifier'}, set(dec.values())
listes = {k: sorted(t for t, v in dec.items() if v == k) for k in ('garder', 'vider', 'reinitialiser', 'a_verifier')}
arr = lambda l: 'ARRAY[' + ', '.join("'" + t + "'" for t in l) + ']::text[]'
modele = (R / 'outils/lancement/remise-a-zero.modele.sql').read_text(encoding='utf8')
# Réinitialisations (mission de fin de soirée du 25/11/2026, point 1.1) : une entrée « ▸ <table> : » par table à réinitialiser.
import re
reinit = (R / 'outils/lancement/reinitialisations.modele.sql').read_text(encoding='utf8')
marquees = set(re.findall(r'^-- ▸ ([a-z0-9_]+) :', reinit, re.M))
manquantes = sorted(set(listes['reinitialiser']) - marquees)
if manquantes: sys.exit('tables à réinitialiser sans entrée dans reinitialisations.modele.sql : ' + ', '.join(manquantes))
def seed_upsert(fichier, colonnes, cle, jsonb_col=None):
    out = []
    for ligne in (R / fichier).read_text(encoding='utf8').splitlines():
        if not ligne.startswith('INSERT INTO'): continue
        if jsonb_col:   # le seed écrit to_jsonb($x$…$x$::text) (colonne texte du baseline) ; la production est en jsonb
            ligne = re.sub(r"to_jsonb\((\$x\$.*?\$x\$)::text\)", r"\1::jsonb", ligne)
        out.append(ligne.rstrip(';') + ' ON CONFLICT (' + cle + ') DO UPDATE SET ' +
                   ', '.join(f'{c} = EXCLUDED.{c}' for c in colonnes) + ', updated_at = now();')
    if not out: sys.exit('seed vide : ' + fichier)
    return '\n'.join(out)
reinit = (reinit.replace('/*SEED_CAISSES*/', seed_upsert('baseline/seeds/92_mixte/caisses_batiments.sql', ['data'], 'id'))
               .replace('/*SEED_ENTREPOTS*/', seed_upsert('baseline/seeds/92_mixte/batiments_etat.sql', ['country', 'city', 'building_id', 'data'], 'id', 'data')))
modele = modele.replace('/*REINITIALISATIONS*/', reinit.rstrip('\n'))
sortie = (modele.replace('/*GARDER*/', arr(listes['garder'])).replace('/*VIDER*/', arr(listes['vider']))
          .replace('/*REINITIALISER*/', arr(listes['reinitialiser'])).replace('/*A_VERIFIER*/', arr(listes['a_verifier']))
          .replace('/*COMPTES*/', ' ; '.join(f'{k} {len(v)}' for k, v in listes.items())))
cible = R / 'outils/lancement/remise-a-zero-20261219.sql'
if '--verifier' in sys.argv:
    if cible.read_text(encoding='utf8') != sortie:
        sys.exit('remise-a-zero-20261219.sql n\'est pas à jour : relancer le générateur')
    print('à jour :', ' ; '.join(f'{k} {len(v)}' for k, v in listes.items()))
else:
    cible.write_text(sortie, encoding='utf8')
    print('écrit :', ' ; '.join(f'{k} {len(v)}' for k, v in listes.items()))
