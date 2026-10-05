#!/usr/bin/env python3
PATH = "plateau-multijoueur.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// Mecanique de groupe speciale pour Jeremy (quete d'accueil) : c'est le JOUEUR qui devient
// leader (l'inverse de rejoindrePJ, ou c'est la personne rejointe qui devient leader).
// Restreinte aux etapes actives de la quete pour eviter tout detournement hors contexte.
function rejoindreJeremy() {
  if (typeof state === 'undefined' || !state.char) return;
  const etapesJeremyActif = ['jeremy_presentation', 'jeremy_groupe'];
  if (!state.char.queteAccueil || etapesJeremyActif.indexOf(state.char.queteAccueil.etape) === -1) {
    if (typeof showToast === 'function') showToast('Indisponible', "Jérémy n'est plus disponible.", false);
    return;
  }
  const myName = state.char.name || 'Joueur';
  state.group = { leader: myName, members: [myName, 'Jérémy'] };
  showToast('Groupe rejoint', 'Jérémy vous accompagne desormais dans la ville. Vous etes le leader du groupe.', true);
}"""

new = """// Jeremy (quete d'accueil) rejoint le groupe via le meme systeme que les PNJ employes
// (state.employes + inGroupe), qui gere deja l'affichage dans chaque piece et le suivi
// automatique du joueur (voir getGroupeHtmlPourPiece / deplacerGroupeAvecPj). Pas besoin
// de la mecanique state.group (reservee a rejoindre un AUTRE joueur) : ici, le joueur est
// naturellement aux commandes, comme pour n'importe quel PNJ recrute.
// Restreinte aux etapes actives de la quete pour eviter tout detournement hors contexte.
function rejoindreJeremy() {
  if (typeof state === 'undefined' || !state.char) return;
  const etapesJeremyActif = ['jeremy_presentation', 'jeremy_groupe'];
  if (!state.char.queteAccueil || etapesJeremyActif.indexOf(state.char.queteAccueil.etape) === -1) {
    if (typeof showToast === 'function') showToast('Indisponible', "Jérémy n'est plus disponible.", false);
    return;
  }
  if (!state.employes) state.employes = [];
  if (!state.employes.some(function(e) { return e.nom === 'Jérémy'; })) {
    state.employes.push({
      nom: 'Jérémy',
      nomComplet: 'Jérémy (PNJ)',
      role: 'Stagiaire pistonné - Hôtel de Ville',
      job: 'stagiaire',
      photoUrl: (typeof QUETE_ACCUEIL_IMAGES !== 'undefined' && QUETE_ACCUEIL_IMAGES.jeremy) || null,
      photoPos: '50% 20%',
      inGroupe: true,
      buildingId: state.currentBuilding,
      roomId: state.currentRoom
    });
  }
  showToast('Jérémy vous accompagne', 'Il vous suit desormais dans vos deplacements.', true);
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ rejoindreJeremy corrigé pour utiliser le bon système (state.employes).")
