#!/usr/bin/env python3
PATH = "plateau-rue-centrale.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    { dir: 'arriere',   icon: 'ti-arrow-back-up' },"""
new = """    { dir: 'arriere',   icon: 'ti-arrow-down' },"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Icône 'arrière' remplacée par une flèche vers le bas (moins trompeuse qu'un retour en arrière).")
