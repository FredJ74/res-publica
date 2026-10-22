#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Contre-epreuves de banc-detention-plateau.js.

POURQUOI CE FICHIER EXISTE. Un banc qui passe AUSSI sans le correctif ne prouve rien. Chacune des
regressions ci-dessous reinjecte, dans une COPIE d'un fichier de production, exactement le defaut
qu'un lot a ferme -- puis relance le banc sur cette copie et exige qu'il ROUGISSE, en nommant
l'epreuve qui doit tomber. Le fichier a grossi lot par lot : detention (9 octobre), subventions
municipales (10 octobre), greffe et universite (13 octobre).

DEUX FACONS DE SUBSTITUER UN FICHIER, selon le banc. Un banc a SOURCES recoit la copie dans sa
liste de sources ; un banc qui lit lui-meme le depot par readFile recoit une TABLE DE
SUBSTITUTION (`lancer_substitution`). Se tromper de lanceur donne un banc qui reste vert sur une
regression reelle -- et c'est exactement ce que ce fichier existe pour interdire.

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
PERSONNAGE = os.path.join(RACINE, "plateau-personnage.js")
BANC_TERRAIN_ETAT = os.path.join(RACINE, "outils", "bancs", "banc-etat-terrain.js")
ORGANISATIONS = os.path.join(RACINE, "plateau-organisations-quetes.js")
ROUTEUR = os.path.join(RACINE, "plateau-router.js")
DATA = os.path.join(RACINE, "data.js")
BANC_SUBVENTIONS = os.path.join(RACINE, "outils", "bancs", "banc-subventions-client.js")
BANC_GREFFE = os.path.join(RACINE, "outils", "bancs", "banc-greffe-documents-client.js")
BANC_PNJ = os.path.join(RACINE, "outils", "bancs", "banc-dialogue-pnj-republia.js")
PNJ = os.path.join(RACINE, "plateau-pnj.js")
PERSONNALITES = os.path.join(RACINE, "api", "_pnj-personnalites.js")
PROFILS_PNJ = os.path.join(RACINE, "api", "_pnj-profils.js")
CHAT = os.path.join(RACINE, "api", "chat.js")
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

    # Les DEUX contre-epreuves de la chaine de l'avocat ont ete RETIREES le 13 octobre 2026 : la
    # requete d'avocat en cellule a ete supprimee (un d100 decidait si une plaidoirie avait
    # convaincu un juge). Il n'y a plus de code a regresser. Le verrou qui remplace ces deux
    # mesures est le chapitre 8 du banc : il rougit si la mecanique renait.
    #
    # La contre-epreuve de ce verrou est faite ICI, en sens INVERSE : au lieu de casser un
    # correctif, on fait RENAITRE la mecanique supprimee et on exige que le banc la voie.
    ("verrou de l avocat -- le handler supprime est reinjecte",
     "function doGreveFaim() {",
     "function confirmerRequeteAvocat(pa, cost) { return pa + cost; }\nfunction doGreveFaim() {",
     "aucun handler doRequeteAvocat / confirmerRequeteAvocat"),

    ("verrou de l avocat -- l appel a la porte serveur est reinjecte",
     "function doGreveFaim() {\n",
     "function doGreveFaim() {\n  sbRpc('detention_reduire_peine', {});\n",
     "aucun appel a la porte serveur detention_reduire_peine"),

    ("verrou de l avocat -- le drapeau avocatUtilise est reinjecte",
     "function doGreveFaim() {\n",
     "function doGreveFaim() {\n  state.estEmprisonne.avocatUtilise = true;\n",
     "aucun drapeau avocatUtilise"),

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

    # LES DEUX ANCRAGES ONT ETE REFAITS le 13 octobre 2026. Ils nommaient `issue =
    # 'reussite_critique'` et `state.plaintesEnCours[i]`, deux ecritures disparues quand la
    # formule de la procedure simplifiee est passee au serveur (12 octobre) : les contre-epreuves
    # ne prouvaient donc plus rien depuis ce jour-la, en silence. Une contre-epreuve dont
    # l'ancrage a disparu est une contre-epreuve morte.
    ("defense -- le statut de l'affaire redevient pose en memoire",
     "  const avocat = vDef.avocat || \"l'avocat commis d'office\";",
     "  affaire.status = 'jugee';\n  const avocat = vDef.avocat || \"l'avocat commis d'office\";",
     "plus aucune pose locale du statut"),

    ("defense -- l'affaire ne recopie plus l'etat arrete par le serveur",
     "    if (pos >= 0) state.plaintesEnCours[pos] = vDef.affaire;",
     "    void pos;",
     "l'affaire recopie l'etat arrete par le serveur"),
]

