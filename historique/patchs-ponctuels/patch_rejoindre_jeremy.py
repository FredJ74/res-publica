#!/usr/bin/env python3
PATH = "plateau-multijoueur.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function quitterGroupe() {
  const myName = state.char && state.char.name ? state.char.name : 'Joueur';
  if (!state.group) return;
  state.group.members = state.group.members.filter(function(m) { return m !== myName; });
  if (state.group.members.length <= 1) state.group = null;
  closePnjModal();
  showToast('Groupe quitte', 'Vous avez quitte le groupe.', false);
  addJournalEntry('Vous avez quitte le groupe.', '');
}

function getGroupSize() {"""
new = """function quitterGroupe() {
  const myName = state.char && state.char.name ? state.char.name : 'Joueur';
  if (!state.group) return;
  state.group.members = state.group.members.filter(function(m) { return m !== myName; });
  if (state.group.members.length <= 1) state.group = null;
  closePnjModal();
  showToast('Groupe quitte', 'Vous avez quitte le groupe.', false);
  addJournalEntry('Vous avez quitte le groupe.', '');
}

// Mecanique de groupe speciale pour Jeremy (quete d'accueil) : c'est le JOUEUR qui devient
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
}

function getGroupSize() {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fonction rejoindreJeremy ajoutée.")
