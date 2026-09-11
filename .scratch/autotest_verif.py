#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Auto-test du verificateur d'equilibrage.

Un verificateur qui ne signale jamais rien est indiscernable d'un verificateur casse. Ce script
lui soumet des cas CASSES (il doit les rejeter) et des cas SAINS mais pieges (il doit les
accepter), et verifie qu'il repond correctement dans les deux sens.

Les cas sains reproduisent volontairement les constructions reelles du depot qui avaient fait
echouer la premiere version : gabarits imbriques, apostrophes francaises dans un gabarit,
regex, division, commentaires contenant des accolades.
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verif_syntaxe_js import verifier   # noqa: E402


CASSES = [
    ("accolade jamais fermee",        "function a() {\n  if (x) {\n    return 1;\n}\n"),
    ("parenthese en trop",            "const a = foo());\n"),
    ("crochet ferme par accolade",    "const a = [1, 2};\n"),
    ("chaine simple non fermee",      "const a = 'bonjour;\nconst b = 2;\n"),
    ("chaine double non fermee",      'const a = "bonjour;\nconst b = 2;\n'),
    ("gabarit non ferme",             "const a = `bonjour ${x} et la suite;\n"),
    ("interpolation non fermee",      "const a = `debut ${ (1 + 2 } fin`;\n"),
    ("accolade surnumeraire",         "function a() { return 1; }}\n"),
]

SAINS = [
    ("gabarit imbrique + apostrophes",
     "const p = `Ligne un.\n"
     "${cond ? `texte avec d'une apostrophe et d'annees` : ''}\n"
     "${autre ? `encore ${profond ? `troisieme niveau d'imbrication` : ''}` : ''}\n"
     "fin`;\n"),
    ("apostrophes francaises en chaine",
     "const a = 'aujourd\\'hui';\nconst b = \"l'Assemblee\";\n"),
    ("regex avec accolades et slash",
     "const re = /^[a-z]{2,3}\\/(x|y)$/g;\nconst d = 10 / 2;\n"),
    ("division apres parenthese",
     "const r = (a + b) / 2;\nconst s = arr[0] / 3;\n"),
    ("commentaires contenant des delimiteurs",
     "// une { accolade et une ( parenthese\n/* et un bloc } ] ) */\nfunction f() { return 1; }\n"),
    ("objet, tableau, fonction flechee",
     "const o = { a: [1, 2, {b: 3}], f: (x) => ({ y: x }) };\n"),
    ("gabarit contenant accolade litterale",
     "const t = `un objet: { pas une interpolation }`;\n"),
    ("chaine contenant des delimiteurs",
     "const s = 'un ( non ferme et un } orphelin';\n"),
]


def ecrire_temp(contenu):
    fd, chemin = tempfile.mkstemp(suffix='.js')
    with os.fdopen(fd, 'w', encoding='utf-8') as fh:
        fh.write(contenu)
    return chemin


def main():
    echecs = 0

    print("=== CAS CASSES (le verificateur DOIT les rejeter) ===")
    for nom, src in CASSES:
        chemin = ecrire_temp(src)
        try:
            ok, msg = verifier(chemin)
        finally:
            os.unlink(chemin)
        correct = (ok is False)
        if not correct:
            echecs += 1
        print("%s %-38s %s" % ("OK  " if correct else "RATE", nom,
                               msg if not ok else "!! accepte a tort !!"))

    print("")
    print("=== CAS SAINS (le verificateur DOIT les accepter) ===")
    for nom, src in SAINS:
        chemin = ecrire_temp(src)
        try:
            ok, msg = verifier(chemin)
        finally:
            os.unlink(chemin)
        correct = (ok is True)
        if not correct:
            echecs += 1
        print("%s %-38s %s" % ("OK  " if correct else "RATE", nom,
                               "" if ok else "!! rejete a tort : " + msg))

    print("")
    total = len(CASSES) + len(SAINS)
    print("%d cas testes, %d reponse(s) incorrecte(s)" % (total, echecs))
    return 1 if echecs else 0


if __name__ == '__main__':
    sys.exit(main())
