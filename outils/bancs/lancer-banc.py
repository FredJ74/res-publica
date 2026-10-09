#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lance un banc JavaScript sous JavaScriptCore, avec les sources du jeu chargees.

POURQUOI CE LANCEUR EXISTE. Cette machine n'a ni Node, ni npx, ni conteneur : le seul moteur
JavaScript disponible est JavaScriptCore (jsc). Eprouver une fonction de supabase.js ou de
api/ demande donc trois choses que jsc ne fournit pas seul :

  1. les MODULES ES de api/ portent `import`/`export`, que `jsc <fichier>` refuse en forme
     script : il faut les transformer -- en PRESERVANT le nombre de lignes, sinon les numeros
     de ligne des erreurs mentent ;
  2. le navigateur et Node fournissent `fetch`, `console`, `process` : le banc les pose
     lui-meme, ce qui est precisement ce qui permet de simuler une panne reseau ou un 500 ;
  3. le verdict doit remonter dans le CODE DE SORTIE. jsc rend 0 meme quand une exception est
     levee dans une promesse -- et tout banc asynchrone est dans ce cas. Verifie le 9 octobre
     2026 : deux regressions injectees affichaient « ECHEC » et le processus rendait 0.

Usage :
    python3 outils/bancs/lancer-banc.py <banc.js> [source1.js source2.js ...]

Les sources sont concatenees AVANT le banc, dans l'ordre donne. Code de sortie 0 si le banc
annonce son verdict vert, 1 dans tous les autres cas -- y compris s'il n'annonce rien.

LE BANC DECLARE SES PROPRES INGREDIENTS. Quand aucune source n'est donnee sur la ligne de
commande, le lanceur lit dans les 20 premieres lignes du banc une ligne de la forme

    SOURCES: supabase.js
    SOURCES: api/_supabase.js api/autre.js     (plusieurs, separees par des espaces)
    SOURCES: aucune                            (le banc lit lui-meme ses fichiers)

Pourquoi la declaration vit DANS le banc et pas dans un script d'appel par banc : le 9 octobre
2026, trois des quatre bancs n'avaient aucune enveloppe, et rien dans le depot ne disait de
quelle source ils avaient besoin. Lances sans source, ils affichaient leur titre et s'arretaient
-- jsc rend 0 quand une exception meurt dans une promesse. Le lanceur refusait bien de les
declarer verts, mais personne ne pouvait deviner comment les relancer. Un banc qu'on ne sait
plus invoquer est un banc mort.

Un banc SANS ligne SOURCES et sans source sur la ligne de commande est REFUSE : mieux vaut
echouer en nommant ce qui manque que tourner a vide.
"""

import os
import re
import subprocess
import sys
import tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"

# Ce que le navigateur ou Node donnent, et que jsc ne donne pas. `process.env` est VIDE a
# dessein : les modules de api/ exercent ainsi leurs replis, dont l'absence de cle service.
PREAMBULE = """
var process = { env: {} };
var console = {
  error: function () {}, warn: function () {}, log: function () {}, info: function () {}
};
var window = undefined;
"""


def forme_script(src):
    """Retire les mots-cles de module en PRESERVANT le nombre de lignes."""
    if not re.search(r"^\s*(import|export)\s", src, flags=re.M):
        return src                      # script navigateur : rien a transformer
    def vider(m):
        return "\n" * m.group(0).count("\n")
    out = re.sub(r"^import\s+[^;]*?;", vider, src, flags=re.M | re.S)
    out = re.sub(r"^export\s+default\s+", "var __default_export = ", out, flags=re.M)
    out = re.sub(r"^export\s+(const|let|var|function|async\s+function|class)\s",
                 r"\1 ", out, flags=re.M)
    out = re.sub(r"^export\s*\{[^}]*?\}\s*(from\s*['\"][^'\"]*['\"])?\s*;?", vider,
                 out, flags=re.M | re.S)
    reste = re.findall(r"^\s*(?:import|export)\b.*$", out, flags=re.M)
    if reste:
        raise SystemExit("lancer-banc : mot-cle de module survivant : %r" % reste[:3])
    if len(out.split("\n")) != len(src.split("\n")):
        raise SystemExit("lancer-banc : le nombre de lignes a change ; les numeros de ligne "
                         "des erreurs seraient faux")
    return out


def sources_declarees(chemin_banc):
    """Lit la ligne « SOURCES: ... » que le banc porte en tete. Rend None si absente."""
    with open(chemin_banc, encoding="utf-8") as fh:
        for _ in range(20):
            ligne = fh.readline()
            if not ligne:
                break
            m = re.search(r"SOURCES:\s*(.+?)\s*$", ligne)
            if m:
                # Tout ce qui suit « -- » est un commentaire pour l'humain, pas un chemin.
                valeur = m.group(1).split("--")[0].strip()
                return [] if valeur == "aucune" else valeur.split()
    return None


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    if not os.path.exists(JSC):
        raise SystemExit("lancer-banc : JavaScriptCore introuvable a %s" % JSC)
    banc = sys.argv[1]
    chemin_banc = banc if os.path.isabs(banc) else os.path.join(RACINE, banc)
    sources = sys.argv[2:]
    if not sources:
        sources = sources_declarees(chemin_banc)
        if sources is None:
            raise SystemExit(
                "lancer-banc : %s ne declare aucune ligne « SOURCES: » et aucune source n'a ete "
                "donnee. Ajouter dans l'en-tete du banc « SOURCES: <fichiers> », ou « SOURCES: "
                "aucune » si le banc lit lui-meme ses fichiers." % banc)
    morceaux = [PREAMBULE]
    for s in sources:
        chemin = s if os.path.isabs(s) else os.path.join(RACINE, s)
        morceaux.append(forme_script(open(chemin, encoding="utf-8").read()))
    morceaux.append(open(banc if os.path.isabs(banc) else os.path.join(RACINE, banc),
                         encoding="utf-8").read())
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as fh:
        fh.write("\n".join(morceaux))
        tmp = fh.name
    try:
        p = subprocess.run([JSC, tmp], capture_output=True, text=True)
        sys.stdout.write(p.stdout)
        if p.stderr.strip():
            sys.stderr.write(p.stderr)
        if p.returncode != 0:
            return p.returncode
        # LE VERDICT EST UNE LIGNE, PAS UN MOT QUI TRAINE. La version precedente cherchait
        # « ECHEC » n'importe ou dans la sortie : le libelle de cas « la panne est un ECHEC »
        # du banc du transport REST suffisait a declarer rouge un banc dont les 24 cas
        # passaient. Un banc a le droit de PARLER d'un echec sans en etre un.
        vert = re.compile(r"^LES \d+ EPREUVES SONT VERTES\.$")
        verdicts = [l.strip() for l in p.stdout.split("\n")
                    if l.strip().startswith("ECHEC") or vert.match(l.strip())]
        if not verdicts:
            sys.stderr.write("lancer-banc : aucune ligne de verdict dans la sortie -- le banc n'a "
                             "pas tourne jusqu'au bout\n")
            return 1
        if any(v.startswith("ECHEC") for v in verdicts):
            return 1
        return 0
    finally:
        os.unlink(tmp)


if __name__ == "__main__":
    sys.exit(main())
