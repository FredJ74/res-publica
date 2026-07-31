#!/usr/bin/env python3
PATH = "plateau-multijoueur.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      buildingId: state.currentBuilding,
      roomId: state.currentRoom
    });
  }
  showToast('Jérémy vous accompagne', 'Il vous suit desormais dans vos deplacements.', true);
}"""

new = """      buildingId: state.currentBuilding,
      roomId: state.currentRoom
    });
  }
  if (typeof updateUI === 'function') updateUI();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  showToast('Jérémy vous accompagne', 'Il vous suit desormais dans vos deplacements.', true);
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Rafraîchissement automatique ajouté après l'ajout de Jérémy.")
