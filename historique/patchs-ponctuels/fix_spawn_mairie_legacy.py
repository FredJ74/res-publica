#!/usr/bin/env python3
"""
Retire l'ancien repli "nouveau personnage -> mairie" dans plateau-core.js
(obsolete, remplace par la quete d'accueil dans la rue), et ajoute
currentCity a l'objet char dans creation.js pour combler le vrai trou
d'origine.
"""

# --- 1. plateau-core.js : retirer le repli vers la mairie ---
PATH_CORE = "plateau-core.js"
with open(PATH_CORE, "r", encoding="utf-8") as f:
    core = f.read()

old_fallback = """  // Nouveau personnage jamais place nulle part : apparait dans le hall d'accueil
  // de la mairie de sa ville de domiciliation (point de depart des quetes exploratoires).
  // IMPORTANT : on verifie aussi l'absence de currentCity connue, sinon ce repli se
  // declenche a tort pour un personnage existant simplement revenu dans la rue (currentBuilding
  // null y est un etat normal et frequent depuis le fix du bug de batiment fantome).
  if (!state.currentBuilding && !state.char?.currentBuilding && !state.char?.currentCity) {
    const buildingMairie = state.currentCity === 'capitale' ? 'mairie-capitale' : 'mairie';
    const roomMairie = state.currentCity === 'capitale' ? 'hall_mairie' : 'accueil_mairie';
    state.currentBuilding = buildingMairie;
    state.currentRoom = roomMairie;
    if (state.char) {
      state.char.currentBuilding = buildingMairie;
      state.char.currentRoom = roomMairie;
    }
  }"""

new_fallback = """  // Ancien repli "nouveau personnage -> hall de la mairie" retire le 31 juillet 2026 :
  // obsolete et en conflit avec la quete d'accueil, qui place desormais le nouveau
  // personnage dans la rue devant le Palais Presidentiel (voir plateau-quete-accueil.js)."""

assert core.count(old_fallback) == 1, f"plateau-core.js : trouvé {core.count(old_fallback)} fois (attendu 1)"
core = core.replace(old_fallback, new_fallback)

with open(PATH_CORE, "w", encoding="utf-8") as f:
    f.write(core)

# --- 2. creation.js : ajouter currentCity a l'objet char ---
PATH_CREATION = "creation.js"
with open(PATH_CREATION, "r", encoding="utf-8") as f:
    creation = f.read()

old_char = """    arg:totalArg(), resources:resources(),
    createdAt:new Date().toISOString(),
    queteAccueil:{ etape:'non_commencee' }
  };"""
new_char = """    arg:totalArg(), resources:resources(),
    createdAt:new Date().toISOString(),
    currentCity:G.city || 'capitale',
    queteAccueil:{ etape:'non_commencee' }
  };"""
assert creation.count(old_char) == 1, f"creation.js : trouvé {creation.count(old_char)} fois (attendu 1)"
creation = creation.replace(old_char, new_char)

with open(PATH_CREATION, "w", encoding="utf-8") as f:
    f.write(creation)

print("✅ Correctif appliqué : repli vers la mairie retiré + currentCity ajouté à la création.")
