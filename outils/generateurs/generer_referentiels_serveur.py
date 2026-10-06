#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GENERATEUR DU MODULE SERVEUR DES REFERENTIELS (chantier 4B, 6 octobre 2026).

LE PROBLEME. api/*.js ne peut pas importer les fichiers du navigateur : data.js
n'a ni export ni module.exports, il n'y a pas de package.json, et les modules
plateau-*.js melangent donnees et comportement -- plateau-core.js enregistre
deux ecouteurs et ecrit dans window des son chargement. Les faire executer par
le serverless serait un couplage faux. Chaque constante dont le cron a besoin
etait donc ressaisie A LA MAIN : trente-quatre constantes *_SERVEUR, et le
fichier l'avoue a chaque fois.

LA REPONSE, qui est celle que le depot applique deja a ses tables miroir :
    SOURCE METIER CANONIQUE -> GENERATION CONTROLEE -> MODULE SERVEUR GENERE
Le module genere est un ARTEFACT TECHNIQUE. Il ne devient jamais une seconde
source de verite : il se regenere, il ne se modifie pas. Toute retouche a la
main est detectee par verifier-referentiels.py, qui rejoue cette generation et
compare.

CE GENERATEUR NE CORRIGE RIEN, ET C'EST LE POINT DUR. Une copie serveur n'est
remplacee que si son equivalence est PROUVEE : la valeur produite depuis le
canon et celle ecrite a la main doivent rendre le MEME texte, par le meme rendu
canonique. Si elles different, la copie reste ou elle est et la divergence est
declaree dans referentiels-serveur.json. Regenerer une copie divergente
reviendrait a trancher un arbitrage de game design en le faisant passer pour de
l'outillage.

POURQUOI LE RENDU PRODUIT DU JS ET NON DU JSON. GREVE_PALIERS et
GREVE_GENERALE_NIVEAUX contiennent Infinity. Un aller-retour JSON l'ecrit
`null`, et `pop >= null` n'est pas `pop >= Infinity` : les seuils de greve
auraient change de comportement sans qu'une ligne de game design soit touchee.
Le rendu ci-dessous ecrit Infinity, et REFUSE tout ce qu'il ne sait pas ecrire
fidelement -- fonction, undefined, NaN, Symbol -- au lieu de l'approximer. Un
generateur qui approxime fabrique la panne qu'il pretend empecher.

Usage :
    python3 outils/generateurs/generer_referentiels_serveur.py              # verifie
    python3 outils/generateurs/generer_referentiels_serveur.py --ecrire     # ecrit l'artefact
    python3 outils/generateurs/generer_referentiels_serveur.py --empreinte  # md5 de l'artefact
    python3 outils/generateurs/generer_referentiels_serveur.py --rendu      # imprime l'artefact

Code de sortie 0 si tout concorde, 1 sinon. N'accede a aucune base.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

JSC_CANDIDATS = [
    "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc",
    "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc",
]


def _racine():
    """La racine du depot, trouvee en REMONTANT jusqu'a data.js. Voir la note
    des huit autres generateurs : compter des niveaux de repertoire les a tous
    casses au chantier 2H."""
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "data.js")):
            return d
        d = os.path.dirname(d)
    raise SystemExit("racine du depot introuvable : aucun data.js en remontant")


RACINE = _racine()
DECLARATION = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "referentiels-serveur.json")
ARTEFACT = os.path.join(RACINE, "api", "_referentiels-generes.js")

# Le rendu canonique, en JavaScript, joue dans le meme moteur que les sources.
# Il est ici et nulle part ailleurs : les deux cotes de la comparaison
# d'equivalence doivent passer par EXACTEMENT le meme rendu, sinon la
# comparaison mesure le rendu et non les valeurs.
RENDU = r"""
function rendre(x, marge) {
  var suite = marge + '  ';
  if (x === null) return 'null';
  var t = typeof x;
  if (t === 'boolean') return x ? 'true' : 'false';
  if (t === 'number') {
    if (x === Infinity) return 'Infinity';
    if (x === -Infinity) return '-Infinity';
    if (x !== x) throw new Error('NaN n\'est pas representable fidelement');
    return String(x);
  }
  if (t === 'string') return JSON.stringify(x);
  if (t === 'undefined') throw new Error('undefined n\'est pas representable');
  if (t === 'function') throw new Error('une fonction ne se recopie pas dans un referentiel');
  if (t === 'symbol') throw new Error('Symbol n\'est pas representable');
  if (Array.isArray(x)) {
    if (x.length === 0) return '[]';
    var e = x.map(function (v) { return suite + rendre(v, suite); });
    return '[\n' + e.join(',\n') + '\n' + marge + ']';
  }
  var cles = Object.keys(x);
  if (cles.length === 0) return '{}';
  var p = cles.map(function (k) {
    return suite + JSON.stringify(k) + ': ' + rendre(x[k], suite);
  });
  return '{\n' + p.join(',\n') + '\n' + marge + '}';
}
function projeter(o, champs) {
  var r = {};
  for (var i = 0; i < champs.length; i++) {
    if (Object.prototype.hasOwnProperty.call(o, champs[i])) r[champs[i]] = o[champs[i]];
  }
  return r;
}
// ORDONNER N'EST PAS DE LA COSMETIQUE. L'ordre des cles d'un objet JavaScript
// est observable : Object.keys, Object.entries et JSON.stringify le rendent.
// RESSOURCES_ECONOMIE_SERVEUR sert d'espace d'INDICES dans un aller-retour avec
// la base (cles[i.index], cron-minuit.js:2811). Plutot que de raisonner sur
// trente-trois usages pour conclure qu'un deplacement de `textile` est sans
// effet -- un raisonnement juste ne vaut pas une preuve -- on reproduit l'ordre
// que le serveur avait, et l'equivalence redevient litterale.
//
// Le refus est la moitie utile : si le canon gagne ou perd une cle, l'ordre
// declare ne la couvre plus et la generation s'arrete. C'est une decision a
// prendre, pas un silence a subir.
function ordonner(o, ordre) {
  var cles = Object.keys(o);
  if (cles.length !== ordre.length) {
    throw new Error('ordre declare : ' + ordre.length + ' cles, le canon en rend ' + cles.length);
  }
  var r = {};
  for (var i = 0; i < ordre.length; i++) {
    if (!Object.prototype.hasOwnProperty.call(o, ordre[i])) {
      throw new Error('ordre declare : cle « ' + ordre[i] + ' » absente du canon');
    }
    r[ordre[i]] = o[ordre[i]];
  }
  return r;
}
"""


def jsc():
    for c in JSC_CANDIDATS:
        if os.path.exists(c):
            return c
    return None


def jouer(script, moteur):
    f = tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8")
    f.write(script)
    f.close()
    try:
        p = subprocess.run([moteur, f.name], capture_output=True, text=True, timeout=300)
    finally:
        os.unlink(f.name)
    if p.returncode != 0:
        return None, ((p.stdout or "") + (p.stderr or "")).strip()[-300:]
    return p.stdout, None


def litteral_de(chemin, constante):
    """Isole le TEXTE de l'expression affectee a `constante`, par equilibrage de
    delimiteurs, en traversant chaines et commentaires sans compter leurs
    delimiteurs. Sert aux fichiers qu'on ne veut PAS charger : plateau-core.js
    touche window, plateau-justice-economie.js depend de l'ordre de chargement.
    On lit la donnee sans jamais executer le comportement qui l'entoure."""
    src = open(chemin, encoding="utf-8", errors="replace").read()
    m = re.search(r"(?:^|\n)\s*(?:const|let|var)\s+%s\s*=\s*" % re.escape(constante), src)
    if not m:
        return None
    i = m.end()
    while i < len(src) and src[i] in " \t\n":
        i += 1
    if i >= len(src):
        return None
    if src[i] in "{[":
        ouvrant, fermant = src[i], {"{": "}", "[": "]"}[src[i]]
    else:
        ouvrant = fermant = None
    prof, j, chaine = 0, i, None
    while j < len(src):
        c = src[j]
        if chaine:
            if c == "\\":
                j += 2
                continue
            if c == chaine:
                chaine = None
            j += 1
            continue
        if c in "'\"`":
            chaine = c
            j += 1
            continue
        if c == "/" and j + 1 < len(src) and src[j + 1] == "/":
            k = src.find("\n", j)
            if k < 0:
                break
            j = k
            continue
        if c == "/" and j + 1 < len(src) and src[j + 1] == "*":
            k = src.find("*/", j)
            if k < 0:
                break
            j = k + 2
            continue
        if ouvrant:
            if c == ouvrant:
                prof += 1
            elif c == fermant:
                prof -= 1
                if prof == 0:
                    return src[i:j + 1]
        else:
            if c in ";\n" and prof == 0:
                return src[i:j].strip()
        j += 1
    return None


