#!/usr/bin/env python3
"""Tous les bancs JS/Node, sans SQL ni acces de production.

Usage : python3 outils/bancs/controler-client.py [--rapport /tmp/resultats] [--part K/N] [--modifies-depuis REF]
  --part K/N           : ne joue que la part K (1..N) des bancs, répartis par durée estimée (CI en parallèle, 24/11/2026).
  --modifies-depuis REF : ne joue que les bancs liés aux fichiers modifiés depuis REF (poussée) ; la suite complète
                         tourne chaque nuit. Un changement du lanceur lui-même rejoue tout.
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


# Fichiers dont la modification impose la suite complète (lanceur, aides communes, environnement des bancs).
TOUT_REJOUER = ('outils/bancs/controler-client.py', 'outils/bancs/lancer-banc.py', 'outils/bancs/shell-node.cjs',
                'outils/bancs/mobile-navigateur.cjs', '.github/workflows/coherence-client.yml',
                'outils/e2e/package.json', 'outils/e2e/package-lock.json')


def poids(banc):
    """Durée estimée (s) pour équilibrer les parts : les bancs Chromium sont les plus longs."""
    nom = banc.name
    if 'navigateur' in nom or 'chromium' in nom or 'browser' in nom:
        return 30
    return 4


def repartir(bancs, k, n):
    """Répartition gloutonne (plus longs d'abord) : chaque banc va dans exactement une part, stable d'une exécution à l'autre."""
    parts = [[0, []] for _ in range(n)]
    for banc in sorted(bancs, key=lambda b: (-poids(b), b.name)):
        cible = min(range(n), key=lambda i: (parts[i][0], i))
        parts[cible][0] += poids(banc)
        parts[cible][1].append(banc)
    return sorted(parts[k - 1][1])


def fichiers_modifies(ref):
    """Fichiers modifiés depuis ref ; None si la référence est inutilisable (on joue alors tout)."""
    def git(*a):
        return subprocess.run(['git', *a], cwd=RACINE, capture_output=True, text=True)
    if not ref or set(ref) == {'0'} or git('cat-file', '-e', ref + '^{commit}').returncode:
        base = git('merge-base', 'HEAD', 'origin/main')
        if base.returncode:
            return None
        ref = base.stdout.strip()
    diff = git('diff', '--name-only', ref, 'HEAD')
    if diff.returncode:
        return None
    return [l for l in diff.stdout.splitlines() if l.strip()]


def bancs_lies(bancs, modifies):
    """Un banc est lié s'il a changé, ou si son texte cite un fichier modifié (nom de fichier ou chemin)."""
    if modifies is None or any(m in TOUT_REJOUER for m in modifies):
        return bancs
    noms = {os.path.basename(m) for m in modifies if not m.endswith('.md')}
    choisis = []
    for banc in bancs:
        rel = banc.relative_to(RACINE).as_posix()
        if rel in modifies:
            choisis.append(banc)
            continue
        texte = banc.read_text(errors='replace')
        if any(nom and nom in texte for nom in noms):
            choisis.append(banc)
    return choisis


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rapport', type=Path)
    parser.add_argument('--part', default='1/1')
    parser.add_argument('--modifies-depuis', dest='modifies_depuis')
    args = parser.parse_args()
    try:
        k, n = (int(x) for x in args.part.split('/'))
        assert 1 <= k <= n
    except (ValueError, AssertionError):
        parser.error('--part attend K/N avec 1 <= K <= N')
    node = shutil.which('node')
    if not node:
        parser.error('Node est requis pour les bancs natifs et les modules partages.')
    if args.rapport:
        args.rapport.mkdir(parents=True, exist_ok=True)
    bancs = sorted(p for p in ICI.glob('banc-*') if p.suffix in ('.js', '.cjs', '.mjs'))
    if not bancs:
        parser.error('Aucun banc : aucun succes ne peut etre annonce.')
    if args.modifies_depuis is not None:
        modifies = fichiers_modifies(args.modifies_depuis)
        bancs = bancs_lies(bancs, modifies)
        print(f'Poussée : {len(bancs)} banc(s) liés aux fichiers modifiés'
              + ('' if modifies is not None else ' (référence inutilisable : suite complète)') + '.', flush=True)
    bancs = repartir(bancs, k, n)
    print(f'Part {k}/{n} : {len(bancs)} banc(s).', flush=True)
    if not bancs:
        if args.rapport:
            ecrire_json(args.rapport / 'execution.json', {'etat': 'terminee', 'bancs_prevus': 0, 'bancs_termines': 0, 'echecs': 0})
        print('Aucun banc lié dans cette part : rien à jouer.')
        return 0
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
            # Les bancs Chromium (« navigateur ») balaient neuf langues et plusieurs largeurs : 120 s ne suffisent plus.
            code, sortie = executer_banc(commande, cwd=RACINE, delai=300 if 'navigateur' in banc.name else 120)
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
                # Annotation GitHub (lisible sans accès aux journaux) : le nom du banc et sa dernière ligne d'erreur.
                if os.environ.get('GITHUB_ACTIONS') == 'true':
                    lignes = [l for l in sortie.splitlines() if l.strip()]
                    derniere = next((l for l in reversed(lignes) if 'Error' in l or 'ECHEC' in l or 'not ok' in l or '✖' in l), lignes[-1] if lignes else '')
                    print('::error title=' + banc.name + '::' + derniere.strip()[:300].replace('\n', ' '), flush=True)
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
