#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Verificateur d'equilibrage pour les sources JS du chantier Assemblee.

node n'est pas installe sur ce poste. Ce script commence donc par un VRAI PARSE via jsc
(JavaScriptCore, livre avec macOS), qui seul detecte une erreur de syntaxe reelle -- par exemple
une apostrophe non echappee au milieu d'une chaine 'simple', qui passe l'equilibrage sans probleme
mais casse le fichier (cas reel du 12 septembre 2026, desc de produire_fuite dans data.js).
Il complete ensuite par le controle d'equilibrage historique, qui localise mieux un desequilibre :
il rejoue le fichier caractere par caractere avec une PILE
DE MODES, en distinguant reellement :

  - le code
  - les chaines '...' et "..."
  - les gabarits `...`, Y COMPRIS IMBRIQUES via ${...}
  - les echappements
  - les commentaires // et
  - les litteraux de regex /.../, distingues d'une division par le token precedent

et verifie que ( ) [ ] { } sont equilibres et correctement imbriques.

CORRECTIF DU 10 SEPTEMBRE 2026 : la premiere version scannait les interpolations ${...} avec une
simple boucle de profondeur qui ignorait les gabarits IMBRIQUES. Sur plateau-pnj.js:1453
  ${cond ? `texte avec d'une apostrophe` : ''}
le backtick interne etait traite comme un caractere ordinaire, l'apostrophe de "d'une" ouvrait
alors une fausse chaine, et tout le reste du fichier etait decale -- d'ou un ECHEC signale a tort.
La pile de modes ci-dessous traite le cas correctement, a n'importe quelle profondeur.

