#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Contre-epreuves de banc-detention-plateau.js.

POURQUOI CE FICHIER EXISTE. Un banc qui passe AUSSI sans le correctif ne prouve rien. Chacune des
treize regressions ci-dessous reinjecte, dans une COPIE de plateau-justice-economie.js, exactement
le defaut que le lot du 9 octobre 2026 a ferme -- puis relance le banc sur cette copie et exige
qu'il ROUGISSE, en nommant l'epreuve qui doit tomber.

Le fichier de production n'est jamais modifie : la copie vit dans le repertoire temporaire.

Usage :
    python3 outils/bancs/contre-epreuves-detention.py
"""
import os
import re
import subprocess
import sys
import tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JUSTICE = os.path.join(RACINE, "plateau-justice-economie.js")
POLITIQUE = os.path.join(RACINE, "plateau-politique.js")
BANC_DETENTION = os.path.join(RACINE, "outils", "bancs", "banc-detention-plateau.js")
BANC_VOTE = os.path.join(RACINE, "outils", "bancs", "banc-vote-electoral.js")
LANCEUR = os.path.join(RACINE, "outils", "bancs", "lancer-banc.py")

# (nom, chaine cherchee, remplacement, fragment de l'epreuve qui DOIT tomber)
REGRESSIONS_VOTE = [
    ("vote -- « Vote enregistre ! » redevient inconditionnel",
     "  if (!vVote || vVote.ok !== true) {",
     "  if (false) {",
     "aucun « Vote enregistré ! »"),

    ("vote -- une coupure reseau redevient un silence",
     "                                      p_ville: city || null, p_candidat: candidatNom })\n"
     "        .catch(() => null)",
     "                                      p_ville: city || null, p_candidat: candidatNom })",
     "un refus, pas un silence"),

    ("vote -- le bulletin est marque AVANT la confirmation",
     "  const rVote = typeof sbRpc === 'function'",
     "  cycle.votes[votant] = candidatNom;\n  const rVote = typeof sbRpc === 'function'",
     "aucun bulletin local"),
]

REGRESSIONS = [
    ("chaine 9 -- le verdict d'ouverture n'est plus lu",
     "if (!vOuv || vOuv.ok !== true) return null;",
     "if (false) return null;",
     "aucun etat de detention pose"),

    ("chaine 9 -- le jour de fin redevient celui du navigateur",
     "const jourFinReel = (vOuv.jour_fin != null) ? vOuv.jour_fin : Number(jourFin);",
     "const jourFinReel = Number(jourFin);",
     "CELUI DU SERVEUR, pas celui passe par le client"),

    ("chaine 9 -- une peine sans terme redevient possible",
     "if (jourFin === null || jourFin === undefined || !Number.isFinite(Number(jourFin))) {",
     "if (!Number.isFinite(Number(jourFin))) {",
     "une peine sans terme est refusee"),

    ("chaine 12 -- le verdict de prolongation n'est plus lu",
     "  if (!r || r.ok !== true) {\n    // Refus d'autorite (42501), cible non detenue",
     "  if (false) {\n    // Refus d'autorite (42501), cible non detenue",
     "false rendu et peine inchangee"),

    ("chaine 11 -- la liberation redevient inconditionnelle",
     "    if (!vFin || vFin.ok !== true) return;",
     "    if (false) return;",
     "le detenu reste detenu"),

    ("chaine 10 -- le transfert au QHS redevient inconditionnel",
     "    if (!vQhs || vQhs.ok !== true) {",
     "    if (false) {",
     "aucun QHS annonce"),

    ("chaine 10 -- le client repose lui-meme le drapeau QHS",
     "    state.detentionQHS = { enQHS: true, paLimite1Jour: false };\n    updateUI();",
     "    await sbUpdate('personnages', 'name=eq.x', { detention_qhs: JSON.stringify({ enQHS: true }) });\n"
     "    state.detentionQHS = { enQHS: true, paLimite1Jour: false };\n    updateUI();",
     "aucun drapeau QHS ecrit par le client"),

    ("chaine 13 -- la sentence redevient une annonce",
     "  if (!vSentence || vSentence.ok !== true) {",
     "  if (false) {",
     "aucune sentence annoncee"),

    # Sans la lecture du verdict, le code tombe dans la branche « requete rejetee » et annonce
    # au joueur que le juge a refuse -- alors que la requete n'a jamais ete enregistree. Le banc
    # tombe donc sur l'epreuve qui exige un refus HONNETE, pas sur celle de la peine.
    ("chaine 13 -- la competence n'est plus verifiee avant la sanction",
     "  if (vAutorite !== true) {",
     "  if (false) {",
     "competence refusee : AUCUNE sanction appliquee"),

    ("chaine de l'avocat -- le verdict de la reduction n'est plus lu",
     "  if (!vAvocat || vAvocat.ok !== true) {",
     "  if (false) {",
     "verdict refuse : le refus est dit"),

    ("chaine de l'avocat -- la reduction redevient calculee par le navigateur",
     "      state.estEmprisonne.jourFin = vAvocat.jour_fin;\n      state.estEmprisonne.jours = vAvocat.jours;",
     "      state.estEmprisonne.jourFin = 99;\n      state.estEmprisonne.jours = 99;",
     "la nouvelle peine est celle du serveur"),

    ("chaine de l'evasion -- le verdict de la cloture n'est plus lu",
     "    if (!vEvasion || vEvasion.ok !== true) {",
     "    if (false) {",
     "le detenu reste detenu"),

    ("chaine 13 -- la sanction n'est plus exigee avant l'archivage",
     "  if (!peineAppliquee) {\n    affaire.status = 'deposee';",
     "  if (false) {\n    affaire.status = 'deposee';",
     "la porte du greffe n est meme pas appelee"),
]


def lancer(banc, chemin_source):
    """Lance le banc sur la source donnee. Rend (code_de_sortie, sortie)."""
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as f:
        f.write("var CHEMIN_SOURCE = %r;\n" % chemin_source)
        decor = f.name
    try:
        r = subprocess.run([sys.executable, LANCEUR, banc, decor],
                           capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr
    finally:
        os.unlink(decor)


def serie(titre, banc, source, regressions, echecs):
    texte = open(source, encoding="utf-8").read()
    code, sortie = lancer(banc, source)
    if code != 0:
        echecs.append("%s : le banc n'est pas vert sur le fichier de production" % titre)
        print("  ***  %s : banc NON vert sur la production" % titre)
        print(sortie[-1500:])
        return
    print("%s -- reference VERTE sur le fichier de production :" % titre)
    for nom, cherche, remplace, epreuve in regressions:
        n = texte.count(cherche)
        if n != 1:
            echecs.append("%s : la chaine cherchee apparait %d fois (1 attendue)" % (nom, n))
            print("  ***  %-62s ancrage introuvable" % nom)
            continue
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as f:
            f.write(texte.replace(cherche, remplace))
            copie = f.name
        try:
            code, sortie = lancer(banc, copie)
        finally:
            os.unlink(copie)
        tombee = any(epreuve in l for l in sortie.splitlines() if l.startswith("  *** "))
        if code == 0:
            echecs.append("%s : le banc reste VERT malgre la regression" % nom)
            print("  ***  %-62s banc vert -- il ne prouve rien" % nom)
        elif not tombee:
            echecs.append("%s : le banc rougit mais PAS sur l'epreuve attendue (%s)"
                          % (nom, epreuve))
            print("  ***  %-62s rougit ailleurs" % nom)
        else:
            print("  ok   %-62s l'epreuve attendue tombe" % nom)
    print("")


def main():
    echecs = []
    serie("DETENTION", BANC_DETENTION, JUSTICE, REGRESSIONS, echecs)
    serie("VOTE ELECTORAL", BANC_VOTE, POLITIQUE, REGRESSIONS_VOTE, echecs)
    total = len(REGRESSIONS) + len(REGRESSIONS_VOTE)
    if echecs:
        print("ECHEC : %d contre-epreuve(s) en defaut." % len(echecs))
        for e in echecs:
            print("  - " + e)
        return 1
    print("LES %d CONTRE-EPREUVES SONT VERTES." % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
