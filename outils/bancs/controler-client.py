#!/usr/bin/env python3
"""Tous les bancs JS/Node, sans SQL ni acces de production.

Usage : python3 outils/bancs/controler-client.py [--rapport /tmp/resultats]
Python 3 et Node sont requis ; JavaScriptCore est utilise s'il est present.
Les bancs historiques conservent le lanceur et son controle de verdict.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

RACINE = Path(__file__).resolve().parents[2]
ICI = Path(__file__).resolve().parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rapport', type=Path)
    args = parser.parse_args()
    node = shutil.which('node')
    if not node:
        parser.error('Node est requis pour les bancs natifs et les modules partages.')
    if args.rapport:
        args.rapport.mkdir(parents=True, exist_ok=True)
    bancs = sorted(p for p in ICI.glob('banc-*') if p.suffix in ('.js', '.cjs', '.mjs'))
    if not bancs:
        parser.error('Aucun banc : aucun succes ne peut etre annonce.')
    resultats = []
    for banc in bancs:
        tete = '\n'.join(banc.read_text().splitlines()[:20])
        historique = banc.suffix == '.js' and 'SOURCES:' in tete
        commande = ([sys.executable, str(ICI / 'lancer-banc.py'), str(banc)] if historique
                    else [node, '--experimental-vm-modules', '--test', str(banc)])
        debut = time.monotonic()
        try:
            proc = subprocess.run(commande, cwd=RACINE, text=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, timeout=120)
            code, sortie = proc.returncode, proc.stdout
        except subprocess.TimeoutExpired:
            code, sortie = 124, 'Delai de 120 secondes depasse : banc non valide.\n'
        entree = {'banc':banc.name, 'code':code,
                  'moteur':'lanceur historique' if historique else 'Node natif',
                  'secondes':round(time.monotonic()-debut, 3)}
        resultats.append(entree)
        print(('OK  ' if code == 0 else 'NON ') + banc.name, flush=True)
        if args.rapport:
            (args.rapport / (banc.name + '.log')).write_text(sortie)
        if code:
            print(sortie[-5000:])
    if args.rapport:
        (args.rapport / 'resultats.json').write_text(json.dumps(resultats, indent=2) + '\n')
    echecs = sum(r['code'] != 0 for r in resultats)
    print(f'{len(bancs)-echecs}/{len(bancs)} bancs reussis ; {echecs} echec(s). Aucun SQL execute.')
    return 1 if echecs else 0

if __name__ == '__main__':
    sys.exit(main())
