#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Lecture : utiliser le systeme unifie plutot que terrainsAchetes ---
old_1 = """  // Vérifier si le terrain appartient à quelqu'un
  const proprietaire = state.terrainsAchetes?.[building];"""
new_1 = """  // Vérifier si le terrain appartient à quelqu'un (systeme unifie, source Supabase)
  const proprietaire = getTerrainState(building).proprietaire;"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Ecriture : passer par setTerrainState + sbSetTerrainState au lieu de terrainsAchetes ---
old_2 = """  // Transférer le terrain
  if (!state.terrainsAchetes) state.terrainsAchetes = {};
  state.terrainsAchetes[buildingId] = acheteur;
  state.arg += prix;
  updateUI();"""
new_2 = """  // Transférer le terrain (systeme unifie : cache local + Supabase)
  const nouvelEtatRachat = setTerrainState(buildingId, { proprietaire: acheteur, coproprietaire: null });
  if (typeof sbSetTerrainState === 'function') {
    sbSetTerrainState(state.country, buildingId, nouvelEtatRachat).catch(() => {});
  }
  state.arg += prix;
  updateUI();"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Étape 2 : doRacheterTerrain/accepterRachat unifiés sur le système Supabase.")
