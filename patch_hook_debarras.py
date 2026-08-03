#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (typeof enigme1InjecterZoneCliquable === 'function') enigme1InjecterZoneCliquable(buildingId, roomId);"""
new = """  if (typeof enigme1InjecterZoneCliquable === 'function') enigme1InjecterZoneCliquable(buildingId, roomId);
  if (typeof enigme1VerifierDebarras === 'function') enigme1VerifierDebarras(buildingId, roomId);"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Hook du débarras branché dans enterRoom.")
