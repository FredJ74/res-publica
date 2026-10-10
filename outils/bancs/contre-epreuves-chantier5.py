#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Contre-epreuves de banc-detention-plateau.js.

POURQUOI CE FICHIER EXISTE. Un banc qui passe AUSSI sans le correctif ne prouve rien. Chacune des
seize regressions ci-dessous reinjecte, dans une COPIE de plateau-justice-economie.js, exactement
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
BANC_DESERTION = os.path.join(RACINE, "outils", "bancs", "banc-desertion-liberation.js")
CRON = os.path.join(RACINE, "api", "cron-minuit.js")
BANC_COTISATIONS = os.path.join(RACINE, "outils", "bancs", "banc-cotisations-organisations.js")
BANC_SUCCESSIONS = os.path.join(RACINE, "outils", "bancs", "banc-successions-reglement.js")
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

REGRESSIONS_DESERTION = [
    ("demobilisation -- le verdict de la cloture n'est plus lu",
     "    if (vFin && vFin.ok === true) {",
     "    if (true) {",
     "refus : le detenu reste detenu"),

    ("incorporation -- le verdict de la cloture n'est plus lu",
     "    if (!vInc || vInc.ok !== true) {",
     "    if (false) {",
     "refus : il n est PAS conduit a la caserne"),

    # Sans le retour en arriere, un refus laisse un SOLDAT DETENU : la requisition dit
    # « incorpore » alors que la peine court toujours.
    ("incorporation -- l'incorporation posee en memoire n'est plus annulee",
     "      state.char.requisition = req;\n      showToast('Transfert impossible'",
     "      showToast('Transfert impossible'",
     "l'incorporation posee en memoire est REVENUE en arriere"),
]

# Les deux series du cron (famille D du chantier 6) ne peuvent PAS passer par CHEMIN_SOURCE : leurs
# bancs n'extraient pas le code par readFile, ils CHARGENT api/cron-minuit.js comme module. La copie
# patchee leur est donc donnee en derniere source sur la ligne de commande, a la place du fichier de
# production -- voir lancer_sources() plus bas.
REGRESSIONS_COTISATIONS = [
    ("cotisations -- la fiche du membre est a nouveau relue avant la porte",
     "        const etape = 'cotisation:' + row.id + ':' + membre.nom;",
     "        await sbGet('personnages', `name=eq.${encodeURIComponent(membre.nom)}`);\n"
     "        const etape = 'cotisation:' + row.id + ':' + membre.nom;",
     "la fiche du membre n est plus relue ici"),

    ("cotisations -- le debit redevient une ecriture directe",
     "        const etape = 'cotisation:' + row.id + ':' + membre.nom;",
     "        await sbUpdate('personnages', `name=eq.${encodeURIComponent(membre.nom)}`,"
     " { arg: 0 });\n"
     "        const etape = 'cotisation:' + row.id + ':' + membre.nom;",
     "aucune ecriture directe"),

    ("cotisations -- un verdict absent redevient un succes",
     "        if (!v) { signalerEchec(etape, 'aucun verdict rendu'); continue; }",
     "        if (!v) { resultats.renouvellements++; continue; }",
     "verdict absent : rien compte"),

    ("cotisations -- la saison n'est plus transmise a la porte",
     "          p_saison: orga.type === 'supporters' ? saisonActuelle.numero : null",
     "          p_saison: null",
     "avec l organisation, le membre et la saison"),
]

REGRESSIONS_SUCCESSIONS = [
    ("successions -- un verdict absent redevient une cloture",
     "  if (!v) { signalerEchec(etape, 'aucun verdict rendu'); return false; }",
     "  if (!v) { return true; }",
     "verdict absent : aucune cloture"),

    ("successions -- les etapes refusees redeviennent silencieuses",
     "  if (Array.isArray(v.echecs) && v.echecs.length > 0) {",
     "  if (false) {",
     "l etape refusee est NOMMEE"),

    ("successions -- une succession non tranchee est quand meme presentee a la porte",
     "      if (toutesResolues) {",
     "      if (true) {",
     "la porte n est pas appelee"),
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


def lancer_sources(banc, chemin_source):
    """Lance un banc a SOURCES (celui-ci charge le fichier de production comme module) en lui
    substituant la copie patchee en derniere source. Rend (code_de_sortie, sortie)."""
    r = subprocess.run([sys.executable, LANCEUR, banc,
                        os.path.join(RACINE, "outils", "bancs", "decor-env-serveur.js"),
                        os.path.join(RACINE, "api", "_referentiels-generes.js"),
                        chemin_source],
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def serie(titre, banc, source, regressions, echecs, lanceur=None):
    lanceur = lanceur or lancer
    texte = open(source, encoding="utf-8").read()
    code, sortie = lanceur(banc, source)
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
            code, sortie = lanceur(banc, copie)
        finally:
            os.unlink(copie)
        tombee = any(epreuve in l for l in sortie.splitlines()
                     if l.startswith("  *** ") or l.startswith("  NON "))
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
    serie("LIBERATIONS DE DESERTION", BANC_DESERTION, POLITIQUE, REGRESSIONS_DESERTION, echecs)
    serie("COTISATIONS D'ORGANISATION", BANC_COTISATIONS, CRON, REGRESSIONS_COTISATIONS, echecs,
          lanceur=lancer_sources)
    serie("REGLEMENT DES SUCCESSIONS", BANC_SUCCESSIONS, CRON, REGRESSIONS_SUCCESSIONS, echecs,
          lanceur=lancer_sources)
    total = (len(REGRESSIONS) + len(REGRESSIONS_VOTE) + len(REGRESSIONS_DESERTION)
             + len(REGRESSIONS_COTISATIONS) + len(REGRESSIONS_SUCCESSIONS))
    if echecs:
        print("ECHEC : %d contre-epreuve(s) en defaut." % len(echecs))
        for e in echecs:
            print("  - " + e)
        return 1
    print("LES %d CONTRE-EPREUVES SONT VERTES." % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