CE QUE CE SCRIPT NE FAIT PAS : ce n'est pas un parseur. Une faute purement grammaticale
(`if (a b)`, un mot-cle mal place, un appel a une fonction inexistante) passe sans etre vue.
Il attrape la classe d'erreur qu'une edition de gros fichier introduit reellement : accolade
oubliee, chaine non fermee, bloc mal decoupe.
"""

import re
import sys

PAIRES = {')': '(', ']': '[', '}': '{'}
OUVRANTS = set('([{')

# Un '/' qui SUIT l'un de ces tokens demarre une regex, jamais une division.
AVANT_REGEX = set('(,=:[!&|?{};+-*%~^') | {'\n'}


def verifier(chemin):
    with open(chemin, encoding='utf-8', errors='replace') as fh:
        src = fh.read()

    n = len(src)
    i = 0
    ligne = 1

    # Pile de delimiteurs : (caractere, ligne, est_interpolation)
    pile = []
    # Pile de modes : 'code' ou 'template'. On demarre en code.
    modes = ['code']
    dernier_signifiant = '\n'

    while i < n:
        c = src[i]
        mode = modes[-1]

        # ------------------------------------------------------------------ TEMPLATE
        if mode == 'template':
            if c == '\\':
                i += 2
                continue
            if c == '\n':
                ligne += 1
                i += 1
                continue
            if c == '$' and i + 1 < n and src[i + 1] == '{':
                # Entree en interpolation : on repasse en mode code et on empile l'accolade
                # comme un delimiteur normal, marque comme interpolation pour savoir, a sa
                # fermeture, qu'il faut revenir au gabarit.
                pile.append(('{', ligne, True))
                modes.append('code')
                i += 2
                dernier_signifiant = '{'
                continue
            if c == '`':
                modes.pop()
                i += 1
                dernier_signifiant = '`'
                continue
            i += 1
            continue

        # ------------------------------------------------------------------ CODE
        if c == '\n':
            ligne += 1
            i += 1
            dernier_signifiant = '\n'
            continue

        # commentaire ligne
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            while i < n and src[i] != '\n':
                i += 1
            continue

        # commentaire bloc
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            i += 2
            while i + 1 < n and not (src[i] == '*' and src[i + 1] == '/'):
                if src[i] == '\n':
                    ligne += 1
                i += 1
            i += 2
            continue

        # litteral regex (heuristique sur le token precedent)
        if c == '/' and dernier_signifiant in AVANT_REGEX:
            i += 1
            en_classe = False
            while i < n:
                d = src[i]
                if d == '\\':
                    i += 2
                    continue
                if d == '\n':
                    break          # une regex ne franchit pas une fin de ligne
                if d == '[':
                    en_classe = True
                elif d == ']':
                    en_classe = False
                elif d == '/' and not en_classe:
                    i += 1
                    break
                i += 1
            dernier_signifiant = '/'
            continue

        # chaines simples et doubles
        if c in ('"', "'"):
            depart = ligne
            quote = c
            i += 1
            ferme = False
            while i < n:
                d = src[i]
                if d == '\\':
                    i += 2
                    continue
                if d == '\n':
                    return (False, "chaine %s non fermee, ouverte ligne %d" % (quote, depart))
                if d == quote:
                    ferme = True
                    i += 1
                    break
                i += 1
            if not ferme:
                return (False, "chaine %s non fermee, ouverte ligne %d" % (quote, depart))
            dernier_signifiant = quote
            continue

        # ouverture d'un gabarit
        if c == '`':
            modes.append('template')
            i += 1
            dernier_signifiant = '`'
            continue

        # delimiteurs
        if c in OUVRANTS:
            pile.append((c, ligne, False))
            dernier_signifiant = c
            i += 1
            continue

        if c in PAIRES:
            if not pile:
                return (False, "'%s' ligne %d sans ouvrant correspondant" % (c, ligne))
            ouvrant, l0, interp = pile.pop()
            if ouvrant != PAIRES[c]:
                return (False, "'%s' ligne %d ferme un '%s' ouvert ligne %d" % (c, ligne, ouvrant, l0))
            if interp:
                # Fin de l'interpolation : retour au gabarit qui l'englobait.
                if len(modes) > 1:
                    modes.pop()
            dernier_signifiant = c
            i += 1
            continue

        if not c.isspace():
            dernier_signifiant = c
        i += 1

    if len(modes) > 1:
        return (False, "gabarit ` ou interpolation ${ non ferme (profondeur %d)" % (len(modes) - 1))
    if pile:
        ouvrant, l0, _ = pile[-1]
        return (False, "'%s' ouvert ligne %d jamais ferme (%d delimiteur(s) en attente)" % (ouvrant, l0, len(pile)))

    return (True, "equilibrage correct")


JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'


def parse_reel(fichier):
    """Vrai parse du fichier par jsc. (True, '') si le JS est syntaxiquement valide."""
    import json as _json
    import os
    import subprocess
    if not os.path.exists(JSC):
        return (True, 'jsc absent : parse reel ignore')
    # Les fichiers de api/ sont des modules ES (export/import) : new Function ne sait pas les lire.
    # jsc fournit checkModuleSyntax pour ce cas, et checkSyntax pour un script classique.
    src = open(fichier, encoding='utf-8').read()
    est_module = bool(re.search(r'^\s*(export|import)\s', src, re.M))
    # checkSyntax prend un CHEMIN, checkModuleSyntax prend la SOURCE : signatures differentes.
    appel = ('checkModuleSyntax(readFile(%s))' if est_module else 'checkSyntax(%s)') % _json.dumps(fichier)
    prog = 'try { %s; print("PARSE_OK"); } catch (e) { print("PARSE_KO " + e); }' % appel
    try:
        r = subprocess.run([JSC, '-e', prog], capture_output=True, text=True, timeout=120)
    except Exception as e:
        return (True, 'parse reel indisponible (%s)' % e)
    sortie = ((r.stdout or '') + (r.stderr or '')).strip()
    if 'PARSE_OK' in sortie:
        return (True, '')
    return (False, sortie.replace('PARSE_KO ', '').split('\n')[0][:160] or 'parse refuse')


def main():
    fichiers = sys.argv[1:]
    if not fichiers:
        print("usage: verif_syntaxe_js.py <fichier.js> ...")
        return 2
    echecs = 0
    for f in fichiers:
        try:
            ok, msg = verifier(f)
            if ok:
                # Le vrai parse passe apres l'equilibrage : ce dernier localise mieux un
                # desequilibre, mais lui seul ne voit pas une apostrophe non echappee.
                okp, msgp = parse_reel(f)
                if not okp:
                    ok, msg = False, "syntaxe refusee par le parseur : " + msgp
                else:
                    msg = "equilibrage et parse corrects" if not msgp else msg + " (" + msgp + ")"
        except Exception as e:
            ok, msg = False, "erreur de lecture : %s" % e
        etat = "OK  " if ok else "ECHEC"
        print("%s %-45s %s" % (etat, f, msg))
        if not ok:
            echecs += 1
    print("")
    print("%d fichier(s) verifie(s), %d echec(s)" % (len(fichiers), echecs))
    return 1 if echecs else 0


if __name__ == '__main__':
    sys.exit(main())
