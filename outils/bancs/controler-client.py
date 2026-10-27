#!/usr/bin/env python3
"""Tous les bancs JS/Node, sans SQL ni acces de production.

Usage : python3 outils/bancs/controler-client.py [--rapport /tmp/resultats]
Python 3 et Node sont requis ; JavaScriptCore est utilise s'il est present.
Les bancs historiques conservent le lanceur et son controle de verdict.
"""
import argparse
import json
import os
import signal
import tempfile
from pathlib import Path
import shutil
import subprocess
import sys
import time

RACINE = Path(__file__).resolve().parents[2]
ICI = Path(__file__).resolve().parent

def executer_banc(commande, *, cwd, delai=120, delai_arret=1):
    """Borne le banc et son groupe de processus, en conservant les diagnostics.

    Un fichier évite qu'un descendant gardant stdout ouvert bloque la collecte.
    Le groupe est privé au banc : aucun autre test/session n'est signalé.
    """
    with tempfile.TemporaryFile() as journal:
        try:
            proc = subprocess.Popen(commande, cwd=cwd, stdout=journal,
                                    stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as exc:
            return 125, f'Lancement impossible : {exc}\n'

        def arreter():
            def envoyer(sig):
                try:
                    if os.name == 'posix':
                        os.killpg(proc.pid, sig)
                    elif proc.poll() is None:
                        proc.kill()
                except ProcessLookupError:
                    pass
            envoyer(signal.SIGTERM)
            try:
                proc.wait(timeout=delai_arret)
            except subprocess.TimeoutExpired:
                pass
            finally:
                # Le parent peut déjà être sorti alors qu'un enfant ignore TERM.
                envoyer(signal.SIGKILL)
            proc.wait(timeout=delai_arret)

        note = ''
        try:
            code = proc.wait(timeout=delai)
        except subprocess.TimeoutExpired:
            arreter()
            code = 124
            note = f'\nDelai de {delai:g} secondes depasse : banc non valide (groupe arrete).\n'
        except BaseException:
            arreter()
            raise
        journal.seek(0)
        return code, journal.read().decode('utf-8', errors='replace') + note


def ecrire_json(chemin, valeur):
    # Un arrêt de runner ne doit pas laisser un JSON tronqué présenté comme complet.
    temporaire = chemin.with_suffix(chemin.suffix + '.tmp')
    temporaire.write_text(json.dumps(valeur, indent=2) + '\n')
    temporaire.replace(chemin)


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
    def bilan(etat):
        if args.rapport:
            ecrire_json(args.rapport / 'resultats.json', resultats)
            ecrire_json(args.rapport / 'execution.json', {
                'etat': etat, 'bancs_prevus': len(bancs),
                'bancs_termines': len(resultats),
                'echecs': sum(r['code'] != 0 for r in resultats)})
    bilan('en_cours')
    try:
        for banc in bancs:
            tete = '\n'.join(banc.read_text().splitlines()[:20])
            historique = banc.suffix == '.js' and 'SOURCES:' in tete
            commande = ([sys.executable, str(ICI / 'lancer-banc.py'), str(banc)] if historique
                        else [node, '--experimental-vm-modules', '--test', str(banc)])
            debut = time.monotonic()
            code, sortie = executer_banc(commande, cwd=RACINE)
            entree = {'banc':banc.name, 'code':code,
                      'moteur':'lanceur historique' if historique else 'Node natif',
                      'secondes':round(time.monotonic()-debut, 3)}
            resultats.append(entree)
            print(('OK  ' if code == 0 else 'NON ') + banc.name, flush=True)
            if args.rapport:
                (args.rapport / (banc.name + '.log')).write_text(sortie)
            bilan('en_cours')
            if code:
                print(sortie[-5000:])
    finally:
        bilan('terminee' if len(resultats) == len(bancs) else 'interrompue')
    echecs = sum(r['code'] != 0 for r in resultats)
    print(f'{len(bancs)-echecs}/{len(bancs)} bancs reussis ; {echecs} echec(s). Aucun SQL execute.')
    return 1 if echecs else 0

def interrompre(signum, _frame):
    # Actions annule d'abord avec INT, puis TERM : les deux passent par finally.
    raise SystemExit(128 + signum)


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, interrompre)
    sys.exit(main())
