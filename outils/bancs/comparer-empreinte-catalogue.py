"""Compare l'empreinte d'un catalogue LOCAL à celle de la production (31/10/2026, #219).

Entrée : la sortie JSON de outils/bancs/empreinte-catalogue-racine.sql jouée sur le catalogue
reconstruit (fichier contenant l'objet {"registre", "categories", ...} ou {"empreinte": {...}}).
Référence : outils/audits/catalogue-1012/EMPREINTE-PRODUCTION-1012.json (relevée en production).

Sortie : CONFORME si toutes les racines concordent (même nombre d'objets et même empreinte
pour fonctions, relations, politiques, déclencheurs, contraintes, index) ; sinon la liste des
seaux discordants et la clause « cible » prête à coller dans empreinte-catalogue-detail.sql,
à jouer des deux côtés pour nommer l'objet qui diffère.
Usage : python3 outils/bancs/comparer-empreinte-catalogue.py <empreinte_locale.json> [--reference <json>]
Aucune base n'est contactée.
"""
import argparse, json, sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
REFERENCE = RACINE / 'outils/audits/catalogue-1012/EMPREINTE-PRODUCTION-1012.json'


def lire(chemin):
    d = json.loads(Path(chemin).read_text())
    if isinstance(d, list) and d and isinstance(d[0], dict):  # sortie brute d'execute_sql
        d = d[0]
    return d.get('empreinte', d)


def comparer(locale, reference):
    ecarts, cibles = [], []
    for cat, ref in sorted(reference['categories'].items()):
        loc = locale.get('categories', {}).get(cat)
        if loc is None:
            ecarts.append('%s : catégorie absente du catalogue local' % cat); continue
        if loc['racine'] == ref['racine'] and int(loc['objets']) == int(ref['objets']):
            continue
        ecarts.append('%s : %s objets en local, %s en production' % (cat, loc['objets'], ref['objets']))
        for seau in sorted(set(ref['seaux']) | set(loc['seaux'])):
            if ref['seaux'].get(seau) != loc['seaux'].get(seau):
                ecarts.append('  seau %s : local %s / production %s' % (seau, loc['seaux'].get(seau), ref['seaux'].get(seau)))
                cibles.append("('%s', '%s')" % (cat, seau))
    return ecarts, cibles


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('locale'); p.add_argument('--reference', default=str(REFERENCE))
    a = p.parse_args()
    reference, locale = lire(a.reference), lire(a.locale)
    print('Production : registre %s (%s), serveur %s' % (reference['registre']['lignes'], reference['registre']['derniere'], reference.get('version_serveur')))
    print('Local      : registre %s (%s), serveur %s' % (locale.get('registre', {}).get('lignes'), locale.get('registre', {}).get('derniere'), locale.get('version_serveur')))
    ecarts, cibles = comparer(locale, reference)
    if not ecarts:
        print('CONFORME : les six familles concordent objet par objet (définitions complètes normalisées).')
        return 0
    print('NON CONFORME :'); print('\n'.join('  ' + e for e in ecarts))
    print('\nClause à coller dans empreinte-catalogue-detail.sql (des deux côtés) :')
    print('cible(cat, seau) AS (VALUES ' + ', '.join(cibles) + '),')
    return 1


if __name__ == '__main__':
    sys.exit(main())
