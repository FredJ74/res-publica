#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """      "Jusqu'en 1947 : propriété de Pierre Thibault (terrain agricole, 2ha10).","""
new_1 = """      "Jusqu'en 1947 : propriété de Pierre Thibault, qui y cultivait des pommes de terre (terrain agricole, 2ha10).","""
assert content.count(old_1) == 1, f"parcelle B-127 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Culture de pommes de terre ajoutée à la parcelle B-127.")
