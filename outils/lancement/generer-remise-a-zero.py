#!/usr/bin/env python3
"""Génère historique/preparations-lancement/remise-a-zero-20261219.sql (mission du soir du 25/11/2026, bloc 4.5).

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
modele = (R / 'historique/preparations-lancement/remise-a-zero.modele.sql').read_text(encoding='utf8')
sortie = (modele.replace('/*GARDER*/', arr(listes['garder'])).replace('/*VIDER*/', arr(listes['vider']))
          .replace('/*REINITIALISER*/', arr(listes['reinitialiser'])).replace('/*A_VERIFIER*/', arr(listes['a_verifier']))
          .replace('/*COMPTES*/', ' ; '.join(f'{k} {len(v)}' for k, v in listes.items())))
cible = R / 'historique/preparations-lancement/remise-a-zero-20261219.sql'
if '--verifier' in sys.argv:
    if cible.read_text(encoding='utf8') != sortie:
        sys.exit('remise-a-zero-20261219.sql n\'est pas à jour : relancer le générateur')
    print('à jour :', ' ; '.join(f'{k} {len(v)}' for k, v in listes.items()))
else:
    cible.write_text(sortie, encoding='utf8')
    print('écrit :', ' ; '.join(f'{k} {len(v)}' for k, v in listes.items()))