def _ordonne(expr, r):
    """Enveloppe une expression dans ordonner() si la declaration fixe l'ordre."""
    if "ordre_des_cles" not in r:
        return expr
    return "ordonner(%s, %s)" % (expr, json.dumps(r["ordre_des_cles"]))


def transformation(r):
    """Le code JS qui va du canon a ce que le serveur lit. Les quatre formes
    sont des projections mecaniques : aucune ne decide quoi que ce soit."""
    forme = r["forme"]
    if forme == "valeur":
        return _ordonne("SOURCE", r)
    champs = json.dumps(r.get("champs", []))
    if forme == "projection_objet":
        return _ordonne("(function (s, c) { var o = {}; Object.keys(s).forEach(function (k) "
                        "{ o[k] = projeter(s[k], c); }); return o; })(SOURCE, %s)" % champs, r)
    if forme == "projection_liste":
        return ("(function (s, c) { return s.map(function (e) { return projeter(e, c); }); })"
                "(SOURCE, %s)" % champs)
    if forme == "projection_objet_de_listes":
        return _ordonne("(function (s, c) { var o = {}; Object.keys(s).forEach(function (k) "
                        "{ o[k] = s[k].map(function (e) { return projeter(e, c); }); }); return o; })"
                        "(SOURCE, %s)" % champs, r)
    if forme == "index_par":
        return _ordonne("(function (s, c, cle) { var o = {}; s.forEach(function (e) "
                        "{ o[String(e[cle])] = projeter(e, c); }); return o; })(SOURCE, %s, %s)"
                        % (champs, json.dumps(r["cle"])), r)
    raise SystemExit("forme inconnue dans la declaration : %s" % forme)


