#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Nouvelle version de queteAccueilRepriseNon : le joueur ajoute lui-meme Jeremy aux contacts ---
old_1 = """function queteAccueilRepriseNon() {
  state.char.queteAccueil = { etape: 'quete_terminee_sans_aide' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  if (typeof addContactByName === 'function') {
    addContactByName('Jérémy', 'Ancien stagiaire de la Mairie', 'ally', false);
  }
  if (typeof quitterJeremy === 'function') quitterJeremy();

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Alors nos chemins se séparent ici. Pour le moment, bien sûr ! Si vous avez besoin de moi, envoyez-moi un mail. Je vous ai ajouté à mes contacts.",
    suivant: null
  });
}"""

new_1 = """function queteAccueilRepriseNon() {
  // On ne l'ajoute plus automatiquement au repertoire : on guide plutot le joueur pour qu'il
  // clique lui-meme sur Jeremy (dans Personnes Presentes) et utilise le bouton "Ajouter au
  // repertoire" qui apparait naturellement dans sa fiche, puis le bouton Messages/Forums.
  // Jeremy quitte reellement le groupe seulement au prochain deplacement (voir
  // queteAccueilVerifierDepartJeremy, appelee depuis les deux hooks de navigation).
  state.char.queteAccueil = { etape: 'attente_depart_jeremy' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Alors nos chemins se séparent ici. Pour le moment, bien sûr !<br><br>Si vous avez besoin de moi, cliquez sur ma fiche pour m'ajouter à vos contacts, et utilisez ensuite le bouton Messages/Forums pour m'envoyer un mail.",
    suivant: function() {
      queteAccueilSurbrillance(".person-card[onclick*=\\"openPnjModal('\\"]", 15000);
      queteAccueilSurbrillance('#btn-messages', 15000);
    }
  });
}

// Fait quitter Jeremy du groupe reellement, au premier deplacement (rue ou batiment) suivant
// la separation choisie par le joueur. Appelee au debut des deux hooks de navigation existants.
function queteAccueilVerifierDepartJeremy() {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  if (state.char.queteAccueil.etape !== 'attente_depart_jeremy') return;
  state.char.queteAccueil = { etape: 'quete_terminee_sans_aide' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  if (typeof quitterJeremy === 'function') quitterJeremy();
}"""

assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Appeler la verification de depart au debut des deux hooks de navigation existants ---
old_2 = """function queteAccueilVerifierGuidage(pays, noeudId) {
  if (pays !== 'republic') return;
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;
"""
new_2 = """function queteAccueilVerifierGuidage(pays, noeudId) {
  if (typeof queteAccueilVerifierDepartJeremy === 'function') queteAccueilVerifierDepartJeremy();
  if (pays !== 'republic') return;
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;
"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

old_3 = """function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'attente_entree_mairie' && buildingId === 'mairie-capitale' && roomId === 'hall_mairie') {"""
new_3 = """function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof queteAccueilVerifierDepartJeremy === 'function') queteAccueilVerifierDepartJeremy();
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'attente_entree_mairie' && buildingId === 'mairie-capitale' && roomId === 'hall_mairie') {"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Séparation avec Jérémy refaite : le joueur l'ajoute lui-même aux contacts.")
