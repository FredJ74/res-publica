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
BANC_IMPOTS = os.path.join(RACINE, "outils", "bancs", "banc-taux-imposition.js")
ILLEGALES = os.path.join(RACINE, "plateau-actions-illegales-rumeurs.js")
BANC_TOURNEE = os.path.join(RACINE, "outils", "bancs", "banc-tournee-cloture.js")
PNJ = os.path.join(RACINE, "plateau-pnj.js")
BANC_TERRAIN = os.path.join(RACINE, "outils", "bancs", "banc-mutation-terrain.js")
SUPABASE = os.path.join(RACINE, "supabase.js")
BANC_PLAINTES = os.path.join(RACINE, "outils", "bancs", "banc-cycle-plaintes.js")
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

REGRESSIONS_TERRAIN = [
    ("terrain -- le verdict de la mutation n'est plus lu",
     "  if (!vMut || vMut.ok !== true) {",
     "  if (false) {",
     # Sans la lecture du verdict, `vMut.etat` leve sur un verdict nul : la promesse est rejetee et
     # la fonction ne rend plus false. C'est cette epreuve-la qui tombe la premiere.
     "verdict absent : la fonction rend false"),

    ("terrain -- l'ecriture directe du blob revient",
     "  const vMut = typeof sbRpc === 'function'",
     "  await sbSetTerrainState(state.country, id, patch).catch(() => {});\n"
     "  const vMut = typeof sbRpc === 'function'",
     "finaliserAchatTerrain ne fait plus aucune ecriture directe de terrain"),

    ("terrain -- la purge de la reservation retombe hors du patch",
     "  for (const k in (purge || {})) patch[k] = purge[k];",
     "  if (false) { for (const k in (purge || {})) patch[k] = purge[k]; }",
     "LA PURGE DE LA RESERVATION EST DANS LE MEME PATCH"),

    ("terrain -- le cache local reprend le patch au lieu de l'etat serveur",
     "  if (typeof setTerrainState === 'function' && vMut.etat) setTerrainState(id, vMut.etat);",
     "  if (typeof setTerrainState === 'function') setTerrainState(id, patch);",
     "le cache local recopie l'etat RENDU PAR LE SERVEUR"),
]

REGRESSIONS_TOURNEE = [
    ("tournee -- le verdict de la cloture n'est plus lu",
     "  const close = await cloturer(true);\n  if (!close) {",
     "  const close = await cloturer(true);\n  if (false) {",
     "verdict absent : le joueur est averti que la cloture n a pas pris"),

    ("tournee -- la suppression ligne par ligne revient dans la resolution",
     "  const close = await cloturer(true);\n  if (!close) {",
     "  await sbSupprimerInvitationDiner(1);\n"
     "  const close = await cloturer(true);\n  if (!close) {",
     "aucune suppression d invitation ligne par ligne ne subsiste dans la resolution"),

    ("tournee -- le gain local est pose AVANT la cloture",
     "  const close = await cloturer(true);\n  if (!close) {",
     "  state.moral = Math.min(100, (state.moral || 0) + 2);\n"
     "  const close = await cloturer(true);\n  if (!close) {",
     "verdict absent : le gain local n est pas pose"),

    ("tournee -- une vente refusee est cloturee comme SERVIE",
     "  if (!vente.ok) {\n    await cloturer(false);",
     "  if (!vente.ok) {\n    await cloturer(true);",
     "la porte est appelee une fois avec servie=false"),
]