def valeur_generee(r, moteur):
    """Rend le TEXTE JS canonique de la valeur produite depuis le canon."""
    chemin = os.path.join(RACINE, r["fichier"])
    if not os.path.exists(chemin):
        return None, "fichier canonique absent : " + r["fichier"]
    if r.get("lecture") == "litteral":
        lit = litteral_de(chemin, r["canon"])
        if lit is None:
            return None, "constante %s introuvable dans %s" % (r["canon"], r["fichier"])
        prologue = "var SOURCE = %s;\n" % lit
    else:
        prologue = "load(%s);\nvar SOURCE = %s;\n" % (json.dumps(chemin), r["canon"])
    script = RENDU + prologue + "print(rendre(%s, ''));\n" % transformation(r)
    sortie, err = jouer(script, moteur)
    if err:
        return None, err
    return sortie.rstrip("\n"), None


ENTETE = """// ============================================================================
// REFERENTIELS DU JEU, POUR LE SERVEUR -- FICHIER GENERE, NE PAS MODIFIER
// ============================================================================
//
// Genere par outils/generateurs/generer_referentiels_serveur.py depuis les
// sources canoniques du navigateur, chargees dans JavaScriptCore. Ce fichier
// est un ARTEFACT TECHNIQUE : il n'est pas une source de verite, et une valeur
// corrigee ici serait perdue a la prochaine generation -- apres avoir fait
// diverger le serveur du jeu, ce que ce chantier existe pour empecher.
//
// Pour changer une de ces valeurs : la changer dans sa source canonique, puis
// rejouer le generateur. Les sources sont nommees ci-dessous, une par
// constante.
//
// verifier-referentiels.py rejoue cette generation a chaque passage et refuse
// si le fichier sur le disque ne correspond plus.
//
// NE CONTIENT QUE CE QUI EST PROUVE EQUIVALENT. Les copies qui divergent de
// leur canon sont restees a la main dans api/cron-minuit.js, et la divergence
// est declaree dans outils/generateurs/referentiels-serveur.json. On ne fait
// pas disparaitre un arbitrage de game design en le regenerant.
// ============================================================================

"""