# SERIE « CYCLE D'UNE AFFAIRE -- politique » SUPPRIMEE le 13 octobre 2026. Ses deux
# contre-epreuves mesuraient le CLASSEMENT MINISTERIEL (`plainte_classer_ministere`,
# `ouvrirModalAffaires('annuler')`), supprime le 12 octobre : l'opportunite des poursuites
# appartient au parquet. Les deux epreuves correspondantes ont quitte `banc-cycle-plaintes.js`
# le meme jour, mais la serie est restee -- et elle echouait depuis, sur « ancrage introuvable ».

REGRESSIONS_PLAINTES_SUPABASE = [
    ("cycle -- l'upsert du blob entier revient dans supabase.js",
     "async function sbLoadPlaintes(country) {",
     "async function sbSavePlainte(plainte) {\n  return sbUpsert('plaintes_en_cours', {});\n}\n"
     "async function sbLoadPlaintes(country) {",
     "sbSavePlainte n existe plus dans supabase.js"),
]


# ---------------------------------------------------------------------------------------------
# ETAT D'UN TERRAIN (chantier 5, les 22 `sbSetTerrainState`, 10 octobre 2026).
REGRESSIONS_TERRAIN_SUPABASE = [
    ("terrain -- la plus grosse surface d'ecriture cliente revient dans supabase.js",
     "async function sbGetTerrainState(country, buildingId, city) {",
     "async function sbSetTerrainState(country, buildingId, etat) {\n"
     "  return sbUpsert('terrains_etat', { id: country + '_' + buildingId });\n}\n"
     "async function sbGetTerrainState(country, buildingId, city) {",
     "sbSetTerrainState n existe plus dans supabase.js"),
]

REGRESSIONS_TERRAIN_JUSTICE = [
    ("terrain -- le verdict du transfert de compromis n'est plus lu",
     "  if (!vTr || vTr.ok !== true) {",
     "  if (false) {",
     "les dix-neuf appels nommes lisent tous leur verdict"),

    ("terrain -- la decision du permis renvoie l'etat ENTIER au serveur",
     "    p_patch: valide\n      ? { permis: etat.permis, constructionAutorisee: true }\n"
     "      : { permis: etat.permis }",
     "    p_patch: etat",
     "la decision du permis ne transmet que `permis`"),

    ("terrain -- l'acceleration interdite preleve quand meme PA et argent",
     "  showToast('Délai incompressible',",
     "  await deduireCoutOrdre({pa,cost});\n  showToast('Délai incompressible',",
     "l'acceleration interdite ne preleve ni PA ni argent"),

    ("terrain -- le vol credite la quantite calculee ici, pas celle que le serveur a arretee",
     "    qte = Number(vVol.quantite) || 0;",
     "    void vVol;",
     "le vol credite la quantite REELLEMENT emportee"),

    ("terrain -- l'ajout d'un lot renvoie le tableau entier",
     "    p_terrain_id: id, p_acte: 'lot_ajouter', p_lots: [lotNeuf]",
     "    p_terrain_id: id, p_acte: 'lot_ajouter', p_lots: (ts.subdivisions || []).concat([lotNeuf])",
     "doAjouterSubdivision n ecrit plus le tableau entier"),

    ("terrain -- le lot absorbe est de nouveau designe par un indice",
     "  const idVide = prop.idVide || (subdivisions[prop.idxVide] || {}).id || null;",
     "  const idVide = null; subdivisions.splice(prop.idxVide, 1);",
     "le lot absorbe est designe par son IDENTIFIANT"),
]

