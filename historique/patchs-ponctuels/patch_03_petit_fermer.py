#!/usr/bin/env python3

# --- 1. Surbrillance de Petit a l'arrivee dans le hall (plateau-quete-accueil.js) ---
PATH_Q = "plateau-quete-accueil.js"
with open(PATH_Q, "r", encoding="utf-8") as f:
    q = f.read()

old_1 = """function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;
"""
new_1 = """function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'attente_entree_mairie' && buildingId === 'mairie-capitale' && roomId === 'hall_mairie') {
    queteAccueilSurbrillance('.person-card[data-enc*="Petit"]', 15000);
  }
"""
assert q.count(old_1) == 1, f"plateau-quete-accueil.js : trouvé {q.count(old_1)} fois (attendu 1)"
q = q.replace(old_1, new_1)

with open(PATH_Q, "w", encoding="utf-8") as f:
    f.write(q)

# --- 2. Surbrillance du bouton Fermer (plateau-personnage.js, dans openSelfView) ---
PATH_P = "plateau-personnage.js"
with open(PATH_P, "r", encoding="utf-8") as f:
    p = f.read()

old_2 = """function openSelfView() {
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));"""
new_2 = """function openSelfView() {
  if (typeof state !== 'undefined' && state.char?.queteAccueil?.etape === 'attente_fiche_personnage' && typeof queteAccueilSurbrillance === 'function') {
    queteAccueilSurbrillance('.sortir-btn', 15000);
  }
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));"""
assert p.count(old_2) == 1, f"plateau-personnage.js : trouvé {p.count(old_2)} fois (attendu 1)"
p = p.replace(old_2, new_2)

with open(PATH_P, "w", encoding="utf-8") as f:
    f.write(p)

print("✅ Surbrillance de Petit (hall) + du bouton Fermer (fiche personnage) ajoutées.")
