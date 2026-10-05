#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Retirer la derniere trace de terrainsAchetes dans doAcheterTerrain ---
old_1 = """  state.arg -= prix;
  if (!state.terrainsAchetes) state.terrainsAchetes = {};
  state.terrainsAchetes[id] = state.char?.name;

  // Synchroniser aussi avec Supabase"""
new_1 = """  state.arg -= prix;

  // Synchroniser aussi avec Supabase"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Supprimer le code mort getTerrainState/setTerrainState (bases sur localStorage,
# jamais reellement executes car ecrases par la version de plateau-justice-economie.js) ---
old_2 = """function getTerrainState(buildingId) {
  const key = 'terrain_state_' + state.country + '_' + buildingId;
  try {
    const stored = localStorage.getItem(key);
    return stored ? JSON.parse(stored) : {};
  } catch(e) { return {}; }
}

function setTerrainState(buildingId, updates) {
  const key = 'terrain_state_' + state.country + '_' + buildingId;
  const current = getTerrainState(buildingId);
  const newState = { ...current, ...updates };
  try { localStorage.setItem(key, JSON.stringify(newState)); } catch(e) {}

  // Synchroniser avec Supabase si disponible
  if (typeof sbSetTerrainState === 'function') {
    sbSetTerrainState(state.country, buildingId, newState).catch(() => {});
  }
  return newState;
}

"""
new_2 = """// NOTE : getTerrainState/setTerrainState sont definies dans plateau-justice-economie.js
// (systeme unifie, base sur state.terrainsState + Supabase). Une ancienne version basee sur
// localStorage vivait ici, mais etait silencieusement ecrasee (dernier fichier charge gagne
// en JS) — code mort supprime le 3 aout 2026 pour eviter toute confusion future.

"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Étape 3 : code mort supprimé, dernière trace de terrainsAchetes retirée.")
