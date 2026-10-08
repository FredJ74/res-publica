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


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    if not os.path.exists(JSC):
        raise SystemExit("lancer-banc : JavaScriptCore introuvable a %s" % JSC)
    banc = sys.argv[1]
    sources = sys.argv[2:]
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
        if "ECHEC" in p.stdout:
            return 1
        if "EPREUVES SONT VERTES" not in p.stdout:
            sys.stderr.write("lancer-banc : aucun verdict dans la sortie -- le banc n'a pas tourne\n")
            return 1
        return 0
    finally:
        os.unlink(tmp)


if __name__ == "__main__":
    sys.exit(main())