REGRESSIONS_TERRAIN_PERSONNAGE = [
    ("terrain -- le gel successoral redevient une ecriture de blob",
     "      const r = await sbRpc('terrain_succession_geler',",
     "      const r = await sbRpcAbsente('terrain_succession_geler',",
     "le gel passe par sa porte, et son verdict est lu"),
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


def lancer_substitution(nom_fichier):
    """Fabrique un lanceur pour un banc qui lit LUI-MEME les fichiers du depot, par readFile.
    Un tel banc n'a pas de source a substituer : on lui passe donc une TABLE DE SUBSTITUTION, et
    il remplace ce seul fichier par la copie patchee. Sans cela, le banc relirait la production
    et resterait vert : la contre-epreuve ne prouverait rien."""
    def lanceur(banc, chemin_source):
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as f:
            f.write("var SUBSTITUTIONS = { %r: %r };\n" % (nom_fichier, chemin_source))
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



# =============================================================================================
# SUBVENTIONS MUNICIPALES -- CHAINE 7 (10 octobre 2026)
# =============================================================================================
# Chaque regression retire UNE discipline du cote navigateur, et nomme l'epreuve qui doit la
# surveiller. Si l'epreuve reste verte, c'est elle qu'il faut reecrire -- pas le code.

REGRESSIONS_SUBVENTIONS_ORGA = [
    ("l'ancienne mecanique gelee ressuscite",
     "async function repondreSubventionMunicipale(id, reponse) {",
     "async function verifierSubventionMairie(club) { return; }\n"
     "async function repondreSubventionMunicipale(id, reponse) {",
     "verifierSubventionMairie n existe plus"),
    ("un bouton envoie un STATUT au lieu d'un verbe",
     "repondreSubventionMunicipale(\\'' + p.id + '\\',\\'refuser\\')",
     "repondreSubventionMunicipale(\\'' + p.id + '\\',\\'expiree\\')",
     "les boutons n envoient que les deux verbes"),
    ("l'ecran du club credite la caisse lui-meme",
     "  const r = await sbSubventionRepondre(id, reponse).catch(() => null);",
     "  await crediterBudgetClub('x', 1, 'y');\n"
     "  const r = await sbSubventionRepondre(id, reponse).catch(() => null);",
     "aucun ecran de subvention ne credite une caisse de club"),
    ("l'ecran ne demande plus au serveur de quoi je suis gestionnaire",
     "    ? await sbSubventionsRecuesLire().catch(() => null) : null;",
     "    ? null : null;",
     "il demande au serveur de quelles propositions je suis gestionnaire"),
]

REGRESSIONS_SUBVENTIONS_POLITIQUE = [
    ("l'ecran facture les PA que la porte facture deja",
     "  const r = (typeof sbSubventionProposer === 'function')",
     "  await deduireCoutOrdre({ pa: 2, cost: 0 });\n"
     "  const r = (typeof sbSubventionProposer === 'function')",
     "aucun des deux ecrans n appelle deduireCoutOrdre"),
    ("l'ecran recalcule le disponible au lieu de le recevoir",
     "[['Solde', e.solde, '#C9A84C'], ['Réservé', e.reserve, '#cc9a44'], ['Disponible', e.disponible, '#6ab858']]",
     "[['Solde', e.solde, '#C9A84C'], ['Réservé', e.reserve, '#cc9a44'], ['Disponible', e.solde - e.reserve, '#6ab858']]",
     "il n invente ni le disponible ni la reserve"),
    ("l'ecran n applique plus le paiement rendu par le serveur",
     "  if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(r.paiement);",
     "  // paiement non applique",
     "l ecran recopie le paiement que le serveur a reellement ecrit"),
    ("une panne de lecture devient une enveloppe vide",
     "  if (!e || e.ok !== true) {\n    const motif = (e && e.raison) ? e.raison : 'indisponible';",
     "  if (false) {\n    const motif = (e && e.raison) ? e.raison : 'indisponible';",
     "une panne de lecture n est pas affichee comme une enveloppe vide"),
]

REGRESSIONS_SUBVENTIONS_SUPABASE = [
    ("le navigateur annonce la commune du maire",
     "async function sbSubventionEnveloppeLire() {\n  const rows = await sbRpc('subvention_enveloppe_lire', {});",
     "async function sbSubventionEnveloppeLire() {\n  const rows = await sbRpc('subvention_enveloppe_lire', { p_ville: 'capitale' });",
     "sbSubventionEnveloppeLire ne transmet AUCUN argument"),
    ("les archives exposent les negociations en cours",
     "&statut=neq.proposee&order=created_at.desc&limit=50');",
     "&order=created_at.desc&limit=50');",
     "les archives publiques ne demandent que les propositions CLOSES"),
]

REGRESSIONS_SUBVENTIONS_ROUTEUR = [
    ("le routeur retransmet pa et cost, invitant au double prelevement",
     "if (fn === 'subvention_proposer'){ doProposerSubvention(); return; }",
     "if (fn === 'subvention_proposer'){ doProposerSubvention(pa, cost); return; }",
     "il ne lui transmet NI pa NI cost"),
]

REGRESSIONS_SUBVENTIONS_CRON = [
    ("la passe de minuit n expire plus rien",
     "      const rows = await sbRpc('subventions_expirer', { p_pays: 'republic' }, HEADERS_SERVICE);",
     "      const rows = null;",
     "le cron appelle subventions_expirer"),
]




# =============================================================================================
# GREFFE ET UNIVERSITE -- TRANCHE DU 13 OCTOBRE 2026
# =============================================================================================
# CHAQUE REGRESSION REMET UN DEFAUT QUE LA TRANCHE A FERME, et nomme l'epreuve qui doit le voir.
# Les quatre premieres portent sur le CATALOGUE (data.js) : c'est la que vivaient le faux casier
# fabrique par le navigateur et la salle de reunion louable. Les suivantes portent sur les
# ECRANS : un handler qui ecrit l'inventaire lui-meme, une fiche qui revelerait l'authenticite
# d'un document, un bouton differe qu'on peut encore cliquer, un taux illegal que l'ecran module
# alors que le serveur le tient fixe, et une exclusivite de local reintroduite cote client.

REGRESSIONS_GREFFE_DATA = [
    ("le navigateur refabrique un faux casier",
     "id:'fausse_identite'",
     "id:'faux_casier', nom:'Faux casier vierge', cout:300}, {id:'fausse_identite'",
     "le faux casier a quitte DOCUMENTS_FALSIFIABLES"),
    ("la salle de reunion redevient un local a louer",
     "salle_reunion: {",
     "salle_reunion: { isLocationRoom:true,",
     "elle n est plus declaree comme un local a louer"),
    ("« Suivre une formation » perd son drapeau `bientot`",
     "bientot:'Bient\u00f4t disponible",
     "inactif:'Bient\u00f4t disponible",
     "il porte le drapeau generique `bientot`"),
    ("les frais de greffe de la domiciliation disparaissent",
     "{fn:'syndicat_etudiant_creer', label:'Domicilier un syndicat \u00e9tudiant', pa:2, cost:150,",
     "{fn:'syndicat_etudiant_creer', label:'Domicilier un syndicat \u00e9tudiant', pa:2, cost:0,",
     "la domiciliation coute 2 PA et 150 FR"),
]

REGRESSIONS_GREFFE_ROUTEUR = [
    ("une route mene a l'ordre differe",
     "  if (fn === 'casier_mon_extrait')",
     "  if (fn === 'suivre_formation') { showToast('Formation', 'x'); return; }\n"
     "  if (fn === 'casier_mon_extrait')",
     "AUCUNE route ne mene a cet ordre"),
]

REGRESSIONS_GREFFE_JUSTICE = [
    ("un handler du greffe ecrit l'objet lui-meme",
     "async function doCasierMonExtrait() {",
     "async function doCasierMonExtrait() {\n"
     "  state.inventory.push({ name: 'Extrait de casier', type: 'document_officiel' });",
     "doCasierMonExtrait n ecrit rien dans l inventaire"),
    ("la fiche d'un document revele son authenticite",
     "function documentOfficielHtml(item) {",
     "function documentOfficielHtml(item) {\n"
     "  if (item.authentique === false) { return '<p>FAUX</p>'; }",
     "la fiche d un document ne lit aucune authenticite"),
]

REGRESSIONS_GREFFE_POLITIQUE = [
    ("un ordre differe redevient cliquable",
     "needsBientot || needsPost",
     "needsPost",
     "un ordre `bientot` est GRISE"),
    ("l'ecran module un taux que le serveur tient fixe",
     "o.type === 'illegal' && !o.tauxFixe",
     "o.type === 'illegal'",
     "le moteur de rendu respecte aussi le taux FIXE du serveur"),
]

REGRESSIONS_GREFFE_ORGAS = [
    ("le navigateur ecrit l'organisation a la place de la porte",
     "async function confirmerSyndicatEtudiantCreer() {",
     "async function confirmerSyndicatEtudiantCreer() {\n"
     "  state.organisations.push({ id: 'x', type: 'syndicale' });",
     "la creation d un syndicat etudiant passe par la porte serveur, et par elle seule"),
    ("l'ecran reintroduit une exclusivite de local",
     "function ouvrirSyndicatsEtudiants() {",
     "function ouvrirSyndicatsEtudiants() {\n"
     "  if (state.dejaUn) { showToast('Local d\u00e9j\u00e0 occup\u00e9', 'x'); return; }",
     "l ecran des syndicats ne refuse aucun local deja occupe"),
]



# =============================================================================================
# DIALOGUE DES PNJ DE REPUBLIA -- TRANCHE DU 13 OCTOBRE 2026
# =============================================================================================
# CE CHAPITRE EXISTE PARCE QUE LE DEFAUT S'EST PRODUIT DEUX FOIS. Le 29 septembre 2026, une
# TypeError levee AVANT le try/catch du dialogue a rendu trois PNJ de la caserne muets, en
# laissant le joueur bloque sur « En train de repondre... » -- sans qu'aucune requete ne parte et
# sans qu'aucun banc ne s'allume. Le 13 octobre, le meme bloc lisait encore `FORUM_TOPICS` hors
# de toute protection : il suffisait d'un changement d'ordre de chargement pour que les 171 PNJ
# de Republia se taisent ensemble. Chaque regression ci-dessous remet un de ces defauts.

REGRESSIONS_PNJ_PERSONNALITES = [
    ("Jeremy redevient muet -- le guide de la quete d'accueil",
     "  'jeremy': {\n    nom: \"Jérémy\",",
     "  'jeremy_desactive': {\n    nom: \"Jérémy\",",
     "Jérémy a un profil serveur"),
    ("Maxence redevient muet",
     "  'maxence_monfils': {\n    nom: \"Maxence Monfils\",",
     "  'maxence_desactive': {\n    nom: \"Maxence Monfils\",",
     "Maxence Monfils a un profil serveur"),
]

REGRESSIONS_PNJ_CLIENT = [
    ("une lecture hors try/catch remet tous les PNJ en panne silencieuse",
     # L'ANCRE EST LA PREMIERE LIGNE PROPRE A `talkToPnj`. Celle du spinner apparait DEUX fois
     # -- openPnjModal la pose aussi -- et une ancre non unique ne prouve rien.
     "  // Gestion speciale loge\n  if (pnj.job === 'portier' && action === 'bonjour') {",
     "  const __mort = TABLE_QUI_N_EXISTE_PAS['x'];\n"
     "  // Gestion speciale loge\n  if (pnj.job === 'portier' && action === 'bonjour') {",
     "aucun PNJ ne leve une exception dans le chemin de dialogue"),
    ("un refus definitif promet de nouveau de reessayer",
     # L'apostrophe de « n'engage » est ECHAPPEE dans le source JavaScript : l'ancre doit
     # porter la barre oblique inverse, sinon elle ne trouve rien.
     "      ? 'Ce personnage n\\'engage pas de conversation.'",
     "      ? 'Discussion impossible momentanément. Veuillez réessayer dans quelques instants.'",
     "les deux messages de panne sont DIFFERENTS"),
    ("l'ecran invite encore a ecrire a un PNJ qui ne repondra jamais",
     "    if (e && e.definitif === true) {\n      const zoneQ = document.getElementById('pnj-zone-question');",
     "    if (false) {\n      const zoneQ = document.getElementById('pnj-zone-question');",
     "un refus DEFINITIF retire la boite de question"),
    ("une panne passagere efface la boite de question",
     "    if (e && e.definitif === true) {\n      const zoneQ = document.getElementById('pnj-zone-question');",
     "    if (true) {\n      const zoneQ = document.getElementById('pnj-zone-question');",
     "une panne PASSAGERE laisse la boite de question en place"),
    ("le navigateur se remet a construire un prompt systeme",
     "    const texteServeur = await reponsePnjServeur(profilServeur, action, recentHistory);",
     "    const __p = 'Tu joues un personnage dans Res Publica';\n"
     "    const texteServeur = await reponsePnjServeur(profilServeur, action + __p, recentHistory);",
     "elle ne contient aucun prompt systeme et aucune cle"),
]

REGRESSIONS_PNJ_PROFILS = [
    ("le miroir des objectifs de la visite derive d'une phrase",
     'attente_offre_verre: "Offrez un verre à Jérémy au bar.",',
     'attente_offre_verre: "Offrez donc un verre a Jeremy, au bar.",',
     "et la MEME phrase pour chacune"),
    ("une etape disparait du miroir serveur",
     '  guide_stade: "Rendez-vous au stade.",\n',
     '',
     "les memes etapes, dans les deux tables"),
    ("le prompt systeme cesse de placer le bloc de la visite",
     "    ...(vis ? [vis, ''] : []),\n",
     '',
     "le prompt systeme sait placer ce bloc"),
]

REGRESSIONS_PNJ_CHAT = [
    ("le sixieme canal est demande pour TOUS les PNJ",
     "  profilId === VISITE_D_ACCUEIL\n    ? lireMemoire('quete_accueil_contexte', null, jeton)\n    : Promise.resolve(null);",
     "  lireMemoire('quete_accueil_contexte', null, jeton);",
     "elle n est demandee que pour le profil jeremy"),
    ("la porte de la visite recoit un nom de joueur",
     "  quete_accueil_contexte:       () => ({})",
     "  quete_accueil_contexte:       (profilId) => ({ p_nom: profilId })",
     "la porte quete_accueil_contexte est declaree sans parametre"),
]

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
    serie("CYCLE D'UNE AFFAIRE -- supabase", BANC_PLAINTES, SUPABASE,
          REGRESSIONS_PLAINTES_SUPABASE, echecs, lanceur=lancer_cible("supabase.js"))
    serie("ETAT D'UN TERRAIN -- supabase", BANC_TERRAIN_ETAT, SUPABASE,
          REGRESSIONS_TERRAIN_SUPABASE, echecs, lanceur=lancer_cible("supabase.js"))
    serie("ETAT D'UN TERRAIN -- justice", BANC_TERRAIN_ETAT, JUSTICE,
          REGRESSIONS_TERRAIN_JUSTICE, echecs, lanceur=lancer_cible("plateau-justice-economie.js"))
    serie("ETAT D'UN TERRAIN -- personnage", BANC_TERRAIN_ETAT, PERSONNAGE,
          REGRESSIONS_TERRAIN_PERSONNAGE, echecs, lanceur=lancer_cible("plateau-personnage.js"))
    serie("SUBVENTIONS MUNICIPALES -- organisations", BANC_SUBVENTIONS, ORGANISATIONS,
          REGRESSIONS_SUBVENTIONS_ORGA, echecs,
          lanceur=lancer_cible("plateau-organisations-quetes.js"))
    serie("SUBVENTIONS MUNICIPALES -- politique", BANC_SUBVENTIONS, POLITIQUE,
          REGRESSIONS_SUBVENTIONS_POLITIQUE, echecs, lanceur=lancer_cible("plateau-politique.js"))
    serie("SUBVENTIONS MUNICIPALES -- supabase", BANC_SUBVENTIONS, SUPABASE,
          REGRESSIONS_SUBVENTIONS_SUPABASE, echecs, lanceur=lancer_cible("supabase.js"))
    serie("SUBVENTIONS MUNICIPALES -- routeur", BANC_SUBVENTIONS, ROUTEUR,
          REGRESSIONS_SUBVENTIONS_ROUTEUR, echecs, lanceur=lancer_cible("plateau-router.js"))
    serie("SUBVENTIONS MUNICIPALES -- cron", BANC_SUBVENTIONS, CRON,
          REGRESSIONS_SUBVENTIONS_CRON, echecs, lanceur=lancer_cible("api/cron-minuit.js"))
    serie("GREFFE ET UNIVERSITE -- catalogue", BANC_GREFFE, DATA,
          REGRESSIONS_GREFFE_DATA, echecs, lanceur=lancer_substitution("data.js"))
    serie("GREFFE ET UNIVERSITE -- routeur", BANC_GREFFE, ROUTEUR,
          REGRESSIONS_GREFFE_ROUTEUR, echecs, lanceur=lancer_substitution("plateau-router.js"))
    serie("GREFFE ET UNIVERSITE -- justice", BANC_GREFFE, JUSTICE,
          REGRESSIONS_GREFFE_JUSTICE, echecs,
          lanceur=lancer_substitution("plateau-justice-economie.js"))
    serie("GREFFE ET UNIVERSITE -- politique", BANC_GREFFE, POLITIQUE,
          REGRESSIONS_GREFFE_POLITIQUE, echecs,
          lanceur=lancer_substitution("plateau-politique.js"))
    serie("GREFFE ET UNIVERSITE -- organisations", BANC_GREFFE, ORGANISATIONS,
          REGRESSIONS_GREFFE_ORGAS, echecs,
          lanceur=lancer_substitution("plateau-organisations-quetes.js"))
    serie("DIALOGUE PNJ -- personnalites serveur", BANC_PNJ, PERSONNALITES,
          REGRESSIONS_PNJ_PERSONNALITES, echecs,
          lanceur=lancer_substitution("api/_pnj-personnalites.js"))
    serie("DIALOGUE PNJ -- navigateur", BANC_PNJ, PNJ,
          REGRESSIONS_PNJ_CLIENT, echecs, lanceur=lancer_substitution("plateau-pnj.js"))
    serie("DIALOGUE PNJ -- assemblage du prompt", BANC_PNJ, PROFILS_PNJ,
          REGRESSIONS_PNJ_PROFILS, echecs, lanceur=lancer_substitution("api/_pnj-profils.js"))
    serie("DIALOGUE PNJ -- endpoint", BANC_PNJ, CHAT,
          REGRESSIONS_PNJ_CHAT, echecs, lanceur=lancer_substitution("api/chat.js"))
    total = (len(REGRESSIONS) + len(REGRESSIONS_VOTE) + len(REGRESSIONS_DESERTION)
             + len(REGRESSIONS_COTISATIONS) + len(REGRESSIONS_SUCCESSIONS)
             + len(REGRESSIONS_IMPOTS) + len(REGRESSIONS_TOURNEE)
             + len(REGRESSIONS_TERRAIN) + len(REGRESSIONS_PLAINTES_JUSTICE)
             + len(REGRESSIONS_PLAINTES_SUPABASE)
             + len(REGRESSIONS_TERRAIN_SUPABASE) + len(REGRESSIONS_TERRAIN_JUSTICE)
             + len(REGRESSIONS_TERRAIN_PERSONNAGE)
             + len(REGRESSIONS_SUBVENTIONS_ORGA) + len(REGRESSIONS_SUBVENTIONS_POLITIQUE)
             + len(REGRESSIONS_SUBVENTIONS_SUPABASE) + len(REGRESSIONS_SUBVENTIONS_ROUTEUR)
             + len(REGRESSIONS_SUBVENTIONS_CRON)
             + len(REGRESSIONS_GREFFE_DATA) + len(REGRESSIONS_GREFFE_ROUTEUR)
             + len(REGRESSIONS_GREFFE_JUSTICE) + len(REGRESSIONS_GREFFE_POLITIQUE)
             + len(REGRESSIONS_GREFFE_ORGAS)
             + len(REGRESSIONS_PNJ_PERSONNALITES) + len(REGRESSIONS_PNJ_CLIENT)
             + len(REGRESSIONS_PNJ_PROFILS) + len(REGRESSIONS_PNJ_CHAT))
    if echecs:
        print("ECHEC : %d contre-epreuve(s) en defaut." % len(echecs))
        for e in echecs:
            print("  - " + e)
        return 1
    print("LES %d CONTRE-EPREUVES SONT VERTES." % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
