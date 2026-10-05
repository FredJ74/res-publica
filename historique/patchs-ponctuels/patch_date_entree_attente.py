#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  ts.permis.statut = 'attente_validation';
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, buildingId, ts).catch(() => {});"""
new = """  ts.permis.statut = 'attente_validation';
  ts.permis.dateEntreeAttente = Date.now();
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, buildingId, ts).catch(() => {});"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ dateEntreeAttente enregistrée au passage en attente de validation.")
