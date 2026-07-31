#!/usr/bin/env python3
PATH = "plateau-multijoueur.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (typeof updateUI === 'function') updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  showToast('Jérémy vous accompagne', 'Il vous suit desormais dans vos deplacements.', true);
}"""

new = """  if (typeof updateUI === 'function') updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  // Rafraichit aussi la liste "Personnes presentes" de la piece actuelle, pour que Jeremy
  // y apparaisse immediatement a cote du joueur (effet de groupe visible), sans attendre
  // un changement de piece. updateUI() seul ne suffit pas : cette liste a son propre appel.
  const roomActuelleJeremy = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom] : null;
  if (roomActuelleJeremy && typeof renderPersonsList === 'function') {
    renderPersonsList(roomActuelleJeremy.persons || []);
  }
  showToast('Jérémy vous accompagne', 'Il vous suit desormais dans vos deplacements.', true);
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Rafraîchissement de la liste 'Personnes présentes' ajouté.")
