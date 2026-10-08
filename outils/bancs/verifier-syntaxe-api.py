#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verifie la syntaxe des modules ES de api/ avec l'analyseur de JavaScriptCore.

POURQUOI CE N'EST PAS DIRECT. api/*.js sont des MODULES ES : ils portent `import` et
`export`, que `checkSyntax` de jsc refuse en forme script. Il faut donc transformer chaque
fichier en forme script AVANT de l'analyser -- et c'est la que les transformations naives
echouent : un `export default async function handler` ou un `import { a,\n  b } from '...'`
sur plusieurs lignes ne se retire pas avec une expression reguliere ligne a ligne.

CE QU'IL GARANTIT SUR SA PROPRE TRANSFORMATION. Il verifie qu'aucun mot-cle de module ne
survit, et que le nombre de lignes est PRESERVE -- un import multi-lignes remplace par une
seule ligne decalerait tous les numeros de ligne, et une erreur signalee ligne 240 ne serait
pas a la ligne 240 du vrai fichier. Sans cette garantie, le diagnostic ment.

Usage :
    python3 outils/bancs/verifier-syntaxe-api.py              # tous les api/*.js
    python3 outils/bancs/verifier-syntaxe-api.py api/chat.js  # un seul
Code de sortie 0 si tout passe.
"""

import glob
import os
import re
import subprocess
import sys
import tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"


def forme_script(src):
    """Retire les mots-cles de module EN PRESERVANT le nombre de lignes."""
    out = src
    # import ... ; sur une ou plusieurs lignes -> autant de lignes vides
    def vider(m):
        return "\n" * m.group(0).count("\n")
    out = re.sub(r"^import\s+[^;]*?;", vider, out, flags=re.M | re.S)
    # export default <expr> -> var __default = <expr>
    out = re.sub(r"^export\s+default\s+", "var __default_export = ", out, flags=re.M)
    # export const/let/var/function/async function/class -> la declaration nue
    out = re.sub(r"^export\s+(const|let|var|function|async\s+function|class)\s",
                 r"\1 ", out, flags=re.M)
    # export { ... } ; sur une ou plusieurs lignes
    out = re.sub(r"^export\s*\{[^}]*?\}\s*(from\s*['\"][^'\"]*['\"])?\s*;?", vider,
                 out, flags=re.M | re.S)
    reste = re.findall(r"^\s*(?:import|export)\b.*$", out, flags=re.M)
    if reste:
        raise SystemExit("verifier-syntaxe-api : mot-cle de module survivant : %r" % reste[:3])
    if len(out.split("\n")) != len(src.split("\n")):
        raise SystemExit("verifier-syntaxe-api : le nombre de lignes a change (%d -> %d) ; "
                         "les numeros de ligne des erreurs seraient faux"
                         % (len(src.split("\n")), len(out.split("\n"))))
    return out


def verifier(chemin):
    src = open(chemin, encoding="utf-8").read()
    script = forme_script(src)
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as fh:
        fh.write(script)
        tmp = fh.name
    try:
        p = subprocess.run(
            [JSC, "-e",
             "try { checkSyntax(arguments[0]); print('OK'); } "
             "catch (e) { print('ECHEC ' + e); }",
             "--", tmp],
            capture_output=True, text=True)
        sortie = (p.stdout or "").strip()
        return sortie.startswith("OK"), sortie
    finally:
        os.unlink(tmp)


def main():
    if not os.path.exists(JSC):
        raise SystemExit("verifier-syntaxe-api : JavaScriptCore introuvable")
    cibles = sys.argv[1:] or sorted(glob.glob(os.path.join(RACINE, "api", "*.js")))
    pbs = 0
    print("SYNTAXE DES MODULES api/ -- analyseur de JavaScriptCore")
    print("=" * 70)
    for c in cibles:
        ok, sortie = verifier(c)
        if not ok:
            pbs += 1
        print("  %-4s %-36s %s" % ("OK" if ok else "NON", os.path.basename(c),
                                   "" if ok else sortie[:90]))
    print("=" * 70)
    if pbs:
        print("ECHEC : %d module(s) sur %d" % (pbs, len(cibles)))
        return 1
    print("LES %d MODULES PASSENT L'ANALYSEUR." % len(cibles))
    return 0


if __name__ == "__main__":
    sys.exit(main())