REGRESSIONS_IMPOTS = [
    ("impots -- le succes redevient inconditionnel",
     "  if (r.ok !== true) { signalerRefusTauxImposition(r); return null; }",
     "  if (false) { signalerRefusTauxImposition(r); return null; }",
     "refus \u00ab autorite_insuffisante \u00bb : nomme au joueur, aucun succes"),

    ("impots -- un verdict absent redevient un taux fixe",
     "  if (!r) {\n"
     "    showToast('Action impossible', \"L'ordre n'a pas abouti : le taux n'a pas \u00e9t\u00e9 "
     "modifi\u00e9.\", false);\n"
     "    return null;\n"
     "  }",
     "  if (false) {\n"
     "    showToast('Action impossible', \"L'ordre n'a pas abouti : le taux n'a pas \u00e9t\u00e9 "
     "modifi\u00e9.\", false);\n"
     "    return null;\n"
     "  }",
     "verdict absent : le refus est dit"),

    ("impots -- le taux annonce redevient celui du curseur",
     "  showToast('Imp\u00f4ts locaux fix\u00e9s', 'Nouveau taux : ' + r.taux + '%.', true, true);",
     "  showToast('Imp\u00f4ts locaux fix\u00e9s', 'Nouveau taux : '"
     " + parseInt(document.getElementById('taux-local-input')?.value || '5') + '%.', true, true);",
     "le curseur disait 31, le serveur a arrete 7"),

    ("impots -- la cle du budget redevient transmise par le client",
     "    p_portee: portee, p_taux: nouveauTaux,",
     "    p_portee: portee, p_taux: nouveauTaux, p_cle: 'republic_capitale',",
     "AUCUNE cle de budget n est transmise"),
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


# ---------------------------------------------------------------------------------------------
# CYCLE DE VIE D'UNE AFFAIRE (chantier 5, les trois `sbSavePlainte`, 10 octobre 2026).
# Le banc lit TROIS fichiers : chaque serie dit lequel elle patche, via `lancer_cible`.
REGRESSIONS_PLAINTES_JUSTICE = [
    ("transmission -- l'annonce du forum redevient inconditionnelle",
     "    if (typeof showToast === 'function') showToast('Affaire non transmise', motifRefus, false);\n"
     "    return false;",
     "    if (typeof showToast === 'function') showToast('Affaire non transmise', motifRefus, false);",
     "un refus ARRETE la fonction avant toute publication"),

    ("transmission -- un rejeu republie l'affaire sur le forum",
     "  if (vAff.deja_transmise === true) return true;",
     "",
     "un rejeu ne republie rien sur le forum"),

    ("transmission -- l'etat local ne recopie plus l'affaire du serveur",
     "  const affaireTransmise = vAff.affaire || {};",
     "  const affaireTransmise = { id: 'affaire-' + Date.now(), cible: cible, motif: motif };",
     "l'etat local recopie l'affaire arretee par le serveur"),

    ("transmission -- l'appelant « enquete conclue » n'attend plus la porte",
     "      const transmise = await transmettreAffaireAuTribunal(",
     "      const transmise = transmettreAffaireAuTribunal(",
     "l'appelant \u00ab enquete conclue \u00bb attend la transmission"),

    ("defense -- le verdict de la porte n'est plus lu",
     "  if (!vDef || vDef.ok !== true) {",
     "  if (false) {",
     "le verdict est lu AVANT toute annonce"),

    ("defense -- le statut de l'affaire redevient pose en memoire",
     "    issue = 'reussite_critique';",
     "    affaire.status = 'jugee';\n    issue = 'reussite_critique';",
     "plus aucune pose locale du statut"),

    ("defense -- l'affaire ne recopie plus l'etat arrete par le serveur",
     "    if (i >= 0) state.plaintesEnCours[i] = vDef.affaire;",
     "    void i;",
     "l'affaire recopie l'etat arrete par le serveur"),
]

REGRESSIONS_PLAINTES_POLITIQUE = [
    ("classement -- le verdict de la porte n'est plus lu",
     "      if (!vClass || vClass.ok !== true) {",
     "      if (false) {",
     "le verdict est lu, et un refus ARRETE la fonction"),

    ("classement -- l'ecran du ministre redevient structurellement vide",
     "  const affaires = state.plaintesEnCours?.filter(p => p.status === 'deposee') || [];\n"
     "  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];",
     "  const affaires = state.plaintesEnCours?.filter(p => p.status === 'pending') || [];\n"
     "  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];",
     "elle filtre le statut reel d une affaire en cours avant jugement"),
]

REGRESSIONS_PLAINTES_SUPABASE = [
    ("cycle -- l'upsert du blob entier revient dans supabase.js",
     "async function sbLoadPlaintes(country) {",
     "async function sbSavePlainte(plainte) {\n  return sbUpsert('plaintes_en_cours', {});\n}\n"
     "async function sbLoadPlaintes(country) {",
     "sbSavePlainte n existe plus dans supabase.js"),
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


def lancer_cible(nom_fichier):
    """Fabrique un lanceur pour un banc qui lit PLUSIEURS fichiers : il faut dire lequel la copie
    patchee remplace. Sans cela, `banc-cycle-plaintes.js` lirait la copie a la place du premier
    fichier de sa liste et la contre-epreuve prouverait n'importe quoi."""
    def lanceur(banc, chemin_source):
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as f:
            f.write("var CHEMIN_FICHIER = %r;\nvar CHEMIN_SOURCE = %r;\n"
                    % (nom_fichier, chemin_source))
            decor = f.name
        try:
            r = subprocess.run([sys.executable, LANCEUR, banc, decor],
                               capture_output=True, text=True)
            return r.returncode, r.stdout + r.stderr
        finally:
            os.unlink(decor)
    return lanceur


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
    serie("TAUX D'IMPOSITION", BANC_IMPOTS, JUSTICE, REGRESSIONS_IMPOTS, echecs)
    serie("CLOTURE D'UNE TOURNEE", BANC_TOURNEE, ILLEGALES, REGRESSIONS_TOURNEE, echecs)
    serie("MUTATION DE PROPRIETE D'UN TERRAIN", BANC_TERRAIN, PNJ, REGRESSIONS_TERRAIN, echecs)
    serie("CYCLE D'UNE AFFAIRE -- justice", BANC_PLAINTES, JUSTICE,
          REGRESSIONS_PLAINTES_JUSTICE, echecs, lanceur=lancer_cible("plateau-justice-economie.js"))
    serie("CYCLE D'UNE AFFAIRE -- politique", BANC_PLAINTES, POLITIQUE,
          REGRESSIONS_PLAINTES_POLITIQUE, echecs, lanceur=lancer_cible("plateau-politique.js"))
    serie("CYCLE D'UNE AFFAIRE -- supabase", BANC_PLAINTES, SUPABASE,
          REGRESSIONS_PLAINTES_SUPABASE, echecs, lanceur=lancer_cible("supabase.js"))
    total = (len(REGRESSIONS) + len(REGRESSIONS_VOTE) + len(REGRESSIONS_DESERTION)
             + len(REGRESSIONS_COTISATIONS) + len(REGRESSIONS_SUCCESSIONS)
             + len(REGRESSIONS_IMPOTS) + len(REGRESSIONS_TOURNEE)
             + len(REGRESSIONS_TERRAIN) + len(REGRESSIONS_PLAINTES_JUSTICE)
             + len(REGRESSIONS_PLAINTES_POLITIQUE) + len(REGRESSIONS_PLAINTES_SUPABASE))
    if echecs:
        print("ECHEC : %d contre-epreuve(s) en defaut." % len(echecs))
        for e in echecs:
            print("  - " + e)
        return 1
    print("LES %d CONTRE-EPREUVES SONT VERTES." % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
