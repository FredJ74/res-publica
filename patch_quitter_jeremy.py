#!/usr/bin/env python3
PATH = "plateau-multijoueur.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function getGroupSize() {"""
new = """// Jeremy quitte le groupe a la fin de la quete d'accueil (separation, avec ou sans reprise
// possible plus tard par mail). Symetrique de rejoindreJeremy().
function quitterJeremy() {
  if (typeof state === 'undefined' || !state.employes) return;
  state.employes = state.employes.filter(function(e) { return e.nom !== 'Jérémy'; });
  if (typeof updateUI === 'function') updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  const roomActuelleJeremy = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom] : null;
  if (roomActuelleJeremy && typeof renderPersonsList === 'function') {
    renderPersonsList(roomActuelleJeremy.persons || []);
  }
}

function getGroupSize() {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ quitterJeremy ajouté.")