def construire(moteur):
    """Rend (texte de l'artefact, lignes de rapport, nombre d'echecs).

    CE QUE CETTE FONCTION PROUVE, ET CE QU'ELLE NE PROUVE PLUS. Pendant la
    migration du 6 octobre 2026, elle comparait la valeur produite depuis le
    canon a la copie encore ecrite a la main dans api/cron-minuit.js, et
    n'emettait que les constantes identiques au texte pres. Cette porte a ete
    franchie une fois : les dix-huit ont ete prouvees, puis retirees du cron.
    Les comparer encore a un fichier qui ne les contient plus n'aurait aucun
    sens.

    L'invariant qui reste, et qui est le bon, est verifie par
    verifier-referentiels.py : l'artefact present sur le disque doit etre
    exactement ce que cette fonction rend. Si une source canonique bouge,
    la regeneration differe du disque, le controle rougit, et quelqu'un doit
    rejouer --ecrire puis relire le diff. Si quelqu'un retouche l'artefact a la
    main, meme refus. Dans les deux cas le changement est vu, ce qui est tout
    ce qu'on demande a un garde-fou."""
    decl = json.load(open(DECLARATION, encoding="utf-8"))
    morceaux, rapport, echecs = [], [], 0

    for r in decl["referentiels"]:
        nom = r["serveur"]
        genere, err = valeur_generee(r, moteur)
        if err:
            rapport.append((nom, r["fichier"], "ILLISIBLE", err[:70]))
            echecs += 1
            continue
        rapport.append((nom, r["fichier"], "RENDU", ""))
        morceaux.append("// %s -- %s de %s\nexport const %s = %s;\n"
                        % (nom, r["canon"], r["fichier"], nom, genere))

    return ENTETE + "\n".join(morceaux), rapport, echecs


def main():
    moteur = jsc()
    if not moteur:
        print("JavaScriptCore est introuvable : ce generateur CHARGE le vrai code")
        print("plutot que de deviner ses valeurs. Il s'abstient.")
        return 1

    texte, rapport, echecs = construire(moteur)

    if "--rendu" in sys.argv:
        sys.stdout.write(texte)
        return 1 if echecs else 0
    if "--empreinte" in sys.argv:
        print(hashlib.md5(texte.encode("utf-8")).hexdigest()[:16])
        return 1 if echecs else 0

    print("GENERATEUR DES REFERENTIELS SERVEUR")
    print("  %d constante(s) declaree(s) generables" % len(rapport))
    for nom, fichier, etat, note in rapport:
        print("  %-46s %-36s %-10s %s" % (nom, fichier, etat, note))

    if "--ecrire" in sys.argv:
        if echecs:
            print("\nRIEN N'A ETE ECRIT : %d constante(s) n'ont pas pu etre rendues." % echecs)
            print("Un artefact partiel serait pire que pas d'artefact.")
            return 1
        avant = open(ARTEFACT, encoding="utf-8").read() if os.path.exists(ARTEFACT) else None
        open(ARTEFACT, "w", encoding="utf-8").write(texte)
        print("\n%s %s" % ("inchange :" if avant == texte else "ecrit    :",
                           os.path.relpath(ARTEFACT, RACINE)))
        print("empreinte : %s" % hashlib.md5(texte.encode("utf-8")).hexdigest()[:16])
        return 0

    print("\nempreinte de l'artefact : %s" % hashlib.md5(texte.encode("utf-8")).hexdigest()[:16])
    if echecs:
        print("ECHEC : %d constante(s) n'ont pas pu etre rendues depuis leur canon." % echecs)
        return 1
    sur_disque = open(ARTEFACT, encoding="utf-8").read() if os.path.exists(ARTEFACT) else None
    if sur_disque is None:
        print("L'artefact n'existe pas encore : --ecrire pour le creer.")
        return 1
    if sur_disque != texte:
        print("ECHEC : l'artefact du disque ne correspond PAS a ce que rendent les sources.")
        print("        Soit il a ete modifie a la main -- il est genere, c'est interdit --")
        print("        soit une source canonique a bouge. Rejouer --ecrire, puis relire le diff.")
        return 1
    print("Les %d constantes sont rendues depuis leur canon, et l'artefact du" % len(rapport))
    print("disque leur correspond exactement.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
