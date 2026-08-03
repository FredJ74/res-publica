#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    if (typeof sbSetTerrainState === 'function') {
      await sbSetTerrainState(state.country, id, { proprietaire: state.char?.name, coproprietaire }).catch(() => {});
    }"""
new = """    if (typeof sbSetTerrainState === 'function') {
      await sbSetTerrainState(state.country, id, { proprietaire: state.char?.name, coproprietaire, surface }).catch(() => {});
    }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Surface incluse dans l'écriture directe Supabase.")
