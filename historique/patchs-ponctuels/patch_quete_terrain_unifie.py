#!/usr/bin/env python3
PATH = "plateau-organisations-quetes.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        if (typeof sbSetTerrainState === 'function') {
          await sbSetTerrainState(state.country, terrainInfo.buildingId, nouvelEtat).catch(() => {});
        }
        // Mettre aussi a jour le localStorage local si le joueur consulte ce terrain plus tard
        try {
          localStorage.setItem('terrain_state_' + state.country + '_' + terrainInfo.buildingId, JSON.stringify(nouvelEtat));
        } catch(e) {}

        if (!state.terrainsAchetes) state.terrainsAchetes = {};
        state.terrainsAchetes[terrainInfo.buildingId] = state.char?.name;"""
new = """        // Systeme unifie : cache local (state.terrainsState) + Supabase
        if (typeof setTerrainState === 'function') {
          setTerrainState(terrainInfo.buildingId, nouvelEtat);
        }
        if (typeof sbSetTerrainState === 'function') {
          await sbSetTerrainState(state.country, terrainInfo.buildingId, nouvelEtat).catch(() => {});
        }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Récompense de quête (terrain à bâtir) unifiée sur le même système.")
